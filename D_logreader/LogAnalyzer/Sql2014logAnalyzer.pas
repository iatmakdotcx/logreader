unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, LogSource, dbDict, System.SysUtils,
  Contnrs, BinDataUtils, SqlDDLs, LogtransPkgMgr;

type

  /// <summary>
  /// 一个独立的行数据
  /// </summary>
  Tsql2014RowData = class(TObject)
    Fields: TList;
    //Table: TdbTableItem;
  public
    function getFieldStrValue(FieldName: string): string;
    function getField(FieldName: string):PdbFieldValue;overload;
    function getField(col_id: Integer):PdbFieldValue;overload;
    constructor Create;
    destructor Destroy; override;
  end;
  /// <summary>
  /// 一个完整的操作（可能包含多个Lsn的运行结果
  /// 缓存日志（COMPENSATION可能会修改数据
  /// </summary>
  Tsql2014Opt = class(TObject)
    OperaType: TOperationType;
    page:TPage_Id;
    table:TdbTableItem;
    UnReliableRData:Boolean;       //标识R0和R1的值是不可靠的 (来源为dbcc page
    R0:Pointer;                    //新数据
    R1:Pointer;                    //老数据
    UniqueClusteredKeys:string;
    deleteFlag:Boolean;            //数据删除标志（ 为ture的数据不生产Sql
    //
    old_data:Tsql2014RowData;
    new_data:Tsql2014RowData;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Pretreatment;
  end;


  TMIX_DATA_Item = class(TObject)
    Idx: QWORD;
    data: TBytes;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TMIX_DATAs = class(TObject)
    FItems: TObjectList;
  public
    function GetItem(Key: Qword): TMIX_DATA_Item;
    constructor Create;
    destructor Destroy; override;
  end;

  TSql2014logAnalyzer = class(TlogAnalyzer)
  private
    FPkgMgr:TTransPkgMgr; //事务队列

    TransId: TTrans_Id;
    TransBeginTime: TDateTime;
    TransCommitTime: TDateTime;
    FLogSource: TLogSource;
    //每个事务开始要重新初始化以下对象
    FRows: TObjectList;
    MIX_DATAs: TMIX_DATAs;
    DDL: TDDLMgr;
    AllocUnitMgr: TAllocUnitMgr;
    IDXs:TDDL_Idxs_ColsMgr;
    procedure serializeToBin(FTranspkg: TTransPkg; var mm: TMemory_data);
    procedure PriseRowLog(tPkg: TTransPkgItem);
    procedure PriseRowLog_Insert(tPkg: TTransPkgItem);
    function getDataFrom_TEXT_MIX(idx: TBytes): TBytes;
    function DML_BuilderSql(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Insert(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Update(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Delete(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Where(aRowData: Tsql2014Opt): string;
    function Read_LCX_TEXT_MIX_DATA(tPkg: TTransPkgItem; BinReader: TbinDataReader): TBytes;
    procedure PriseDDLPkg(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysrscols(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysschobjs(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysobjvalues(DataRow: Tsql2014Opt);
    function GenSql: string;
    function GenSql_CreateDefault(ddlitem: TDDLItem): string;
    function GenSql_CreateTable(ddlitem: TDDLItem): string;
    procedure PriseRowLog_Delete(tPkg: TTransPkgItem);
    function PriseRowLog_InsertDeleteRowData(DbTable: TdbTableItem; BinReader: TbinDataReader): Tsql2014RowData;
    procedure PriseDDLPkg_D(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_U(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_D_syscolpars(DataRow: Tsql2014Opt);
    function GenSql_DDL_Insert(ddlitem: TDDLItem_Insert): string;
    function GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
    function GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
    function GenSql_DropDefault(ddlitem: TDDL_Delete_Def): string;
    function GenSql_DropTable(ddlitem: TDDL_Delete_Table): string;
    procedure PriseDDLPkg_sysiscols(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_syssingleobjrefs(DataRow: Tsql2014Opt);
    function GenSql_CreatePrimaryKey(ddlitem: TDDL_Create_PrimaryKey): string;
    procedure Execute2(FTranspkg: TTransPkg);
    procedure PriseDDLPkg_syscolpars(DataRow: Tsql2014Opt);
    function GenSql_CreateColumn(ddlitem: TDDL_Create_Column): string;
    function getColsTypeStr(col: TdbFieldItem): string;
    function GenSql_DropColumn(ddlitem: TDDL_Delete_Column): string;
    procedure PriseRowLog_MODIFY_ROW(tPkg: TTransPkgItem);
    procedure PriseRowLog_MODIFY_COLUMNS(tPkg: TTransPkgItem);
    function PriseRowLog_UniqueClusteredKeys(BinReader: TbinDataReader; DbTable: TdbTableItem): string;
  public
    /// <summary>
    ///
    /// </summary>
    /// <param name="PkgMgr">事务队列</param>
    /// <param name="LogSource">数据源</param>
    constructor Create(PkgMgr:TTransPkgMgr; LogSource: TLogSource);
    destructor Destroy; override;
    procedure Execute; override;
    /// <summary>
    /// 将表更改操作，应用到当前系统。以免读取的日志与表结构不匹配
    /// </summary>
    procedure ApplySysDDLChange;
  end;

implementation

uses
  loglog, plugins, OpCode, hexValUtils, contextCode, dbFieldTypes,
  Memory_Common, sqlextendedprocHelper;

type
  TRawElement = packed record
    Offset: Cardinal;
    Length: Word;
  end;

{ TSql2014logAnalyzer }

constructor TSql2014logAnalyzer.Create(PkgMgr:TTransPkgMgr;LogSource: TLogSource);
begin
  inherited Create(False);

  FPkgMgr := PkgMgr;
  FLogSource := LogSource;
  FRows := TObjectList.Create;
  FRows.OwnsObjects := True;
  MIX_DATAs := TMIX_DATAs.Create;
  DDL := TDDLMgr.Create;
  AllocUnitMgr := TAllocUnitMgr.Create;
  IDXs:=TDDL_Idxs_ColsMgr.Create;

  Self.NameThreadForDebugging('TSql2014logAnalyzer', Self.ThreadID);
end;

destructor TSql2014logAnalyzer.Destroy;
begin
  FRows.Clear;
  FRows.Free;
  MIX_DATAs.Free;
  DDL.Free;
  AllocUnitMgr.Free;
  IDXs.Free;
  inherited;
end;

procedure TSql2014logAnalyzer.ApplySysDDLChange;
var
  I:Integer;
  ddlitem :TDDLItem;
  ctable:TDDL_Create_Table;
  dtable:TDDL_Delete_Table;

  cColumn:TDDL_Create_Column;
  dColumn:TDDL_Delete_Column;

  TableObj: TdbTableItem;
begin
  for I := 0 to DDL.FItems.Count - 1 do
  begin
    ddlitem := TDDLItem(DDL.FItems[I]);
    if (ddlitem.OpType=Opt_Insert) then
    begin
      if ddlitem.xType = 'u' then
      begin
        ctable := TDDL_Create_Table(ddlitem);
        FLogSource.Fdbc.dict.tables.addTable(ctable.TableObj);
        ctable.TableObj := nil;
      end else if ddlitem.xType = 'column' then
      begin
        cColumn:=TDDL_Create_Column(ddlitem);
        cColumn.Table.Fields.addField(cColumn.field);
      end;

    end else if (ddlitem.OpType=Opt_Delete) then
    begin
      if ddlitem.xType = 'u' then
      begin
        dtable := TDDL_Delete_Table(ddlitem);
        FLogSource.Fdbc.dict.tables.RemoveTable(dtable.getObjId);
      end else if ddlitem.xType = 'column' then
      begin
        dColumn := TDDL_Delete_Column(ddlitem);
        TableObj := FLogSource.Fdbc.dict.tables.GetItemById(dColumn.TableId);
        if TableObj<>nil then
        begin
          TableObj.Fields.RemoveField(dColumn.objName);
        end;
      end;

    end else if (ddlitem.OpType = Opt_Update) then begin
      //todo:修改

    end;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql(aRowData: Tsql2014Opt): string;
begin
  if not aRowData.deleteFlag then
  begin
    case aRowData.OperaType of
      Opt_Insert:
        Result := DML_BuilderSql_Insert(aRowData);
      Opt_Update:
        Result := DML_BuilderSql_Update(aRowData);
      Opt_Delete:
        Result := DML_BuilderSql_Delete(aRowData);
    else
      Loger.Add('尚未定義的SQLBuilder');
    end;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql_Update(aRowData: Tsql2014Opt): string;
function binEquals(v1, v2: TBytes): Boolean;
begin
  if v1 = v2 then
  begin
    Result := True;
  end else if Length(v1) <> Length(v2) then begin
    Result := False;
  end else begin
    Result := CompareMem(@v1[0], @v2[0], Length(v1));
  end;
end;

var
  updateStr:string;
  I: Integer;
  raw_old,raw_new: PdbFieldValue;
  whereStr: string;
  fieldval: PdbFieldValue;
  isUniClustered :Boolean;
  J: Integer;
begin
  whereStr := aRowData.UniqueClusteredKeys;
  if whereStr='' then
  begin
    //没有聚合键
    if aRowData.old_data<>nil then
    begin
      //有old源则通过olddata生成where
      for I := 0 to aRowData.old_data.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.old_data.Fields[I]);
        whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
      end;
      if whereStr.Length > 0 then
      begin
        Delete(whereStr, 1, 4);  //"and "
      end;
    end else begin
      //没有唯一聚合,也没有old源
      whereStr :=' 1=2 --表不包涵唯一聚合,且无法获取更新源。请为表设置“唯一聚合”或使用数据源提取插件';
    end
  end;

  if aRowData.new_data = nil then
  begin
    //没有新数据。使用select封装
    updateStr := FLogSource.Fdbc.getUpdateSQLfromSelect(aRowData.Table, whereStr);
    if updateStr='' then
    begin
      Result := '数据行已丢失！'+whereStr;
      Exit;
    end;
  end else begin
    if aRowData.old_data<>nil then
    begin
      //新旧数据都有，则对比差异生成update
      updateStr := '';
      for I := 0 to aRowData.Table.Fields.Count - 1 do
      begin
        raw_old := aRowData.old_data.getField(aRowData.Table.Fields[i].Col_id);
        raw_new := aRowData.new_data.getField(aRowData.Table.Fields[i].Col_id);
        if (raw_new=nil)  and (raw_old=nil)then
        begin

        end else
        if raw_new = nil then
        begin
          //var 值 ————>  null
          updateStr := updateStr + Format(', %s=NULL',[raw_old.field.getSafeColName]);
        end else if (raw_old = nil) or (not binEquals(raw_new.value, raw_old.value)) then begin
          updateStr := updateStr + Format(', %s=%s',[raw_new.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(raw_new.field, raw_new.value)]);
        end
      end;
      if updateStr.Length > 0 then
        Delete(updateStr, 1, 2);  //", "
    end else begin
      //没有old，根据新的全部字段生成update（除唯一聚合，如果存在
      updateStr := '';
      for I := 0 to aRowData.Table.Fields.Count - 1 do
      begin
        isUniClustered := False;
        for J := 0 to aRowData.Table.UniqueClusteredKeys.Count-1 do
        begin
          if TdbFieldItem(aRowData.Table.UniqueClusteredKeys[j]).Col_id = aRowData.Table.Fields[i].Col_id then
          begin
            isUniClustered := True;
            Break;
          end;
        end;

        if not isUniClustered then
        begin
          raw_new := aRowData.new_data.getField(aRowData.Table.Fields[i].Col_id);
          if raw_new = nil then
          begin
            //var 值 ————>  null
            updateStr := updateStr + Format(', %s=NULL',[raw_new.field.getSafeColName]);
          end else begin
            updateStr := updateStr + Format(', %s=%s',[raw_new.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(raw_new.field, raw_new.value)]);
          end;
        end;
      end;
      if updateStr.Length > 0 then
        Delete(updateStr, 1, 2);  //", "
    end
  end;
  Result := Format('UPDATE %s SET %s WHERE %s;', [aRowData.Table.getFullName, updateStr, whereStr]);
end;

function TSql2014logAnalyzer.DML_BuilderSql_Where(aRowData: Tsql2014Opt): string;
var
  whereStr: string;
  I: Integer;
  fieldval: PdbFieldValue;
begin
  if aRowData.UniqueClusteredKeys <> '' then
  begin
    Result := aRowData.UniqueClusteredKeys;
  end
  else
  begin
    whereStr := '';
    for I := 0 to aRowData.new_data.Fields.Count - 1 do
    begin
      fieldval := PdbFieldValue(aRowData.new_data.Fields[I]);
      whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
    end;
    if whereStr.Length > 0 then
    begin
      Delete(whereStr, 1, 4);  //"and "
    end;
    Result := whereStr;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql_Insert(aRowData: Tsql2014Opt): string;
var
  fields: string;
  StrVal: string;
  I: Integer;
  fieldval: PdbFieldValue;
begin
  fields := '';
  StrVal := '';
  for I := 0 to aRowData.new_data.Fields.Count - 1 do
  begin
    fieldval := PdbFieldValue(aRowData.new_data.Fields[I]);
    fields := fields + ',' + fieldval.field.getSafeColName;
    StrVal := StrVal + ',' + Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value);
  end;
  if aRowData.new_data.Fields.Count > 0 then
  begin
    Delete(fields, 1, 1);
    Delete(StrVal, 1, 1);
  end;
  Result := Format('INSERT INTO %s(%s)values(%s);', [aRowData.Table.getFullName, fields, StrVal]);
end;

function TSql2014logAnalyzer.DML_BuilderSql_Delete(aRowData: Tsql2014Opt): string;
var
  whereStr: string;
  I,j: Integer;
  field: TdbFieldItem;
  fieldval: PdbFieldValue;
begin
  if aRowData.table.UniqueClusteredKeys.Count>0 then
  begin
    whereStr := '';
    for I := 0 to aRowData.table.UniqueClusteredKeys.Count-1 do
    begin
      field := TdbFieldItem(aRowData.table.UniqueClusteredKeys[i]);
      for J := 0 to aRowData.new_data.Fields.Count -1 do
      begin
        fieldval := PdbFieldValue(aRowData.new_data.Fields[j]);
        if fieldval.field.Col_id=field.Col_id then
        begin
          whereStr := whereStr + Format('and %s=%s ', [field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(field, fieldval.value)]);
          Break;
        end;
      end;
    end;
    Delete(whereStr, 1, 4);
  end else
    whereStr := DML_BuilderSql_Where(aRowData);
  Result := Format('DELETE FROM %s WHERE %s;', [aRowData.Table.getFullName, whereStr]);
end;

procedure TSql2014logAnalyzer.Execute;
var
  TTsPkg: TTransPkg;
begin
  inherited;
  while not Terminated do
  begin
    if FPkgMgr.FpaddingPrisePkg.Count > 0 then
    begin
      TTsPkg := TTransPkg(FPkgMgr.FpaddingPrisePkg.Pop);
      try
        FRows.Clear;
        MIX_DATAs.FItems.Clear;
        DDL.FItems.Clear;
        AllocUnitMgr.FItems.Clear;
        IDXs.FItems.Clear;
        Execute2(TTsPkg);
      except
        on ee:Exception do
        begin
          Loger.Add('TSql2014logAnalyzer.事务块处理失败！TranId:' + TranId2Str(TTsPkg.Ftransid) + '.' + ee.Message, LOG_ERROR);
        end;
      end;
      TTsPkg.Free;
    end else begin
      Sleep(1000);
    end;
  end;
end;

procedure TSql2014logAnalyzer.Execute2(FTranspkg: TTransPkg);
var
  mm: TMemory_data;
  I: Integer;
  TTpi: TTransPkgItem;
  DataRow_buf:Tsql2014Opt;
  DMLitem: TDMLItem;
  TmpBinReader: TbinDataReader;
begin
  Loger.Add('TSql2014logAnalyzer.Execute ==> transId:%s, MinLsn:%s', [TranId2Str(FTranspkg.Ftransid),LSN2Str(TTransPkgItem(FTranspkg.Items[0]).lsn)]);
  //通知插件
  serializeToBin(FTranspkg, mm);
  PluginsMgr.onTransPkgRev(mm);
  FreeMem(mm.data);

  //开始解析数据
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    TTpi := TTransPkgItem(FTranspkg.Items[I]);
    PriseRowLog(TTpi);
  end;

  //分析Sql
  for I := 0 to FRows.Count - 1 do
  begin
    DataRow_buf := Tsql2014Opt(FRows[i]);
    if DataRow_buf.R0<>nil then
    begin
      TmpBinReader := TbinDataReader.Create(DataRow_buf.R0, $2000);
      try
        DataRow_buf.new_data := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
      finally
        TmpBinReader.Free;
      end;
      if (DataRow_buf.OperaType = Opt_Update) and (DataRow_buf.R1 <> nil) then
      begin
        TmpBinReader := TbinDataReader.Create(DataRow_buf.R1, $2000);
        try
          DataRow_buf.old_data := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
        finally
          TmpBinReader.Free;
        end;
      end;
    end;

    Loger.Add('-->' + DML_BuilderSql(DataRow_buf));
    //continue;
    if DataRow_buf.Table.Owner = 'sys' then
    begin
      //如果操作的是系统表则是ddl语句
      if DataRow_buf.OperaType = Opt_Insert then
      begin
        PriseDDLPkg(DataRow_buf);
      end
      else if DataRow_buf.OperaType = Opt_Delete then
      begin
        PriseDDLPkg_D(DataRow_buf);
      end
      else if DataRow_buf.OperaType = Opt_Update then
      begin
        PriseDDLPkg_U(DataRow_buf);
      end;

    end
    else
    begin
      // dml 语句
      DMLitem := TDMLItem.Create;
      DMLitem.data := DataRow_buf;
      DDL.Add(DMLitem);
    end;

  end;
  if DDL.FItems.Count>0 then
  begin
    ApplySysDDLChange;
  end;
  Loger.Add(GenSql);
end;

function TSql2014logAnalyzer.GenSql: string;
var
  ddlitem: TDDLItem;
  I: Integer;
  ResList: TStringList;
  Tmpstr:string;
begin
  ResList := TStringList.Create;
  try
    ResList.Add('--genSql begin--');
    ResList.Add('TransId:' + TranId2Str(TransId));
    ResList.Add('--TranBeinTime:' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransBeginTime));
    ResList.Add('--CommitTranTime:' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransCommitTime));

    for I := 0 to DDL.FItems.Count - 1 do
    begin
      Tmpstr := '';
      ddlitem := TDDLItem(DDL.FItems[I]);
      case ddlitem.OpType of
        Opt_Insert:
          Tmpstr := GenSql_DDL_Insert(TDDLItem_Insert(ddlitem));
        Opt_Update:
          Tmpstr := GenSql_DDL_Update(TDDLItem_Update(ddlitem));
        Opt_Delete:
          Tmpstr := GenSql_DDL_Delete(TDDLItem_Delete(ddlitem));
        Opt_DML:
          begin
            Tmpstr := DML_BuilderSql(TDMLItem(DDL.FItems[I]).data)
          end;
      end;
      if Tmpstr <> '' then
        ResList.Add(Tmpstr);
    end;
    ResList.Add('--genSql end--');
    Result := ResList.Text;
  finally
    ResList.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_DDL_Insert(ddlitem: TDDLItem_Insert): string;
begin
  if ddlitem.xType = 'u' then
  begin
    Result := GenSql_CreateTable(ddlitem);
  end
  else if ddlitem.xType = 'd' then
  begin
    Result := GenSql_CreateDefault(ddlitem);
  end else if ddlitem.xType = 'pk' then
  begin
    Result := GenSql_CreatePrimaryKey(TDDL_Create_PrimaryKey(ddlitem));
  end else if ddlitem.xType = 'column' then
  begin
    Result := GenSql_CreateColumn(TDDL_Create_Column(ddlitem));
  end
  else
  begin
    //TODO:GenSql_DDL_Insert
  end;
end;

function TSql2014logAnalyzer.GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
begin
  if ddlitem.xType = 'u' then
  begin
    Result := GenSql_DropTable(TDDL_Delete_Table(ddlitem));
  end
  else if ddlitem.xType = 'd' then
  begin
    Result := GenSql_DropDefault(TDDL_Delete_Def(ddlitem));
  end else if ddlitem.xType = 'column' then
  begin
    Result := GenSql_DropColumn(TDDL_Delete_Column(ddlitem));
  end
  else
  begin

  end;
  //TODO:GenSql_DDL_Delete
end;

function TSql2014logAnalyzer.GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
begin
  //TODO:GenSql_DDL_Update
end;

function TSql2014logAnalyzer.GenSql_DropColumn(ddlitem: TDDL_Delete_Column): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s drop column %s;';
var
  Table:TdbTableItem;
  DDLtable: TDDLItem;
begin
  Result := '--drop Column table id:'+IntToStr(ddlitem.TableId);

  DDLtable := ddl.GetItem(ddlitem.TableId);
  if DDLtable <> nil then
  begin
    Table := TDDL_Create_Table(DDLtable).TableObj;
  end
  else
  begin
    Table := FLogSource.Fdbc.dict.tables.GetItemById(ddlitem.TableId);
  end;
  if Table<>nil then
  begin
    Result := Result + #$D#$A + Format(SQLTEMPLATE, [Table.getFullName, ddlitem.objName]);
  end else begin
    Result := Result + #$D#$A + '/*';
    Result := Result + #$D#$A + Format(SQLTEMPLATE, ['#'+IntToStr(ddlitem.TableId), ddlitem.objName]);
    Result := Result + #$D#$A + '*/';
  end;
end;

function TSql2014logAnalyzer.GenSql_DropTable(ddlitem: TDDL_Delete_Table): string;
begin
  Result := '--drop TABLE ID :'+IntToStr(ddlitem.objId);
  Result := Result + #$D#$A + Format('DROP TABLE [%s].[%s]',[ddlitem.Owner,ddlitem.objName]);
end;

function TSql2014logAnalyzer.GenSql_DropDefault(ddlitem: TDDL_Delete_Def): string;
var
  Table:TdbTableItem;
  resStr:Tstringlist;
begin
  resStr := Tstringlist.Create;
  try
    resStr.Add('--drop default constraint');
    resStr.Add('--TableId:'+IntToStr(ddlitem.ParentId));
    resStr.Add('--ObjId:'+IntToStr(ddlitem.objId));
    resStr.Add('--objName:'+ddlitem.objName);
    Table := FLogSource.Fdbc.dict.tables.GetItemById(ddlitem.tableid);
    if Table = nil then
    begin
      resStr.Add(Format('-- alter table #%d drop constraint %s;',[ddlitem.ParentId,ddlitem.objName]));
    end
    else
    begin
      resStr.Add(Format('alter table %s drop constraint [%s];',[table.getFullName, ddlitem.objName]));
    end;
    Result := resStr.Text;
  finally
    resStr.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_CreateColumn(ddlitem: TDDL_Create_Column): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s ADD [%s] %s; ';
var
  resStr:Tstringlist;
  tmpStr:string;
begin
  resStr:=Tstringlist.Create;
  try
    resStr.Add('--ALTER TABLE Add Column');
    resStr.Add('--Tableid:'+inttostr(ddlitem.Table.TableId));
    resStr.Add('--columnName:'+ddlitem.field.ColName);
    tmpStr := getColsTypeStr(ddlitem.field) + ' ';
    if ddlitem.field.is_nullable then
    begin
      tmpStr := tmpStr + 'NULL';
    end
    else
    begin
      tmpStr := tmpStr + 'NOT NULL';
    end;

    resStr.Add(Format(SQLTEMPLATE, [ddlitem.Table.getFullName, ddlitem.field.ColName, tmpStr]));
    Result := resStr.Text;
  finally
    resStr.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_CreatePrimaryKey(ddlitem: TDDL_Create_PrimaryKey): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s ADD CONSTRAINT [%s] PRIMARY KEY %s (%s) ';
var
  DDLtable: TDDLItem;
  tableL: TdbTableItem;
  tableName: string;
  colName: string;
  CLUSTEREDType:string;
  cols:TObjectList;
  I: Integer;
  TempItem:TDDL_Idxs_ColsItem;
  dbfield:TdbFieldItem;
  resStr:Tstringlist;

  hasError:Boolean;
begin
  hasError := False;
  DDLtable := ddl.GetItem(ddlitem.tableid);
  if DDLtable <> nil then
  begin
    tableL := TDDL_Create_Table(DDLtable).TableObj;
  end
  else
  begin
    tableL := FLogSource.Fdbc.dict.tables.GetItemById(ddlitem.tableid);
  end;

  cols := IDXs.GetById(ddlitem.tableid);
  if (cols = nil) or (cols.Count = 0) then
  begin
    colName := '#';
  end
  else
  begin
    colName := '';
    if tableL = nil then
    begin
      hasError := True;
      for I := 0 to cols.Count - 1 do
      begin
        TempItem := TDDL_Idxs_ColsItem(cols[I]);
        colName := colName + ',' + inttostr(TempItem.idxId) + ' ' + TempItem.orderType;
      end;
    end
    else
    begin
      for I := 0 to cols.Count - 1 do
      begin
        TempItem := TDDL_Idxs_ColsItem(cols[I]);
        dbfield := tableL.Fields.GetItemById(TempItem.ColId);
        if dbfield = nil then
        begin
          hasError := True;
          colName := colName + ',' + inttostr(TempItem.idxId) + ' ' + TempItem.orderType;
        end
        else
        begin
          colName := colName + ',' + dbfield.ColName + ' ' + TempItem.orderType;
        end;
      end;
      Delete(colName, 1, 1);
    end;
  end;

  if tableL=nil then
  begin
    tableName := '#'+inttostr(ddlitem.tableid);
    hasError := True;
  end else begin
    tableName := tableL.getFullName;
  end;
  if ddlitem.isCLUSTERED then
    CLUSTEREDType := 'CLUSTERED'
  else
    CLUSTEREDType := 'NONCLUSTERED';

  resStr:=Tstringlist.Create;
  try
    resStr.Add('--Create primary key');
    resStr.Add('--Tableid:'+inttostr(ddlitem.tableid));
    resStr.Add('--Pkid:'+inttostr(ddlitem.objId));
    resStr.Add('--PkName:'+ddlitem.objName);
    if hasError then
    begin
      resStr.Add('/*')
    end;
    resStr.Add(Format(SQLTEMPLATE, [tableName, ddlitem.objName, CLUSTEREDType, colName]));
    if hasError then
    begin
      resStr.Add('*/')
    end;
    Result := resStr.Text;
  finally
    resStr.Free;
  end;
end;

function TSql2014logAnalyzer.getColsTypeStr(col: TdbFieldItem): string;
begin
  case col.type_id of
    MsTypes.IMAGE:
      Result := 'IMAGE';
    MsTypes.TEXT:
      Result := 'TEXT';
    MsTypes.UNIQUEIDENTIFIER:
      Result := 'UNIQUEIDENTIFIER';
    MsTypes.DATE:
      Result := 'DATE';
    MsTypes.TIME:
      Result := Format('TIME(%d)', [col.scale]);
    MsTypes.DATETIME2:
      Result := Format('DATETIME2(%d)', [col.scale]);
    MsTypes.DATETIMEOFFSET:
      Result := Format('DATETIMEOFFSET(%d)', [col.scale]);
    MsTypes.TINYINT:
      Result := 'TINYINT';
    MsTypes.SMALLINT:
      Result := 'SMALLINT';
    MsTypes.INT:
      Result := 'INT';
    MsTypes.SMALLDATETIME:
      Result := 'SMALLDATETIME';
    MsTypes.REAL:
      Result := 'REAL';
    MsTypes.MONEY:
      Result := 'MONEY';
    MsTypes.DATETIME:
      Result := 'DATETIME';
    MsTypes.FLOAT:
      Result := 'FLOAT';
    MsTypes.SQL_VARIANT:
      Result := 'SQL_VARIANT';
    MsTypes.NTEXT:
      Result := 'NTEXT';
    MsTypes.BIT:
      Result := 'BIT';
    MsTypes.DECIMAL:
      Result := Format('DECIMAL(%d,%d)', [col.procision, col.scale]);
    MsTypes.NUMERIC:
      Result := Format('NUMERIC(%d,%d)', [col.procision, col.scale]);
    MsTypes.SMALLMONEY:
      Result := 'SMALLMONEY';
    MsTypes.BIGINT:
      Result := 'BIGINT';
    MsTypes.VARBINARY:
      Result := Format('VARBINARY(%d)', [col.Max_length]);
    MsTypes.VARCHAR:
      Result := Format('VARCHAR(%d)', [col.Max_length]);
    MsTypes.BINARY:
      Result := Format('BINARY(%d)', [col.Max_length]);
    MsTypes.CHAR:
      Result := Format('CHAR(%d)', [col.Max_length]);
    MsTypes.TIMESTAMP:
      Result := 'TIMESTAMP';
    MsTypes.NVARCHAR:
      Result := Format('NVARCHAR(%d)', [col.Max_length]);
    MsTypes.NCHAR:
      Result := Format('NCHAR(%d)', [col.Max_length]);
    MsTypes.XML:
      Result := 'XML';
    MsTypes.GEOGRAPHY:
      Result := 'GEOGRAPHY';
  else
    Result := '';
  end;
end;

function TSql2014logAnalyzer.GenSql_CreateTable(ddlitem: TDDLItem): string;
const
  SQLTEMPLATE = 'CREATE TABLE %s(%s);';
var
  table: TDDL_Create_Table;
  colsStr: TStringList;
  I: Integer;
  tmpStr: string;
begin
  table := TDDL_Create_Table(ddlitem);
  colsStr := TStringList.Create;
  try
    colsStr.Add(Format('-- Table id :%d', [table.TableObj.TableId]));
    colsStr.Add(Format('CREATE TABLE %s(', [table.TableObj.getFullName]));
    for I := 0 to table.TableObj.Fields.Count - 1 do
    begin
      tmpStr := table.TableObj.Fields[I].ColName + ' ';
      tmpStr := tmpStr + getColsTypeStr(table.TableObj.Fields[I]) + ' ';
      if table.TableObj.Fields[I].is_nullable then
      begin
        tmpStr := tmpStr + 'NULL, ';
      end
      else
      begin
        tmpStr := tmpStr + 'NOT NULL, ';
      end;
      colsStr.Add(tmpStr);
    end;
    colsStr.Add(');');
    Result := colsStr.Text;
  finally
    colsStr.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_CreateDefault(ddlitem: TDDLItem): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s add constraint [%s] default %s for %s;';
var
  DDLtable: TDDLItem;
  tableL: TdbTableItem;
  DefObj: TDDL_Create_Def;
  ResStr: TStringList;
  tableName: string;
  colName: string;
begin
  DefObj := TDDL_Create_Def(ddlitem);
  DDLtable := ddl.GetItem(DefObj.tableid);
  if DDLtable <> nil then
  begin
    tableL := TDDL_Create_Table(DDLtable).TableObj;
  end
  else
  begin
    tableL := FLogSource.Fdbc.dict.tables.GetItemById(DefObj.tableid);
  end;

  ResStr := TStringList.Create;
  try
    if tableL = nil then
    begin
      tableName := '#' + IntToStr(DefObj.tableid);
      colName := '#' + IntToStr(DefObj.colid);
      ResStr.Add('-- generate Default constraint fail. the table object has been loss from database.');
      ResStr.Add(Format('-- Table id :%d', [DefObj.tableid]));
      ResStr.Add(Format('-- Constraint id :%d', [DefObj.objId]));
      ResStr.Add('/*');
      ResStr.Add(Format(SQLTEMPLATE, [tableName, DefObj.objName, DefObj.value, colName]));
      ResStr.Add('*/');
    end
    else
    begin
      ResStr.Add(Format('-- Constraint id :%d', [DefObj.objId]));
      tableName := tableL.getFullName;
      colName := tableL.Fields.GetItemById(DefObj.colid).colName;
      ResStr.Add(Format(SQLTEMPLATE, [tableName, DefObj.objName, DefObj.value, colName]));
    end;
    Result := ResStr.Text;
  finally
    ResStr.Free;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D(DataRow: Tsql2014Opt);
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    //删除表,存储过程、视图 、默认值等对象
    PriseDDLPkg_D_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    //删除表列
    PriseDDLPkg_D_syscolpars(DataRow);
  end
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D_syscolpars(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  TableId: Integer;
  ColName: string;
  ColObj: TDDL_Delete_Column;
begin
  TableId := 0;
  ColName := '';

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'id' then
    begin
      TableId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ColName := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end;
  end;

  ColObj := TDDL_Delete_Column.Create;
  ColObj.TableId := TableId;
  ColObj.objName := ColName;
  DDL.Add(ColObj);
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_U(DataRow: Tsql2014Opt);
begin
  //todo:PriseDDLPkg_U
end;

procedure TSql2014logAnalyzer.PriseDDLPkg(DataRow: Tsql2014Opt);
var
  rowsetid: int64;
  ObjId: Integer;
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    //新增表,存储过程、视图 、默认值等对象
    PriseDDLPkg_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    PriseDDLPkg_syscolpars(DataRow);
  end
  else if DataRow.Table.TableNmae = 'sysrowsets' then
  begin
    rowsetid := StrToInt64(DataRow.new_data.getFieldStrValue('rowsetid'));
    ObjId := StrToInt(DataRow.new_data.getFieldStrValue('idmajor'));
    AllocUnitMgr.Add(rowsetid, ObjId);
  end
  else if DataRow.Table.TableNmae = 'sysrscols' then
  begin
    PriseDDLPkg_sysrscols(DataRow);
  end
  else if DataRow.Table.TableNmae = 'sysobjvalues' then
  begin
    //默认值——值
    PriseDDLPkg_sysobjvalues(DataRow);
  end else if DataRow.Table.TableNmae = 'sysiscols' then
  begin
    //index fields
    PriseDDLPkg_sysiscols(DataRow);
  end else if DataRow.Table.TableNmae = 'syssingleobjrefs' then
  begin
    //index 信息 (是否集合索引)
    PriseDDLPkg_syssingleobjrefs(DataRow);
  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_syscolpars(DataRow: Tsql2014Opt);
var
  ddlitem: TDDLItem;
  FieldItem: TdbFieldItem;
  table:TdbTableItem;
  //tmpVar
  collation_id: Integer;
  TmpStr: string;
  ObjId: Integer;
  ddl_col:TDDL_Create_Column;
begin
  if TryStrToInt(DataRow.new_data.getFieldStrValue('id'), ObjId) then
  begin
    ddlitem := DDL.GetItem(ObjId);
    FieldItem := TdbFieldItem.Create;
    FieldItem.Col_id := StrToInt(DataRow.new_data.getFieldStrValue('colid'));
    FieldItem.ColName := DataRow.new_data.getFieldStrValue('name');
    FieldItem.type_id := StrToInt(DataRow.new_data.getFieldStrValue('xtype'));
    FieldItem.Max_length := StrToInt(DataRow.new_data.getFieldStrValue('length'));
    FieldItem.procision := StrToInt(DataRow.new_data.getFieldStrValue('prec'));
    FieldItem.scale := StrToInt(DataRow.new_data.getFieldStrValue('scale'));
    collation_id := StrToInt(DataRow.new_data.getFieldStrValue('collationid'));
    FieldItem.collation_name := FLogSource.Fdbc.GetCollationPropertyFromId(collation_id);
    if FieldItem.collation_name <> '' then
    begin
      TmpStr := FLogSource.Fdbc.GetCodePageFromCollationName(FieldItem.collation_name);
      if TmpStr <> '' then
      begin
        FieldItem.CodePage := StrToIntDef(TmpStr, -1);
      end
      else
      begin
        FieldItem.CodePage := -1;
      end;
    end;

    if (ddlitem <> nil) and (ddlitem.xType = 'u') then
    begin
      //表添加字段
      TDDL_Create_Table(ddlitem).TableObj.Fields.addField(FieldItem);
    end
    else
    begin
      table := FLogSource.Fdbc.dict.tables.GetItemById(ObjId);
      if table<>nil then
      begin
        ddl_col := TDDL_Create_Column.Create;
        ddl_col.Table := table;
        ddl_col.field := FieldItem;
        DDL.Add(ddl_col);
      end else begin
        FieldItem.Free;
        //不是创建表，也不是新增列
        raise Exception.Create('Error Message:PriseDDLPkg_syscolpars not Create table Or add Column');
      end;
    end;
  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_syssingleobjrefs(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  objId: Integer;
  indepid:Integer;

  ddlitem:TDDLItem;
  pkObj:TDDL_Create_PrimaryKey;
begin
  objId := 0;
  indepid := 0;

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'depid' then
    begin
      objId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'indepid' then
    begin
      indepid := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;

  ddlitem := DDL.GetItem(objId);
  if (ddlitem = nil) or (ddlitem.OpType <> Opt_Insert) then
  begin
    raise Exception.Create('pkValue No found!');
  end else begin
    if ddlitem.xType = 'pk' then
    begin
      pkObj:=TDDL_Create_PrimaryKey(ddlitem);
      pkObj.isCLUSTERED := indepid = 1;
    end else
    begin
      raise Exception.Create('Error Message:PriseDDLPkg_syssingleobjrefs Error Xtype!');
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysiscols(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  objId: Integer;
  indexId:Integer;
  status:Integer;
  fieldId:Integer;

begin
  objId := 0;
  indexId := 0;
  status := 0;
  fieldId := 0;

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'idmajor' then
    begin
      objId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'idminor' then
    begin
      indexId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'status' then
    begin
      status := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'intprop' then
    begin
      fieldId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;
  IDXs.Add(objId, indexId, fieldId, (status and 4) > 0);
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysobjvalues(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  objId: Integer;
  value: string;
  ddlitem: TDDLItem;
  DefObj: TDDL_Create_Def;
begin
  objId := 0;
  value := '';

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'objid' then
    begin
      objId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'imageval' then
    begin
      value := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end;
  end;

  ddlitem := DDL.GetItem(objId);
  if ddlitem=nil then
  begin
    raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.1');
  end else begin
    if ddlitem.xType = 'd' then
    begin
      DefObj := TDDL_Create_Def(ddlitem);
      DefObj.value := hexToAnsiiData(value);
    end
    else if ddlitem.xType = 'u' then begin

    end else
    begin
      raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.2');
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014Opt);

  procedure DeleteTablesSubObj(tableId: Integer);
  var
    I: Integer;
    ddlitem: TDDLItem_Delete;
  begin
    //删除表中的子元素，
    //删除表的时候，日志是一列一列删除，最后再删除表对象的，
    //而语句，只用删除表，子对象自动全部删除
    for I := DDl.FItems.Count - 1 downto 0 do
    begin
      if TDDLItem(DDl.FItems[I]).OpType = Opt_Delete then
      begin
        ddlitem := TDDLItem_Delete(DDl.FItems[i]);
        if ddlitem.ParentId = tableId then
        begin
          DDl.FItems.Delete(I);
        end;
      end;
    end;
  end;

var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  ObjId: Integer;
  ObjName: string;
  nsid: Integer;
  ObjType: string;
  pid: Integer;
//  initprop: Integer; //如果对象是表值为表总列数，如果是默认值为列id

  table: TDDL_Delete_Table;
  DefObj: TDDL_Delete_Def;
begin
  ObjId := 0;
  ObjName := '';
  nsid := 0;
  ObjType := '';
  pid := 0;
//  initprop := 0;

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'id' then
    begin
      ObjId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ObjName := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'nsid' then
    begin
      nsid := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'type' then
    begin
      ObjType := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'pid' then
    begin
      pid := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'intprop' then
    begin
//      initprop := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;
  ObjType := Trim(LowerCase(ObjType));

  if ObjType = 'u' then
  begin
    //表
    table := TDDL_Delete_Table.Create;
    table.objId := ObjId;
    table.objName := ObjName;
    table.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
    //如果删除表，这里要处理掉删除字段，删除默认值等对象数据
    DeleteTablesSubObj(ObjId);
  end
  else if ObjType = 'v' then
  begin
    //todo:视图

  end
  else if ObjType = 'p' then
  begin
    //todo:过程


  end
  else if ObjType = 'c' then
  begin
  //todo:check

  end
  else if ObjType = 'd' then
  begin
  //default
    DefObj := TDDL_Delete_Def.Create;
    DefObj.objId := ObjId;
    DefObj.objName := ObjName;
    DefObj.tableid := pid;
    DDL.Add(DefObj);
  end
  else if ObjType = 'pk' then
  begin
  //todo:primary key

  end
  else if ObjType = 'tr' then
  begin
  //todo:Trigger

  end
  else if ObjType = 'uq' then
  begin
  //todo:unique key


  end
  else if ObjType = 'fk' then
  begin
  //todo:FOREIGN key


  end
  else
  begin
  //未知对象

  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysschobjs(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  ObjId: Integer;
  ObjName: string;
  nsid: Integer;
  ObjType: string;
  pid: Integer;
  initprop: Integer; //如果对象是表值为表总列数，如果是默认值为列id

  table: TDDL_Create_Table;
  DefObj: TDDL_Create_Def;
  pkObj:TDDL_Create_PrimaryKey;
begin
  ObjId := 0;
  ObjName := '';
  nsid := 0;
  ObjType := '';
  pid := 0;
  initprop := 0;

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'id' then
    begin
      ObjId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ObjName := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'nsid' then
    begin
      nsid := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'type' then
    begin
      ObjType := Hvu_GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'pid' then
    begin
      pid := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'intprop' then
    begin
      initprop := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;
  ObjType := Trim(LowerCase(ObjType));

  if ObjType = 'u' then
  begin
    //表
    table := TDDL_Create_Table.Create;
    table.TableObj.TableId := ObjId;
    table.TableObj.TableNmae := ObjName;
    table.TableObj.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
  end
  else if ObjType = 'v' then
  begin
    //todo:视图

  end
  else if ObjType = 'p' then
  begin
    //todo:过程


  end
  else if ObjType = 'c' then
  begin
  //todo:check

  end
  else if ObjType = 'd' then
  begin
  //default
    DefObj := TDDL_Create_Def.Create;
    DefObj.objId := ObjId;
    DefObj.objName := ObjName;
    DefObj.tableid := pid;
    DefObj.colid := initprop;
    DDL.Add(DefObj);
  end
  else if ObjType = 'pk' then
  begin
    //primary key
    pkObj := TDDL_Create_PrimaryKey.Create;
    pkObj.objId := ObjId;
    pkObj.objName := ObjName;
    pkObj.tableid := pid;
    DDL.Add(pkObj);
  end
  else if ObjType = 'tr' then
  begin
  //todo:Trigger

  end
  else if ObjType = 'uq' then
  begin
  //todo:unique key


  end
  else if ObjType = 'fk' then
  begin
  //todo:FOREIGN key


  end
  else
  begin
  //未知对象

  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysrscols(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  rowsetid: int64;
  ColId: Integer;
  statusCode: Integer;
  ObjId: Integer;
  DataOffset: Integer;
  Nullbit: Integer;
  ddlitem: TDDLItem;
  table: TDDL_Create_Table;
  FieldItem: TdbFieldItem;
  cColumn:TDDL_Create_Column;
begin
  rowsetid := 0;
  ColId := 0;
  statusCode := 0;
  DataOffset := 0;
  Nullbit := 0;
  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'rsid' then
    begin
      rowsetid := StrToInt64(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'rscolid' then
    begin
      ColId := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'status' then
    begin
      statusCode := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'offset' then
    begin
      DataOffset := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'nullbit' then
    begin
      Nullbit := StrToInt(Hvu_GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;
  ObjId := AllocUnitMgr.GetObjId(rowsetid);
  if ObjId <> 0 then
  begin
    ddlitem := DDL.GetItem(ObjId);
    if (ddlitem <> nil) and (ddlitem.xType = 'u') then
    begin
      table := TDDL_Create_Table(ddlitem);
      FieldItem := table.TableObj.Fields.Items[ColId - 1];
      FieldItem.nullMap := Nullbit - 1;
      FieldItem.is_nullable := (statusCode and $80) = 0;
      FieldItem.leaf_pos := DataOffset;
    end
    else
    begin
      raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.2');
    end;
  end
  else
  begin
    //直接新增列，alter table xxx add xxx xx;
    ObjId := FLogSource.Fdbc.GetObjectIdByPartitionid(rowsetid);
    if ObjId <> 0 then
    begin
      for I := 0 to DDL.FItems.Count -1 do
      begin
        if DDL.FItems[i] is TDDL_Create_Column then
        begin
          cColumn := TDDL_Create_Column(DDL.FItems[I]);
          if (cColumn.table.TableId = ObjId) and (cColumn.field.Col_id = ColId) then
          begin
            cColumn.field.nullMap := Nullbit - 1;
            cColumn.field.is_nullable := (statusCode and $80) = 0;
            cColumn.field.leaf_pos := DataOffset;
          end;
        end;
      end;
    end else begin
      raise Exception.CreateFmt('Error Message:PriseDDLPkg_sysrscols.无法解析的 Partitionid:%d',[rowsetid]);
    end;

  end;
end;

function TSql2014logAnalyzer.getDataFrom_TEXT_MIX(idx: TBytes): TBytes;
var
  MIXDATAPkg: PLogMIXDATAPkg;
  MixItem: TMIX_DATA_Item;
begin
  MIXDATAPkg := @idx[0];
  MixItem := MIX_DATAs.GetItem(MIXDATAPkg.key);
  if MixItem = nil then
  begin
    raise Exception.CreateFmt('TSql2014logAnalyzer.getDataFrom_TEXT_MIX fail!Idx:%s', [bytestostr_singleHex(idx)]);
    Result := nil;
  end
  else
  begin
    Result := MixItem.data;
  end;
end;

function TSql2014logAnalyzer.PriseRowLog_InsertDeleteRowData(DbTable: TdbTableItem; BinReader: TbinDataReader): Tsql2014RowData;
var
  I: Integer;
  InsertRowFlag: Word;
  TmpInt: Integer;
  ColCnt: Word;
  DataRow: Tsql2014RowData;
  nullMap: TBytes;
  VarFieldValEndOffset: array of Word;
  VarFieldValBase: Cardinal;  //var 字段值开始位置
  boolbit: Integer;
  aField: TdbFieldItem;
  Idx, b: Integer;
  val_begin, val_len: Cardinal;
  fieldval: PdbFieldValue;
begin
  InsertRowFlag := BinReader.readWord;
  if (InsertRowFlag and $6) > 0 then
  begin
    //重复的压缩日志
    Result := nil;
    Exit;
  end;
  //DONE: 这里应该效验InsertRowFlag的特性
  TmpInt := BinReader.readWord; //列数量的 Offset
  BinReader.seek(TmpInt, soBeginning);
  ColCnt := BinReader.readWord;
  if ColCnt <> DbTable.Fields.Count then
  begin
    //UNIQUIFIER
    if (ColCnt <> DbTable.Fields.Count + 1) then
    begin
      raise Exception.Create('实际列数与日志不匹配！这可能是修改表后造成的！放弃解析！');
    end;
  end;
  DataRow := Tsql2014RowData.Create;
  if (InsertRowFlag and $10) > 0 then
  begin
    //nullMap := BinReader.readBytes((DbTable.Fields.Count + 7) shr 3);
    nullMap := BinReader.readBytes((ColCnt + 7) shr 3);
  end
  else
  begin
    //不包含NullData
    nullMap := nil;
  end;
  if (InsertRowFlag and $20) > 0 then
  begin
    TmpInt := BinReader.readWord; //var 字段数量
  end
  else
  begin
    //不包含varData
    TmpInt := 0;
  end;
  SetLength(VarFieldValEndOffset, TmpInt);
  for I := 0 to TmpInt - 1 do
  begin
    VarFieldValEndOffset[I] := BinReader.readWord;
  end;
  VarFieldValBase := BinReader.getRangePosition;
  boolbit := 0;
  for I := 0 to DbTable.Fields.Count - 1 do
  begin
    aField := DbTable.Fields[I];
    if not aField.isLogSkipCol then
    begin
      if aField.is_nullable then
      begin
        Idx := aField.nullMap shr 3;
        b := aField.nullMap and 7;
        if (nullMap[Idx] and (1 shl b)) > 0 then  //值为null
          Continue;
      end;

      if aField.leaf_pos < 0 then
      begin
        // var Field
        Idx := 0 - aField.leaf_pos - 1;
        if Idx < Length(VarFieldValEndOffset) then
        begin
          if Idx = 0 then
          begin
            val_begin := VarFieldValBase;
          end
          else
          begin
            val_begin := (VarFieldValEndOffset[Idx - 1] and $7FFF);
          end;
          val_len := (VarFieldValEndOffset[Idx] and $7FFF) - val_begin;
          if val_len <= 0 then
          begin
            Continue;
          end
          else
          begin
            New(fieldval);
            try
              fieldval.field := aField;
              BinReader.seek(val_begin, soBeginning);
              if (VarFieldValEndOffset[Idx] and $8000) > 0 then
              begin
                //如果最高位是1说明数据在LCX_TEXT_MIX包中
                fieldval.value := BinReader.readBytes($10);
                fieldval.value := getDataFrom_TEXT_MIX(fieldval.value);
              end
              else
              begin
                fieldval.value := BinReader.readBytes(val_len);
              end;
            except
              on exx: Exception do
              begin
                Dispose(fieldval);
                raise exx;
              end;
            end;
            DataRow.Fields.Add(fieldval);
          end;
        end;
      end
      else
      begin
        //fixed Field
        BinReader.seek(aField.leaf_pos, soBeginning);

        New(fieldval);
        try
          fieldval.field := aField;
          fieldval.value := BinReader.readBytes(aField.Max_length);
          if aField.type_id = MsTypes.BIT then
          begin
            if ((1 shl boolbit) and fieldval.value[0]) > 0 then
            begin
              fieldval.value[0] := 1;
            end
            else
            begin
              fieldval.value[0] := 0;
            end;
            boolbit := boolbit + 1;
            if boolbit = 8 then
              boolbit := 0;
          end;
        except
          on exx: Exception do
          begin
            Dispose(fieldval);
            raise exx;
          end;
        end;
        DataRow.Fields.Add(fieldval);
      end;
    end;
  end;
  Result := DataRow;
end;

procedure TSql2014logAnalyzer.PriseRowLog_Insert(tPkg: TTransPkgItem);
var
  Rldo: PRawLog_DataOpt;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  I: Integer;
  BinReader: TbinDataReader;
  TableId: Integer;
  DbTable: TdbTableItem;
  DataRow: Tsql2014Opt;
  TmpCPnt:UIntPtr;
  TmpSize:Cardinal;
begin
  DataRow := nil;
  BinReader := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_HEAP,      //堆表写入(没有聚合索引的表
      LCX_CLUSTERED: //聚合写入
        begin
          if (Rldo.normalData.FlagBits and 1)>0 then
          begin
            //Rollback tran
            //COMPENSATION    恢复事务中Delete的数据
            for I := 0 to FRows.Count - 1 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //撤销之前的数据
                if DataRow.OperaType=Opt_Insert then
                begin
                  //insert的数据。delete然后回滚delete
                  DataRow.deleteFlag := False;

                  TmpCPnt :=  UIntPtr(Rldo)+ SizeOf(TRawLog_DataOpt) ;
                  TmpSize := PWord(TmpCPnt)^;
                  TmpCPnt := TmpCPnt + Rldo.NumElements*2;
                  TmpCPnt := (TmpCPnt + 3) and $FFFFFFFC;

                  //只读第一个块放进buf就是了
                  if DataRow.R0<>nil then
                    FreeMemory(DataRow.R0);
                  DataRow.R0 := GetMemory(TmpSize);
                  Move(Pointer(TmpCPnt)^, DataRow.R0^, TmpSize);

                end else
                  DataRow.deleteFlag := True;

                Break;
              end
            end;
          end else begin
            SetLength(R_, Rldo.NumElements);
            SetLength(R_Info, Rldo.NumElements);
            BinReader := TbinDataReader.Create(tPkg.Raw);
            BinReader.seek(SizeOf(TRawLog_DataOpt), soBeginning);
            for I := 0 to Rldo.NumElements - 1 do
            begin
              R_Info[I].Length := BinReader.readWord;
            end;
            BinReader.alignTo4;
            for I := 0 to Rldo.NumElements - 1 do
            begin
              if R_Info[I].Length > 0 then
              begin
                R_Info[I].Offset := BinReader.Position;
                R_[I] := BinReader.readBytes(R_Info[I].Length);
                BinReader.alignTo4;
              end;
            end;
            //一般是 3 块数据 (可以有N个块
            //1至n-2. 真实写入的数据
            //n-1. 0 聚合索引信息（对于Insert日志，此值保持null
            //n. 表信息
            if R_Info[Rldo.NumElements - 1].Length = 0 then
            begin
              //整块移动数据，这个里直接忽略
              Exit;
            end;
            BinReader.SetRange(R_Info[Rldo.NumElements - 1].Offset, R_Info[Rldo.NumElements - 1].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //忽略的表
              Exit;
            end;

            DataRow := Tsql2014Opt.Create;
            DataRow.OperaType := Opt_Insert;
            DataRow.page := Rldo.pageId;
            DataRow.table := DbTable;
            DataRow.R0 := GetMemory(R_Info[0].Length);
            Move(Pointer(UIntPtr(Rldo)+R_Info[0].Offset)^, DataRow.R0^, R_Info[0].Length);
            FRows.Add(DataRow);
          end;
        end;
      LCX_INDEX_LEAF: //索引写入
        begin
          //这东西应该可以忽略吧？？？
        end;
      LCX_TEXT_MIX: //行分块数据 image,text,ntext之类的
        begin
          SetLength(R_, Rldo.NumElements);
          SetLength(R_Info, Rldo.NumElements);
          BinReader := TbinDataReader.Create(tPkg.Raw);
          BinReader.seek(SizeOf(TRawLog_DataOpt), soBeginning);
          for I := 0 to Rldo.NumElements - 1 do
          begin
            R_Info[I].Length := BinReader.readWord;
          end;
          BinReader.alignTo4;
          for I := 0 to Rldo.NumElements - 1 do
          begin
            if R_Info[I].Length > 0 then
            begin
              R_Info[I].Offset := BinReader.Position;
              R_[I] := BinReader.readBytes(R_Info[I].Length);
              BinReader.alignTo4;
            end;
          end;
          //开始读取R0
          BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
          Read_LCX_TEXT_MIX_DATA(tPkg, BinReader);
        end;
    else
      Loger.Add('PriseRowLog_Insert 遇到尚未处理的 ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
    end;
  finally
    if BinReader <> nil then
      BinReader.Free;
  end;
end;

function TSql2014logAnalyzer.Read_LCX_TEXT_MIX_DATA(tPkg: TTransPkgItem; BinReader: TbinDataReader): TBytes;
var
  RowFlag: Word;
  MixDataIdx: QWORD;
  MixDataLen: QWORD;
  MixItem: TMIX_DATA_Item;
  MixDataType: Word;
begin
  RowFlag := BinReader.readWord;
  { TODO -oChin -c : 测试用代码 2017-09-16 11:42:40 }
  if RowFlag <> $0008 then
  begin
    Loger.AddException('LCX_TEXT_MIX 行首发现未确认值 ' + lsn2str(tPkg.LSN));
  end;

  BinReader.skip(2);  //R0长度
  MixDataIdx := BinReader.readQWORD;
  MixDataType := BinReader.readWord;
  if MixDataType = 0 then
  begin
    MixDataLen := BinReader.readDWORD;
    //这种数据长度是6位的，猜测应该是兼容大于4BG的数据
    MixDataLen := MixDataLen or (Qword(BinReader.readWORD) shl 32);
    MixItem := TMIX_DATA_Item.Create;
    MixItem.Idx := MixDataIdx;
    MixItem.data := BinReader.readBytes(MixDataLen);
    MIX_DATAs.FItems.Add(MixItem);
  end
  else
  begin
    Loger.AddException('LCX_TEXT_MIX 行首发现未确认值 MixDataType ' + lsn2str(tPkg.LSN));
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog_Delete(tPkg: TTransPkgItem);
var
  Rldo: PRawLog_DataOpt;
  BinReader: TbinDataReader;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  I: Integer;
  TableId: Integer;
  DbTable: TdbTableItem;
  DataRow: Tsql2014Opt;
  TmpCPnt:UIntPtr;
  TmpSize:Cardinal;
begin
  BinReader := nil;
  DataRow := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_MARK_AS_GHOST, LCX_CLUSTERED, LCX_HEAP:
        begin
          if (Rldo.normalData.FlagBits and 1)>0 then
          begin
            //rollback tran
            //COMPENSATION    删除事务中insert的数据
            for I := 0 to FRows.Count - 1 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //撤销之前的数据
                DataRow.deleteFlag := True;
                Break;
              end
            end;
          end else begin
            //删除前，先查找下之前有没有对本行数据的操作（insert或Update，有则取消之前操作
            for I := 0 to FRows.Count - 1 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //撤销之前的数据
                if DataRow.OperaType = Opt_Insert then
                begin
                  DataRow.deleteFlag := True;
                  //同一个事务中先insert然后再delete(
                  Exit;
                end else begin
                  //同一个事务中先update然后再delete(

                  //操作性质变更
                  DataRow.OperaType := Opt_Delete;
                  //替换R0
                  TmpCPnt :=  UIntPtr(Rldo)+ SizeOf(TRawLog_DataOpt) ;
                  TmpSize := PWord(TmpCPnt)^;
                  TmpCPnt := TmpCPnt + Rldo.NumElements*2;
                  TmpCPnt := (TmpCPnt + 3) and $FFFFFFFC;

                  //只读第一个块放进buf就是了
                  if DataRow.R0<>nil then
                    FreeMemory(DataRow.R0);
                  DataRow.R0 := GetMemory(TmpSize);
                  Move(Pointer(TmpCPnt)^, DataRow.R0^, TmpSize);
                  Exit;
                end;
              end
            end;

            SetLength(R_, Rldo.NumElements);
            SetLength(R_Info, Rldo.NumElements);
            BinReader := TbinDataReader.Create(tPkg.Raw);
            BinReader.seek(SizeOf(TRawLog_DataOpt), soBeginning);
            for I := 0 to Rldo.NumElements - 1 do
            begin
              R_Info[I].Length := BinReader.readWord;
            end;
            BinReader.alignTo4;
            for I := 0 to Rldo.NumElements - 1 do
            begin
              if R_Info[I].Length > 0 then
              begin
                R_Info[I].Offset := BinReader.Position;
                R_[I] := BinReader.readBytes(R_Info[I].Length);
                BinReader.alignTo4;
              end;
            end;
            //一般是 2 块数据
            //1. 删除的行数据
            //2. 表信息
            BinReader.SetRange(R_Info[1].Offset, R_Info[1].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //忽略的表
              Exit;
            end;
            //开始读取R0
            DataRow := Tsql2014Opt.Create;
            DataRow.OperaType := Opt_Delete;
            DataRow.page := Rldo.pageId;
            DataRow.table := DbTable;
            DataRow.R0 := GetMemory(R_Info[0].Length);
            Move(Pointer(UIntPtr(Rldo)+R_Info[0].Offset)^, DataRow.R0^, R_Info[0].Length);
            FRows.Add(DataRow);
          end;
        end;
      LCX_TEXT_MIX:
        begin
        //可以忽略的。删除行数据的时候这个会自动删除掉
        end;
      LCX_INDEX_INTERIOR:
        begin

        end;
    end;
  finally
    if BinReader <> nil then
      BinReader.Free;
  end;
end;

function TSql2014logAnalyzer.PriseRowLog_UniqueClusteredKeys(BinReader: TbinDataReader;DbTable: TdbTableItem):string;
var
  flag:Byte;
  I, J: Integer;
  field: TdbFieldItem;
  fieldval: PdbFieldValue;
  values: TList;
  varFCnt:Integer;
  varFxIdx:array of Word;
  fieldCnt:Word;
  tmpCardinal:Cardinal;
begin
  flag := BinReader.readByte;
  Result := '';
  varFCnt := 0;
  values := TList.Create;
  try
    for I := 0 to DbTable.UniqueClusteredKeys.Count - 1 do
    begin
      field := DbTable.UniqueClusteredKeys[I];
      if (field.leaf_pos > 0) then
      begin
        New(fieldval);
        fieldval.field := field;
        fieldval.value := BinReader.readBytes(field.Max_length);
        values.Add(fieldval);
      end
      else
      begin
        if varFCnt = 0 then
        begin
          //field Cnt
          fieldCnt := BinReader.readWord;
          //效验索引字段数量
          if fieldCnt <> DbTable.UniqueClusteredKeys.Count then
          begin
          //有问题数据，跳出
            Exit;
          end;
          //nullmap
          BinReader.skip((fieldCnt + 7) shr 3);
          if (flag and $20) = 0 then
          begin
            // ?? 不包含var字段 值
            Exit;
          end;
          //var 字段数量
          fieldCnt := BinReader.readWord;
          SetLength(varFxIdx, fieldCnt);
          tmpCardinal := BinReader.Position;
          for j := 0 to fieldCnt -1 do
          begin
            varFxIdx[i] := BinReader.readWord - tmpCardinal;
            tmpCardinal := varFxIdx[i];
          end;
        end;
        New(fieldval);
        fieldval.field := field;
        fieldval.value := BinReader.readBytes(varFxIdx[varFCnt]);
        values.Add(fieldval);
        varFCnt := varFCnt + 1;
      end;
    end;
    for I := 0 to values.Count - 1 do
    begin
      fieldval := values[I];
      Result := Result + Format('and %s=%s ', [fieldval.field.getSafeColName,
        Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
    end;
    if values.Count>0 then
    begin
      Delete(Result, 1, 4);  //"and "
    end;
  finally
    for I := 0 to values.Count - 1 do
    begin
      Dispose(PdbFieldValue(values[I]));
    end;
    values.Free;
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog_MODIFY_ROW(tPkg: TTransPkgItem);
procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
var
  tmpdata:Pointer;
  tmpLen:Integer;
begin
  //回滚一个修改
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else if size_old < size_new then
  begin
    //数据后移
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_new - size_old))^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
    FreeMem(tmpdata);
  end else begin
    //前移
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(Pointer(uintptr(tmpdata) + (size_old - size_new))^, Pointer(uintptr(srcData) + offset)^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
    FreeMem(tmpdata);
  end;
end;
var
  Rldo: PRawLog_DataOpt;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  BinReader: TbinDataReader;
  I:Integer;
  OriginRowData:TBytes;
  TableId: Integer;
  DbTable: TdbTableItem;
  tmpdata:Pointer;
  DataRow_buf: Tsql2014Opt;
  RawDataLen:Integer;
begin
  BinReader := nil;
  DataRow_buf := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_HEAP, //堆表写入
      LCX_CLUSTERED: //聚合写入
        begin
          SetLength(R_, Rldo.NumElements);
          SetLength(R_Info, Rldo.NumElements);
          BinReader := TbinDataReader.Create(tPkg.Raw);
          BinReader.seek(SizeOf(TRawLog_DataOpt), soBeginning);
          for I := 0 to Rldo.NumElements - 1 do
          begin
            R_Info[I].Length := BinReader.readWord;
          end;
          BinReader.alignTo4;
          for I := 0 to Rldo.NumElements - 1 do
          begin
            if R_Info[I].Length > 0 then
            begin
              R_Info[I].Offset := BinReader.Position;
              R_[I] := BinReader.readBytes(R_Info[I].Length);
              BinReader.alignTo4;
            end;
          end;
          //一般是 6 块数据
          //0, 旧数据
          //1. 新数据
          //2. 聚合索引信息
          //3. 表信息
          //4. 0
          //5. 0
          if (Rldo.normalData.FlagBits and 1) > 0 then
          begin
            //COMPENSATION
            for I := 0 to FRows.Count - 1 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //找到页，修正页数据
                if DataRow_buf.OperaType = Opt_Update then
                begin
                  if (DataRow_buf.R0<>nil) and (not DataRow_buf.UnReliableRData) then
                  begin
                    RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                    applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                  end;
                end else if DataRow_buf.OperaType=Opt_Insert then
                begin
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                end;
                Break;
              end
            end;
          end else begin
            for I := 0 to FRows.Count - 1 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //找到页，修正页数据
                if DataRow_buf.OperaType = Opt_Update then
                begin
                  if (DataRow_buf.R0<>nil) and (not DataRow_buf.UnReliableRData) then
                  begin
                    RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                    applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                  end;
                end else if DataRow_buf.OperaType=Opt_Insert then
                begin
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                end else  if DataRow_buf.OperaType=Opt_Delete then
                begin
                  //这肯定是删除了数据然后又回滚了的（R0中包含了当前行的完整数据
                  DataRow_buf.OperaType := Opt_Update;
                  DataRow_buf.deleteFlag := False;
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                  //刷新唯一聚合（唯一聚合是不会被update的，当尝试Update聚合=delete+insert
                  if (DataRow_buf.UniqueClusteredKeys='') and (DataRow_buf.table.UniqueClusteredKeys.Count>0) and (R_Info[2].Length > 0) then
                  begin
                    BinReader.SetRange(R_Info[2].Offset, R_Info[2].Length);
                    DataRow_buf.UniqueClusteredKeys := PriseRowLog_UniqueClusteredKeys(BinReader, DataRow_buf.table);
                  end;
                end;
                exit;
              end
            end;

            BinReader.SetRange(R_Info[3].Offset, R_Info[3].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //忽略的表
              Exit;
            end;

            DataRow_buf := Tsql2014Opt.Create;
            try
              if (DbTable.UniqueClusteredKeys.Count>0) and (R_Info[2].Length > 0) then
              begin
                //读取UniqueClusteredKeys
                BinReader.SetRange(R_Info[2].Offset, R_Info[2].Length);
                DataRow_buf.UniqueClusteredKeys := PriseRowLog_UniqueClusteredKeys(BinReader, DbTable);
              end;

              OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
              if OriginRowData = nil then
              begin
                Loger.Add('获取行原始数据失败！' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
                if (DataRow_buf.UniqueClusteredKeys = '') or (DbTable.Owner='sys') then
                begin
                  //如果没有聚合索引，从dbcc page获取原始行数据。因为不会出现重建聚合，所以page页相内容不容易发生变动，数据相对可靠。
                  OriginRowData := getUpdateSoltFromDbccPage(FLogSource.Fdbc, Rldo.pageId);
                  if OriginRowData = nil then
                  begin
                    Loger.Add('获取行原始数据失败！'+lsn2str(tPkg.LSN), LOG_ERROR or LOG_IMPORTANT);
                    DataRow_buf.Free;
                    Exit;
                  end;
                  DataRow_buf.UnReliableRData := true;
                end else begin
                  //如果没有OriginRowData但是有 UniqueClusteredKeys则可以通过直接查询整行数据封装
                end
              end;

              DataRow_buf.OperaType := Opt_Update;
              DataRow_buf.page := Rldo.pageId;
              DataRow_buf.table := DbTable;
              if OriginRowData <> nil then
              begin
                //before
                tmpdata := AllocMem($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                RawDataLen := PageRowCalcLength(tmpdata);
                applyChange(tmpdata, R_[0], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                DataRow_buf.R1 := tmpdata;
                //after
                tmpdata := AllocMem($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                DataRow_buf.R0 := tmpdata;
              end;

              FRows.Add(DataRow_buf);
            except
              DataRow_buf.Free;
            end;
            SetLength(OriginRowData, 0);
          end;
        end;
    else
      Loger.Add('PriseRowLog_MODIFY_ROW 遇到尚未处理的 ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
    end;
  finally
    if BinReader <> nil then
      BinReader.Free;
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog_MODIFY_COLUMNS(tPkg: TTransPkgItem);
procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
var
  tmpdata:Pointer;
  tmpLen:Integer;
begin
  //回滚一个修改
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else if size_old > size_new then
  begin
    //数据后移
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_old - size_new))^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
    FreeMem(tmpdata);
  end else begin
    //前移
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(Pointer(uintptr(tmpdata) + (size_new - size_old))^, Pointer(uintptr(srcData) + offset)^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
    FreeMem(tmpdata);
  end;
end;

var
  Rldo: PRawLog_DataOpt;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  BinReader: TbinDataReader;
  I:Integer;
  OriginRowData:TBytes;
  OffsetInRow:Word;
  TableId: Integer;
  DbTable: TdbTableItem;
  TmpBinReader: TbinDataReader;
  tmpdata_bef:Pointer;
  DataRow_bef,DataRow_aft: Tsql2014RowData;
begin
  Loger.Add('===========================PriseRowLog_MODIFY_COLUMNS============================');
  BinReader := nil;
  DataRow_bef := nil;
  Rldo := tPkg.Raw.data;
  try
    try
      case Rldo.normalData.ContextCode of
        LCX_HEAP, //堆表写入
        LCX_CLUSTERED: //聚合写入
          begin
            SetLength(R_, Rldo.NumElements);
            SetLength(R_Info, Rldo.NumElements);
            BinReader := TbinDataReader.Create(tPkg.Raw);
            BinReader.seek(SizeOf(TRawLog_DataOpt), soBeginning);
            for I := 0 to Rldo.NumElements - 1 do
            begin
              R_Info[I].Length := BinReader.readWord;
            end;
            BinReader.alignTo4;
            for I := 0 to Rldo.NumElements - 1 do
            begin
              if R_Info[I].Length > 0 then
              begin
                R_Info[I].Offset := BinReader.Position;
                R_[I] := BinReader.readBytes(R_Info[I].Length);
                BinReader.alignTo4;
              end;
            end;
            (*
            0:更新的Offset
            1:更新的大小
            2:聚集索引信息
            3:锁信息，object_id和 lock_key
            --之后是修改的内容，类似Log_MODIFY_ROW的r0和r1
            每2个为一组，至少有2组
            *)
            OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
            if OriginRowData = nil then
            begin
              Loger.Add('获取行原始数据失败！' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
              //备用方案，从dbcc page获取原始行数据（数据可能不准确
              OriginRowData := getUpdateSoltFromDbccPage(FLogSource.Fdbc, Rldo.pageId);
              if OriginRowData = nil then
              begin
                Loger.Add('获取行原始数据失败！'+lsn2str(tPkg.LSN),LOG_ERROR or LOG_IMPORTANT);
                Exit;
              end;
            end;
            BinReader.SetRange(R_Info[3].Offset, R_Info[3].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //忽略的表
              Exit;
            end;

            //OriginRowData 是修改后的行数据
            tmpdata_bef := AllocMem($2000);
            try
              Move(OriginRowData[0], tmpdata_bef^, Length(OriginRowData));

              for I := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
              begin
                OffsetInRow := Pword(UIntPtr(R_[0]) + i*4)^;
                applyChange(tmpdata_bef, R_[4 + I * 2], OffsetInRow, R_Info[4 + I * 2].Length, R_Info[4 + I * 2 + 1].Length, Length(OriginRowData));
              end;

              //before update
              TmpBinReader := TbinDataReader.Create(tmpdata_bef, $2000);
              try
                DataRow_bef := PriseRowLog_InsertDeleteRowData(DbTable, TmpBinReader);
              finally
                TmpBinReader.Free;
              end;
              //after update
              TmpBinReader := TbinDataReader.Create(@OriginRowData[0], $2000);
              try
                DataRow_aft := PriseRowLog_InsertDeleteRowData(DbTable, TmpBinReader);
              finally
                TmpBinReader.Free;
              end;


            finally
              FreeMem(tmpdata_bef);
            end;
          end;
      else
        Loger.Add('PriseRowLog_MODIFY_COLUMNS 遇到尚未处理的 ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
      end;
      if DataRow_bef <> nil then
      begin

        FRows.Add(DataRow_bef);
      end;
    except
      on eexx: Exception do
      begin
        raise eexx;
      end;
    end;
  finally
    if BinReader <> nil then
      BinReader.Free;
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog(tPkg: TTransPkgItem);
var
  Rl: PRawLog;
  Rlbx: PRawLog_BEGIN_XACT;
  Rlcx: PRawLog_COMMIT_XACT;
begin
  Rl := tPkg.Raw.data;
  try
    if Rl.OpCode = LOP_INSERT_ROWS then //新增
    begin
      PriseRowLog_Insert(tPkg);
    end
    else if Rl.OpCode = LOP_DELETE_ROWS then  //删除
    begin
      PriseRowLog_Delete(tPkg);
    end
    else if Rl.OpCode = LOP_MODIFY_ROW then  //修改单个块
    begin
      PriseRowLog_MODIFY_ROW(tPkg);
    end
    else if Rl.OpCode = LOP_MODIFY_COLUMNS then  //修改多个块
    begin
      PriseRowLog_MODIFY_COLUMNS(tPkg);
    end
    else if Rl.OpCode = LOP_BEGIN_XACT then
    begin
      Rlbx := tPkg.Raw.data;
      TransBeginTime := Hvu_Hex2Datetime(Rlbx.Time);
      TransId := Rlbx.normalData.TransID;
    end
    else if Rl.OpCode = LOP_COMMIT_XACT then
    begin
      Rlcx := tPkg.Raw.data;
      TransCommitTime := Hvu_Hex2Datetime(Rlcx.Time);
    end
    else
    begin

    end
  except
    on E: Exception do
    begin
      Loger.Add(E.Message + '-->LSN:' + lsn2str(tPkg.LSN), LOG_ERROR);
    end;
  end;
end;

procedure TSql2014logAnalyzer.serializeToBin(FTranspkg: TTransPkg; var mm: TMemory_data);
var
  dataLen: Integer;
  I: Integer;
  datatOffset: Integer;
begin
  //////////////////////////////////////////////////////////////////////////
  ///                   bin define
  /// |tranID|rowCount|每行长度的数组|行数据
  ///    6        2      4*rowCount       x
  ///
  //////////////////////////////////////////////////////////////////////////
  dataLen := 0;
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    dataLen := dataLen + TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize + SizeOf(Tlog_LSN);
  end;
  mm.dataSize := SizeOf(Ttrans_ID) + 2 + FTranspkg.Items.Count * 2 + dataLen;
  mm.data := AllocMem(mm.dataSize);

  Move(FTranspkg.Ftransid, mm.data^, SizeOf(Ttrans_ID));
  datatOffset := SizeOf(Ttrans_ID);
  Move(FTranspkg.Items.Count, Pointer(UIntPtr(mm.data) + datatOffset)^, 2);
  datatOffset := datatOffset + 2;
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    //65536个大小一般情况下是够了，每个块最多就8K，大于8k的数据会拆分成N个块

    Move(TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize, Pointer(UIntPtr(mm.data) + datatOffset)^, 4);
    datatOffset := datatOffset + 4;
  end;

  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    Move(TTransPkgItem(FTranspkg.Items[I]).Raw.data^, Pointer(UIntPtr(mm.data) + datatOffset)^, TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize);
    datatOffset := datatOffset + TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize;
  end;
end;
{ Tsql2014RowData }

constructor Tsql2014RowData.Create;
begin
  fields := TList.Create;
end;

destructor Tsql2014RowData.Destroy;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  for I := 0 to fields.Count - 1 do
  begin
    pdd := PdbFieldValue(fields[I]);
    SetLength(pdd.value, 0);
    Dispose(pdd);
  end;
  fields.free;
  inherited;
end;

function Tsql2014RowData.getField(FieldName: string): PdbFieldValue;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  Result := nil;
  FieldName := LowerCase(FieldName);
  for I := 0 to fields.Count - 1 do
  begin
    pdd := PdbFieldValue(fields[I]);
    if LowerCase(pdd.field.ColName) = FieldName then
    begin
      Result := pdd;
      Exit;
    end;
  end;
end;

function Tsql2014RowData.getField(col_id: Integer): PdbFieldValue;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  Result := nil;
  for I := 0 to fields.Count - 1 do
  begin
    pdd := PdbFieldValue(fields[I]);
    if pdd.field.Col_id = col_id then
    begin
      Result := pdd;
      Exit;
    end;
  end;
end;

function Tsql2014RowData.getFieldStrValue(FieldName: string): string;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  //没有的字段默认null
  Result := 'NULL';
  //DONE:此方式效率低，（写成代码中if效率也很低
  FieldName := LowerCase(FieldName);
  for I := 0 to fields.Count - 1 do
  begin
    pdd := PdbFieldValue(fields[I]);
    if LowerCase(pdd.field.ColName) = FieldName then
    begin
      Result := Hvu_GetFieldStrValue(pdd.field, pdd.value);
      Break;
    end;
  end;
end;

{ MIX_DATA_Item }

constructor TMIX_DATA_Item.Create;
begin

end;

destructor TMIX_DATA_Item.Destroy;
begin
  SetLength(data, 0);
  inherited;
end;

{ TMIX_DATAs }

constructor TMIX_DATAs.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TMIX_DATAs.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TMIX_DATAs.GetItem(Key: Qword): TMIX_DATA_Item;
var
  H, L, M: Integer;
begin
  //二分查找
  L := 0;
  H := FItems.Count - 1;
  while L <= H do
  begin
    M := (L + H) div 2;
    if TMIX_DATA_Item(FItems[M]).idx = Key then
    begin
      Result := TMIX_DATA_Item(FItems[M]);
      Exit;
    end
    else if TMIX_DATA_Item(FItems[M]).idx > Key then
    begin
      H := M - 1;
    end
    else
    begin
      L := M + 1;
    end;
  end;
  Result := nil;
end;

{ TsqlRawBuf }

constructor Tsql2014Opt.Create;
begin
  R0 := nil;
//  R1 := nil;
  UnReliableRData := False;
  old_data := nil;
  new_data := nil;
end;

destructor Tsql2014Opt.Destroy;
begin
  if R0<>nil then
    FreeMem(R0);

//  if R1<>nil then
//    FreeMem(R1);

  if old_data<>nil then
     old_data.Free;
  if new_data<>nil then
     new_data.Free;

  inherited;
end;

procedure Tsql2014Opt.Pretreatment;
begin

end;

end.

