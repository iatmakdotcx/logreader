unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, LogSource, dbDict, System.SysUtils,
  Contnrs, BinDataUtils, SqlDDLs, LogtransPkgMgr;

type
  /// <summary>
  /// ���浥����־��COMPENSATION���ܻ��޸�����
  /// </summary>
  TsqlRawBuf = class(TObject)
    OperaType: TOperationType;
    page:TPage_Id;
    table:TdbTableItem;
    dataFromDbccPage:boolean;//dbcc��raw���ݲ��ô����������ݣ�������������֮�������
    R0:Pointer;
    R1:Pointer;
    public
    constructor Create;
    destructor Destroy; override;
  end;
  /// <summary>
  /// �����ĵ�������
  /// </summary>
  Tsql2014RowData = class(TObject)
    OperaType: TOperationType;
    Fields: TList;
    Table: TdbTableItem;
    lsn: Tlog_LSN;
    afterUpdate:Tsql2014RowData;
  public
    function getFieldStrValue(FieldName: string): string;
    function getField(FieldName: string):PdbFieldValue;overload;
    function getField(col_id: Integer):PdbFieldValue;overload;
    constructor Create;
    destructor Destroy; override;
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
    FPkgMgr:TTransPkgMgr; //�������

    TransBeginTime: TDateTime;
    TransCommitTime: TDateTime;
    FLogSource: TLogSource;
    //ÿ������ʼҪ���³�ʼ�����¶���
    FRows: TObjectList;
    MIX_DATAs: TMIX_DATAs;
    DDL: TDDLMgr;
    AllocUnitMgr: TAllocUnitMgr;
    IDXs:TDDL_Idxs_ColsMgr;
    procedure serializeToBin(FTranspkg: TTransPkg; var mm: TMemory_data);
    procedure PriseRowLog(tPkg: TTransPkgItem);
    procedure PriseRowLog_Insert(tPkg: TTransPkgItem);
    function getDataFrom_TEXT_MIX(idx: TBytes): TBytes;
    function DML_BuilderSql_Insert(aRowData: Tsql2014RowData): string;
    function DML_BuilderSql_Delete(aRowData: Tsql2014RowData): string;
    function DML_BuilderSql(aRowData: Tsql2014RowData): string;
    function Read_LCX_TEXT_MIX_DATA(tPkg: TTransPkgItem; BinReader: TbinDataReader): TBytes;
    procedure PriseDDLPkg(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysrscols(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysschobjs(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysobjvalues(DataRow: Tsql2014RowData);
    function GenSql: string;
    function GenSql_CreateDefault(ddlitem: TDDLItem): string;
    function GenSql_CreateTable(ddlitem: TDDLItem): string;
    procedure PriseRowLog_Delete(tPkg: TTransPkgItem);
    function PriseRowLog_InsertDeleteRowData(DbTable: TdbTableItem; BinReader: TbinDataReader): Tsql2014RowData;
    procedure PriseDDLPkg_D(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_U(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_D_syscolpars(DataRow: Tsql2014RowData);
    function GenSql_DDL_Insert(ddlitem: TDDLItem_Insert): string;
    function GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
    function GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
    function GenSql_DropDefault(ddlitem: TDDL_Delete_Def): string;
    function GenSql_DropTable(ddlitem: TDDL_Delete_Table): string;
    procedure PriseDDLPkg_sysiscols(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_syssingleobjrefs(DataRow: Tsql2014RowData);
    function GenSql_CreatePrimaryKey(ddlitem: TDDL_Create_PrimaryKey): string;
    procedure Execute2(FTranspkg: TTransPkg);
    procedure PriseDDLPkg_syscolpars(DataRow: Tsql2014RowData);
    function GenSql_CreateColumn(ddlitem: TDDL_Create_Column): string;
    function getColsTypeStr(col: TdbFieldItem): string;
    function GenSql_DropColumn(ddlitem: TDDL_Delete_Column): string;
    function DML_BuilderSql_Update(aRowData: Tsql2014RowData): string;
    procedure PriseRowLog_MODIFY_ROW(tPkg: TTransPkgItem);
    procedure PriseRowLog_MODIFY_COLUMNS(tPkg: TTransPkgItem);
  public
    /// <summary>
    ///
    /// </summary>
    /// <param name="PkgMgr">�������</param>
    /// <param name="LogSource">����Դ</param>
    constructor Create(PkgMgr:TTransPkgMgr; LogSource: TLogSource);
    destructor Destroy; override;
    procedure Execute; override;
    /// <summary>
    /// ������Ĳ�����Ӧ�õ���ǰϵͳ�������ȡ����־���ṹ��ƥ��
    /// </summary>
    procedure ApplySysDDLChange;
  end;

implementation

uses
  pluginlog, plugins, OpCode, hexValUtils, contextCode, dbFieldTypes,
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

    end else begin
      //todo:�޸�

    end;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql(aRowData: Tsql2014RowData): string;
begin
  case aRowData.OperaType of
    Opt_Insert:
      Result := DML_BuilderSql_Insert(aRowData);
    Opt_Update:
      Result := DML_BuilderSql_Update(aRowData);
    Opt_Delete:
      Result := DML_BuilderSql_Delete(aRowData);
  else
    Loger.Add('��δ���x��SQLBuilder');
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql_Update(aRowData: Tsql2014RowData): string;
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
  whereStr: string;
  updateStr:string;
  I, J: Integer;
  fieldval: PdbFieldValue;
  field: TdbFieldItem;
  DataRow_aft: Tsql2014RowData;
  raw_old,raw_new: PdbFieldValue;
begin
  whereStr := '';
  if aRowData.Table.UniqueKeys.Count > 0 then
  begin
    for I := 0 to aRowData.Table.UniqueKeys.Count - 1 do
    begin
      field := aRowData.Table.UniqueKeys[I];
      for J := 0 to aRowData.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.Fields[J]);
        if fieldval.field.Col_id = field.Col_id then
        begin
          whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
          Break;
        end;
      end;
    end;
  end
  else
  begin
    for I := 0 to aRowData.Fields.Count - 1 do
    begin
      fieldval := PdbFieldValue(aRowData.Fields[I]);
      whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
    end;
  end;
  if whereStr.Length > 0 then
  begin
    Delete(whereStr, 1, 4);  //"and "
  end;

  updateStr := '';
  DataRow_aft := aRowData.afterUpdate;
  for I := 0 to aRowData.Table.Fields.Count - 1 do
  begin
    raw_old := aRowData.getField(aRowData.Table.Fields[i].Col_id);
    raw_new := DataRow_aft.getField(aRowData.Table.Fields[i].Col_id);
    if raw_new = nil then
    begin
      //var ֵ ��������>  null
      updateStr := updateStr + Format(', %s=NULL',[raw_old.field.getSafeColName]);
    end else if (raw_old = nil) or (not binEquals(raw_new.value, raw_old.value)) then begin
      updateStr := updateStr + Format(', %s=%s',[raw_new.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(raw_new.field, raw_new.value)]);
    end
  end;
  if updateStr.Length > 0 then
    Delete(updateStr, 1, 2);  //", "
  Result := Format('UPDATE %s SET %s WHERE %s;', [aRowData.Table.getFullName, updateStr, whereStr]);
end;

function TSql2014logAnalyzer.DML_BuilderSql_Insert(aRowData: Tsql2014RowData): string;
var
  fields: string;
  StrVal: string;
  I: Integer;
  fieldval: PdbFieldValue;
begin
  fields := '';
  StrVal := '';
  for I := 0 to aRowData.Fields.Count - 1 do
  begin
    fieldval := PdbFieldValue(aRowData.Fields[I]);
    fields := fields + ',' + fieldval.field.getSafeColName;
    StrVal := StrVal + ',' + Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value);
  end;
  if aRowData.Fields.Count > 0 then
  begin
    Delete(fields, 1, 1);
    Delete(StrVal, 1, 1);
  end;
  Result := Format('INSERT INTO %s(%s)values(%s);', [aRowData.Table.getFullName, fields, StrVal]);
end;

function TSql2014logAnalyzer.DML_BuilderSql_Delete(aRowData: Tsql2014RowData): string;
var
  whereStr: string;
  I, J: Integer;
  fieldval: PdbFieldValue;
  field: TdbFieldItem;
begin
  whereStr := '';
  if aRowData.Table.UniqueKeys.Count > 0 then
  begin
    for I := 0 to aRowData.Table.UniqueKeys.Count - 1 do
    begin
      field := aRowData.Table.UniqueKeys[I];
      for J := 0 to aRowData.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.Fields[J]);
        if fieldval.field.Col_id = field.Col_id then
        begin
          whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
          Break;
        end;
      end;
    end;
  end
  else
  begin
    for I := 0 to aRowData.Fields.Count - 1 do
    begin
      fieldval := PdbFieldValue(aRowData.Fields[I]);
      whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
    end;
  end;
  if whereStr.Length > 0 then
  begin
    Delete(whereStr, 1, 4);  //"and "
  end;
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
          Loger.Add('TSql2014logAnalyzer.����鴦��ʧ�ܣ�TranId:' + TranId2Str(TTsPkg.Ftransid) + '.' + ee.Message, LOG_ERROR);
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
  DataRow: Tsql2014RowData;
  DataRow_buf:TsqlRawBuf;
  DMLitem: TDMLItem;
  TmpBinReader: TbinDataReader;
begin
  Loger.Add('TSql2014logAnalyzer.Execute ==> transId:%s, MinLsn:%s', [TranId2Str(FTranspkg.Ftransid),LSN2Str(TTransPkgItem(FTranspkg.Items[0]).lsn)]);
  //֪ͨ���
  serializeToBin(FTranspkg, mm);
  PluginsMgr.onTransPkgRev(mm);
  FreeMem(mm.data);
  //��ʼ��������
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    TTpi := TTransPkgItem(FTranspkg.Items[I]);
    PriseRowLog(TTpi);
  end;

  //��ʼ������
  for I := 0 to FRows.Count - 1 do
  begin
    if FRows[i] is TsqlRawBuf then
    begin
      DataRow_buf := TsqlRawBuf(FRows[i]);
      TmpBinReader := TbinDataReader.Create(DataRow_buf.R0, $2000);
      try
        DataRow := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
      finally
        TmpBinReader.Free;
      end;
      if (DataRow_buf.OperaType = Opt_Update) and (DataRow_buf.R1 <> nil) then
      begin
        TmpBinReader := TbinDataReader.Create(DataRow_buf.R1, $2000);
        try
          DataRow.afterUpdate := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
        finally
          TmpBinReader.Free;
        end;
      end;
    end else begin
      DataRow := Tsql2014RowData(FRows[I]);
    end;
    Loger.Add(lsn2str(DataRow.LSN) + '-->' + DML_BuilderSql(DataRow));
   // continue;
    if DataRow.Table.Owner = 'sys' then
    begin
      //�����������ϵͳ������ddl���
      if DataRow.OperaType = Opt_Insert then
      begin
        PriseDDLPkg(DataRow);
      end
      else if DataRow.OperaType = Opt_Delete then
      begin
        PriseDDLPkg_D(DataRow);
      end
      else if DataRow.OperaType = Opt_Update then
      begin
        PriseDDLPkg_U(DataRow);
      end;
    end
    else
    begin
      // dml ���
      DMLitem := TDMLItem.Create;
      DMLitem.data := DataRow;
      DDL.Add(DMLitem);
    end;
  end;
  if DDL.FItems.Count>0 then
  begin
    Loger.Add(GenSql);
    ApplySysDDLChange;
  end;
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
            Tmpstr := DML_BuilderSql(Tsql2014RowData(TDMLItem(DDL.FItems[I]).data))
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

procedure TSql2014logAnalyzer.PriseDDLPkg_D(DataRow: Tsql2014RowData);
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    //ɾ����,�洢���̡���ͼ ��Ĭ��ֵ�ȶ���
    PriseDDLPkg_D_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    //ɾ������
    PriseDDLPkg_D_syscolpars(DataRow);
  end
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D_syscolpars(DataRow: Tsql2014RowData);
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

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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

procedure TSql2014logAnalyzer.PriseDDLPkg_U(DataRow: Tsql2014RowData);
begin
  //todo:PriseDDLPkg_U
end;

procedure TSql2014logAnalyzer.PriseDDLPkg(DataRow: Tsql2014RowData);
var
  rowsetid: int64;
  ObjId: Integer;
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    //������,�洢���̡���ͼ ��Ĭ��ֵ�ȶ���
    PriseDDLPkg_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    PriseDDLPkg_syscolpars(DataRow);
  end
  else if DataRow.Table.TableNmae = 'sysrowsets' then
  begin
    rowsetid := StrToInt64(DataRow.getFieldStrValue('rowsetid'));
    ObjId := StrToInt(DataRow.getFieldStrValue('idmajor'));
    AllocUnitMgr.Add(rowsetid, ObjId);
  end
  else if DataRow.Table.TableNmae = 'sysrscols' then
  begin
    PriseDDLPkg_sysrscols(DataRow);
  end
  else if DataRow.Table.TableNmae = 'sysobjvalues' then
  begin
    //Ĭ��ֵ����ֵ
    PriseDDLPkg_sysobjvalues(DataRow);
  end else if DataRow.Table.TableNmae = 'sysiscols' then
  begin
    //index fields
    PriseDDLPkg_sysiscols(DataRow);
  end else if DataRow.Table.TableNmae = 'syssingleobjrefs' then
  begin
    //index ��Ϣ (�Ƿ񼯺�����)
    PriseDDLPkg_syssingleobjrefs(DataRow);
  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_syscolpars(DataRow: Tsql2014RowData);
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
  if TryStrToInt(DataRow.getFieldStrValue('id'), ObjId) then
  begin
    ddlitem := DDL.GetItem(ObjId);
    FieldItem := TdbFieldItem.Create;
    FieldItem.Col_id := StrToInt(DataRow.getFieldStrValue('colid'));
    FieldItem.ColName := DataRow.getFieldStrValue('name');
    FieldItem.type_id := StrToInt(DataRow.getFieldStrValue('xtype'));
    FieldItem.Max_length := StrToInt(DataRow.getFieldStrValue('length'));
    FieldItem.procision := StrToInt(DataRow.getFieldStrValue('prec'));
    FieldItem.scale := StrToInt(DataRow.getFieldStrValue('scale'));
    collation_id := StrToInt(DataRow.getFieldStrValue('collationid'));
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
      //������ֶ�
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
        //���Ǵ�����Ҳ����������
        raise Exception.Create('Error Message:PriseDDLPkg_syscolpars not Create table Or add Column');
      end;
    end;
  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_syssingleobjrefs(DataRow: Tsql2014RowData);
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

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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

procedure TSql2014logAnalyzer.PriseDDLPkg_sysiscols(DataRow: Tsql2014RowData);
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

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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

procedure TSql2014logAnalyzer.PriseDDLPkg_sysobjvalues(DataRow: Tsql2014RowData);
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

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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

procedure TSql2014logAnalyzer.PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014RowData);

  procedure DeleteTablesSubObj(tableId: Integer);
  var
    I: Integer;
    ddlitem: TDDLItem_Delete;
  begin
    //ɾ�����е���Ԫ�أ�
    //ɾ�����ʱ����־��һ��һ��ɾ���������ɾ�������ģ�
    //����䣬ֻ��ɾ�����Ӷ����Զ�ȫ��ɾ��
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
//  initprop: Integer; //��������Ǳ�ֵΪ���������������Ĭ��ֵΪ��id

  table: TDDL_Delete_Table;
  DefObj: TDDL_Delete_Def;
begin
  ObjId := 0;
  ObjName := '';
  nsid := 0;
  ObjType := '';
  pid := 0;
//  initprop := 0;

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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
    //��
    table := TDDL_Delete_Table.Create;
    table.objId := ObjId;
    table.objName := ObjName;
    table.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
    //���ɾ��������Ҫ�����ɾ���ֶΣ�ɾ��Ĭ��ֵ�ȶ�������
    DeleteTablesSubObj(ObjId);
  end
  else if ObjType = 'v' then
  begin
    //todo:��ͼ

  end
  else if ObjType = 'p' then
  begin
    //todo:����


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
  //δ֪����

  end;

end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysschobjs(DataRow: Tsql2014RowData);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  ObjId: Integer;
  ObjName: string;
  nsid: Integer;
  ObjType: string;
  pid: Integer;
  initprop: Integer; //��������Ǳ�ֵΪ���������������Ĭ��ֵΪ��id

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

  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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
    //��
    table := TDDL_Create_Table.Create;
    table.TableObj.TableId := ObjId;
    table.TableObj.TableNmae := ObjName;
    table.TableObj.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
  end
  else if ObjType = 'v' then
  begin
    //todo:��ͼ

  end
  else if ObjType = 'p' then
  begin
    //todo:����


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
  //δ֪����

  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysrscols(DataRow: Tsql2014RowData);
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
  for I := 0 to DataRow.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.Fields[I]);
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
    //ֱ�������У�alter table xxx add xxx xx;
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
      raise Exception.CreateFmt('Error Message:PriseDDLPkg_sysrscols.�޷������� Partitionid:%d',[rowsetid]);
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
  VarFieldValBase: Cardinal;  //var �ֶ�ֵ��ʼλ��
  boolbit: Integer;
  aField: TdbFieldItem;
  Idx, b: Integer;
  val_begin, val_len: Cardinal;
  fieldval: PdbFieldValue;
begin
  InsertRowFlag := BinReader.readWord;
  if (InsertRowFlag and $6) > 0 then
  begin
    //�ظ���ѹ����־
    Result := nil;
    Exit;
  end;
  //DONE: ����Ӧ��Ч��InsertRowFlag������
  TmpInt := BinReader.readWord; //�������� Offset
  BinReader.seek(TmpInt, soBeginning);
  ColCnt := BinReader.readWord;
  if ColCnt <> DbTable.Fields.Count then
  begin
    //UNIQUIFIER
    if (ColCnt <> DbTable.Fields.Count + 1) then
    begin
      raise Exception.Create('ʵ����������־��ƥ�䣡��������޸ı����ɵģ�����������');
    end;
  end;
  DataRow := Tsql2014RowData.Create;
  DataRow.Table := DbTable;
  if (InsertRowFlag and $10) > 0 then
  begin
    //nullMap := BinReader.readBytes((DbTable.Fields.Count + 7) shr 3);
    nullMap := BinReader.readBytes((ColCnt + 7) shr 3);
  end
  else
  begin
    //������NullData
    nullMap := nil;
  end;
  if (InsertRowFlag and $20) > 0 then
  begin
    TmpInt := BinReader.readWord; //var �ֶ�����
  end
  else
  begin
    //������varData
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
        if (nullMap[Idx] and (1 shl b)) > 0 then  //ֵΪnull
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
                //������λ��1˵��������LCX_TEXT_MIX����
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
  DataRow: Tsql2014RowData;
begin
  DataRow := nil;
  BinReader := nil;
  Rldo := tPkg.Raw.data;
  try
    try
      case Rldo.normalData.ContextCode of
        LCX_HEAP, //�ѱ�д��
        LCX_CLUSTERED: //�ۺ�д��
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
            //һ���� 3 ������ (������N����
            //1��n-2. ��ʵд�������
            //n-1. 0 ���ȣ�
            //n. ����Ϣ
            if R_Info[Rldo.NumElements - 1].Length = 0 then
            begin
              //�����ƶ����ݣ������ֱ�Ӻ���
              Exit;
            end;
            BinReader.SetRange(R_Info[Rldo.NumElements - 1].Offset, R_Info[Rldo.NumElements - 1].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //���Եı�
              Exit;
            end;
            //��ʼ��ȡR0
            BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
            DataRow := PriseRowLog_InsertDeleteRowData(DbTable, BinReader);
          end;
        LCX_INDEX_LEAF: //����д��
          begin
            //�ⶫ��Ӧ�ÿ��Ժ��԰ɣ�����
          end;
        LCX_TEXT_MIX: //�зֿ����� image,text,ntext֮���
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
            //��ʼ��ȡR0
            BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
            Read_LCX_TEXT_MIX_DATA(tPkg, BinReader);
          end;
      else
        Loger.Add('PriseRowLog_Insert ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
      end;
      if DataRow <> nil then
      begin
        DataRow.OperaType := Opt_Insert;
        DataRow.lsn := tPkg.LSN;
        FRows.Add(DataRow);
      end;
    except
      on eexx: Exception do
      begin
        if DataRow <> nil then
          DataRow.Free;

        raise eexx;
      end;
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
  { TODO -oChin -c : �����ô��� 2017-09-16 11:42:40 }
  if RowFlag <> $0008 then
  begin
    Loger.AddException('LCX_TEXT_MIX ���׷���δȷ��ֵ ' + lsn2str(tPkg.LSN));
  end;

  BinReader.skip(2);  //R0����
  MixDataIdx := BinReader.readQWORD;
  MixDataType := BinReader.readWord;
  if MixDataType = 0 then
  begin
    MixDataLen := BinReader.readDWORD;
    //�������ݳ�����6λ�ģ��²�Ӧ���Ǽ��ݴ���4BG������
    MixDataLen := MixDataLen or (Qword(BinReader.readWORD) shl 32);
    MixItem := TMIX_DATA_Item.Create;
    MixItem.Idx := MixDataIdx;
    MixItem.data := BinReader.readBytes(MixDataLen);
    MIX_DATAs.FItems.Add(MixItem);
  end
  else
  begin
    Loger.AddException('LCX_TEXT_MIX ���׷���δȷ��ֵ MixDataType ' + lsn2str(tPkg.LSN));
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
  DataRow: Tsql2014RowData;
begin
  BinReader := nil;
  DataRow := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_MARK_AS_GHOST, LCX_CLUSTERED, LCX_HEAP:
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
        //һ���� 2 ������
        //1. ɾ����������
        //2. ����Ϣ
          BinReader.SetRange(R_Info[1].Offset, R_Info[1].Length);
          BinReader.skip(6);
          TableId := BinReader.readInt;
          DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
          if DbTable = nil then
          begin
          //���Եı�
            Exit;
          end;
        //��ʼ��ȡR0
          BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
          DataRow := PriseRowLog_InsertDeleteRowData(DbTable, BinReader);
        end;
      LCX_TEXT_MIX:
        begin
        //���Ժ��Եġ�ɾ�������ݵ�ʱ��������Զ�ɾ����
        end;
      LCX_INDEX_INTERIOR:
        begin

        end;
    end;
    if DataRow <> nil then
    begin
      DataRow.OperaType := Opt_Delete;
      DataRow.lsn := tPkg.LSN;
      FRows.Add(DataRow);
    end;

  finally
    if BinReader <> nil then
      BinReader.Free;
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog_MODIFY_ROW(tPkg: TTransPkgItem);
procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
var
  tmpdata:Pointer;
  tmpLen:Integer;
begin
  //�ع�һ���޸�
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else if size_old > size_new then
  begin
    //���ݺ���
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_old - size_new))^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
    FreeMem(tmpdata);
  end else begin
    //ǰ��
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
  OriginRowDataDbcc:boolean;
  TableId: Integer;
  DbTable: TdbTableItem;
  tmpdata:Pointer;
  DataRow_buf: TsqlRawBuf;
  RawDataLen:Integer;
begin
  BinReader := nil;
  DataRow_buf := nil;
  OriginRowDataDbcc := false;
  Rldo := tPkg.Raw.data;
  try
    try
      case Rldo.normalData.ContextCode of
        LCX_HEAP, //�ѱ�д��
        LCX_CLUSTERED: //�ۺ�д��
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
            if (Rldo.normalData.FlagBits and 1) > 0 then
            begin
              //COMPENSATION
              for I := 0 to FRows.Count - 1 do
              begin
                if(FRows[i] is TsqlRawBuf) then
                begin
                  DataRow_buf := TsqlRawBuf(FRows[i]);
                  if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                    (DataRow_buf.page.FID = Rldo.pageId.FID) and
                    (DataRow_buf.page.solt = Rldo.pageId.solt) then
                  begin
                    //�ҵ�ҳ������ҳ����
                    if not DataRow_buf.dataFromDbccPage then
                    begin
                      RawDataLen := PageRowCalcLength(DataRow_buf.R1);
                      applyChange(DataRow_buf.R1, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                    end;
                    Break;
                  end
                end;
              end;
            end else begin
              OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
              if OriginRowData = nil then
              begin
                Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
                OriginRowDataDbcc := true;
                //���÷�������dbcc page��ȡԭʼ�����ݣ����ݿ��ܲ�׼ȷ
                OriginRowData := getUpdateSoltFromDbccPage(FLogSource.Fdbc, Rldo.pageId);
                if OriginRowData = nil then
                begin
                  Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�'+lsn2str(tPkg.LSN),LOG_ERROR or LOG_IMPORTANT);
                  Exit;
                end;
              end;

              BinReader.SetRange(R_Info[3].Offset, R_Info[3].Length);
              BinReader.skip(6);
              TableId := BinReader.readInt;
              DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
              if DbTable = nil then
              begin
                //���Եı�
                Exit;
              end;

              DataRow_buf := TsqlRawBuf.Create;
              try
                DataRow_buf.OperaType := Opt_Update;
                DataRow_buf.page := Rldo.pageId;
                DataRow_buf.table := DbTable;
                DataRow_buf.dataFromDbccPage := OriginRowDataDbcc;
                //before
                tmpdata := AllocMem($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                RawDataLen := PageRowCalcLength(tmpdata);
                applyChange(tmpdata, R_[0], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                DataRow_buf.R0 := tmpdata;
                //after
                tmpdata := AllocMem($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                DataRow_buf.R1 := tmpdata;

                FRows.Add(DataRow_buf);
              except
                DataRow_buf.Free;
              end;
              SetLength(OriginRowData, 0);
            end;
          end;
      else
        Loger.Add('PriseRowLog_MODIFY_ROW ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
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

procedure TSql2014logAnalyzer.PriseRowLog_MODIFY_COLUMNS(tPkg: TTransPkgItem);
procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
var
  tmpdata:Pointer;
  tmpLen:Integer;
begin
  //�ع�һ���޸�
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else if size_old > size_new then
  begin
    //���ݺ���
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_old - size_new))^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
    FreeMem(tmpdata);
  end else begin
    //ǰ��
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
        LCX_HEAP, //�ѱ�д��
        LCX_CLUSTERED: //�ۺ�д��
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
            0:���µ�Offset
            1:���µĴ�С
            2:�ۼ�������Ϣ
            3:����Ϣ��object_id�� lock_key
            --֮�����޸ĵ����ݣ�����Log_MODIFY_ROW��r0��r1
            ÿ2��Ϊһ�飬������2��
            *)
            OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
            if OriginRowData = nil then
            begin
              Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
              //���÷�������dbcc page��ȡԭʼ�����ݣ����ݿ��ܲ�׼ȷ
              OriginRowData := getUpdateSoltFromDbccPage(FLogSource.Fdbc, Rldo.pageId);
              if OriginRowData = nil then
              begin
                Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�'+lsn2str(tPkg.LSN),LOG_ERROR or LOG_IMPORTANT);
                Exit;
              end;
            end;
            BinReader.SetRange(R_Info[3].Offset, R_Info[3].Length);
            BinReader.skip(6);
            TableId := BinReader.readInt;
            DbTable := FLogSource.Fdbc.dict.tables.GetItemById(TableId);
            if DbTable = nil then
            begin
              //���Եı�
              Exit;
            end;

            //OriginRowData ���޸ĺ��������
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

              DataRow_bef.afterUpdate := DataRow_aft;
            finally
              FreeMem(tmpdata_bef);
            end;
          end;
      else
        Loger.Add('PriseRowLog_MODIFY_COLUMNS ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
      end;
      if DataRow_bef <> nil then
      begin
        DataRow_bef.OperaType := Opt_Update;
        DataRow_bef.lsn := tPkg.LSN;
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
    if Rl.OpCode = LOP_INSERT_ROWS then //����
    begin
      PriseRowLog_Insert(tPkg);
    end
    else if Rl.OpCode = LOP_DELETE_ROWS then  //ɾ��
    begin
      PriseRowLog_Delete(tPkg);
    end
    else if Rl.OpCode = LOP_MODIFY_ROW then  //�޸ĵ�����
    begin
      PriseRowLog_MODIFY_ROW(tPkg);
    end
    else if Rl.OpCode = LOP_MODIFY_COLUMNS then  //�޸Ķ����
    begin
      PriseRowLog_MODIFY_COLUMNS(tPkg);
    end
    else if Rl.OpCode = LOP_BEGIN_XACT then
    begin
      Rlbx := tPkg.Raw.data;
      TransBeginTime := Hvu_Hex2Datetime(Rlbx.Time);
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
  /// |tranID|rowCount|ÿ�г��ȵ�����|������
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
    //65536����Сһ��������ǹ��ˣ�ÿ��������8K������8k�����ݻ��ֳ�N����

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
  afterUpdate := nil;
end;

destructor Tsql2014RowData.Destroy;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  if afterUpdate<>nil then
  begin
    afterUpdate.Free;
  end;

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
  //û�е��ֶ�Ĭ��null
  Result := 'NULL';
  //DONE:�˷�ʽЧ�ʵͣ���д�ɴ�����ifЧ��Ҳ�ܵ�
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
  //���ֲ���
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

constructor TsqlRawBuf.Create;
begin
  R0 := nil;
  R1 := nil;
end;

destructor TsqlRawBuf.Destroy;
begin
  if R0<>nil then
    FreeMem(R0);

  if R1<>nil then
    FreeMem(R1);

  inherited;
end;

end.

