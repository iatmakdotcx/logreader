unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, LogSource, dbDict, System.SysUtils,
  Contnrs, BinDataUtils, SqlDDLs;

type
  Tsql2014RowData = class(TObject)
    OperaType: TOperationType;
    Fields: TList;
    Table: TdbTableItem;
    lsn: Tlog_LSN;
  public
    function getFieldStrValue(FieldName: string): string;
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
    FRows: TObjectList;
    TransBeginTime: TDateTime;
    TransCommitTime: TDateTime;
    FTranspkg: TTransPkg;
    FLogSource: TLogSource;
    MIX_DATAs: TMIX_DATAs;
    DDL: TDDLMgr;
    AllocUnitMgr: TAllocUnitMgr;
    procedure serializeToBin(var mm: TMemory_data);
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
  public
    constructor Create(LogSource: TLogSource; Transpkg: TTransPkg);
    destructor Destroy; override;
    procedure Execute; override;
    /// <summary>
    /// 将表更改操作，应用到当前系统。以免读取的日志与表结构不匹配
    /// </summary>
    procedure ApplySysChange;
  end;

implementation

uses
  pluginlog, plugins, OpCode, hexValUtils, contextCode, dbFieldTypes,
  Memory_Common;

type
  TRawElement = packed record
    Offset: Cardinal;
    Length: Word;
  end;

{ TSql2014logAnalyzer }

constructor TSql2014logAnalyzer.Create(LogSource: TLogSource; Transpkg: TTransPkg);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FTranspkg := Transpkg;
  FLogSource := LogSource;
  FRows := TObjectList.Create;
  FRows.OwnsObjects := True;
  MIX_DATAs := TMIX_DATAs.Create;
  DDL := TDDLMgr.Create;
  AllocUnitMgr := TAllocUnitMgr.Create;
end;

destructor TSql2014logAnalyzer.Destroy;
begin
  FTranspkg.Free;
  FRows.Clear;
  FRows.Free;
  MIX_DATAs.Free;
  DDL.Free;
  AllocUnitMgr.Free;
  inherited;
end;

procedure TSql2014logAnalyzer.ApplySysChange;
begin
  //


end;

function TSql2014logAnalyzer.DML_BuilderSql(aRowData: Tsql2014RowData): string;
begin
  case aRowData.OperaType of
    Opt_Insert:
      Result := DML_BuilderSql_Insert(aRowData);
    Opt_Update:
      ;
    Opt_Delete:
      Result := DML_BuilderSql_Delete(aRowData);
  else
    Loger.Add('尚未定義的SQLBuilder');
  end;
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
    StrVal := StrVal + ',' + Hvu_GetFieldStrValue(fieldval.field, fieldval.value);
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
          whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValue(fieldval.field, fieldval.value)]);
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
      whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu_GetFieldStrValue(fieldval.field, fieldval.value)]);
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
  mm: TMemory_data;
  I: Integer;
  TTpi: TTransPkgItem;
  DataRow: Tsql2014RowData;
  DMLitem: TDMLItem;
begin
  Loger.Add('TSql2014logAnalyzer.Execute ==> ' + TranId2Str(FTranspkg.Ftransid));
  //通知插件
  serializeToBin(mm);
  PluginsMgr.onTransPkgRev(mm);
  FreeMem(mm.data);
  //开始解析数据
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    TTpi := TTransPkgItem(FTranspkg.Items[I]);
    PriseRowLog(TTpi);
  end;

  //开始干正事
  for I := 0 to FRows.Count - 1 do
  begin
    DataRow := Tsql2014RowData(FRows[I]);
    Loger.Add(lsn2str(DataRow.LSN) + '-->' + DML_BuilderSql(DataRow));
    if DataRow.Table.Owner = 'sys' then
    begin
      //如果操作的是系统表则是ddl语句
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
      // dml 语句
      DMLitem := TDMLItem.Create;
      DMLitem.data := DataRow;
      DDL.Add(DMLitem);
    end;
  end;
  Loger.Add(GenSql);
  ApplySysChange;
end;

function TSql2014logAnalyzer.GenSql: string;
var
  ddlitem: TDDLItem;
  I: Integer;
  ResList: TStringList;
begin
  ResList := TStringList.Create;
  try
    for I := 0 to DDL.FItems.Count - 1 do
    begin
      ddlitem := TDDLItem(DDL.FItems[I]);
      case ddlitem.OpType of
        Opt_Insert:
          ResList.Add(GenSql_DDL_Insert(TDDLItem_Insert(ddlitem)));
        Opt_Update:
          ResList.Add(GenSql_DDL_Update(TDDLItem_Update(ddlitem)));
        Opt_Delete:
          ResList.Add(GenSql_DDL_Delete(TDDLItem_Delete(ddlitem)));
        Opt_DML:
          begin
            ResList.Add(DML_BuilderSql(Tsql2014RowData(TDMLItem(DDL.FItems[I]).data)));
          end;
      end;

    end;
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
  end
  else
  begin
    //TODO:GenSql_DDL_Insert
  end;
end;

function TSql2014logAnalyzer.GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
begin
  //TODO:GenSql_DDL_Delete
end;

function TSql2014logAnalyzer.GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
begin
  //TODO:GenSql_DDL_Update
end;

function TSql2014logAnalyzer.GenSql_CreateTable(ddlitem: TDDLItem): string;

  function getColsTypeStr(col: TdbFieldItem): string;
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
    //删除表,存储过程、视图 、默认值等对象
    PriseDDLPkg_D_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    //删除表列
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

end;

procedure TSql2014logAnalyzer.PriseDDLPkg(DataRow: Tsql2014RowData);
var
  ddlitem: TDDLItem;
  FieldItem: TdbFieldItem;
  //tmpVar
  rowsetid: int64;
  ObjId: Integer;
  collation_id: Integer;
  TmpStr: string;
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    //新增表,存储过程、视图 、默认值等对象
    PriseDDLPkg_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    if TryStrToInt(DataRow.getFieldStrValue('id'), ObjId) then
    begin
      ddlitem := DDL.GetItem(ObjId);
      if (ddlitem <> nil) and (ddlitem.xType = 'u') then
      begin
        //表添加字段
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
        TDDL_Create_Table(ddlitem).TableObj.Fields.addField(FieldItem);
      end
      else
      begin
        raise Exception.Create('Error Message:DataRow.Table.TableNmae = syscolpars');
      end;
    end;
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
    //默认值——值
    PriseDDLPkg_sysobjvalues(DataRow);
  end;

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
  if (ddlitem <> nil) and (ddlitem.xType = 'd') then
  begin
    DefObj := TDDL_Create_Def(ddlitem);
    DefObj.value := hexToAnsiiData(value);
  end
  else
  begin
    raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.2');
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014RowData);

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
        ddlitem := TDDLItem_Delete(DDl.FItems);
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
    //表
    table := TDDL_Delete_Table.Create;
    table.objId := ObjId;
    table.objName := ObjName;
    table.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
    //如果删除表，这里要处理掉删除字段，删除默认值等对象数据
    //DeleteTablesSubObj(ObjId);
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
  initprop: Integer; //如果对象是表值为表总列数，如果是默认值为列id

  table: TDDL_Create_Table;
  DefObj: TDDL_Create_Def;
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
    //表
    table := TDDL_Create_Table.Create;
    table.TableObj.TableId := ObjId;
    table.TableObj.TableNmae := ObjName;
    table.TableObj.Owner := FLogSource.Fdbc.GetSchemasName(nsid);
    DDL.Add(table);
  end
  else if ObjType = 'd' then
  begin
    //默认值
    DefObj := TDDL_Create_Def.Create;
    DefObj.objId := ObjId;
    DefObj.objName := ObjName;
    DefObj.tableid := pid;
    DefObj.colid := initprop;
    DDL.Add(DefObj);
  end
  else if ObjType = 'p' then
  begin
    //过程


  end
  else if ObjType = 'pk' then
  begin
    //primary key


  end
  else
  begin
     //未知对象

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
    raise Exception.Create('Error Message:PriseDDLPkg_sysrscols');
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
    raise Exception.Create('实际列数与日志不匹配！这可能是修改表后造成的！放弃解析！');
  end;
  DataRow := Tsql2014RowData.Create;
  DataRow.Table := DbTable;
  if (InsertRowFlag and $10) > 0 then
  begin
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
  DataRow: Tsql2014RowData;
begin
  DataRow := nil;
  BinReader := nil;
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
            //一般是 3 块数据 (可以有N个块
            //1至n-2. 真实写入的数据
            //n-1. 0 长度？
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
            //开始读取R0
            BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
            DataRow := PriseRowLog_InsertDeleteRowData(DbTable, BinReader);
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
          BinReader.SetRange(R_Info[0].Offset, R_Info[0].Length);
          DataRow := PriseRowLog_InsertDeleteRowData(DbTable, BinReader);
        end;
      LCX_TEXT_MIX:
        begin
        //可以忽略的。删除行数据的时候这个会自动删除掉
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

    end
    else if Rl.OpCode = LOP_MODIFY_COLUMNS then  //修改多个块
    begin

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

procedure TSql2014logAnalyzer.serializeToBin(var mm: TMemory_data);
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
  Move(FTranspkg.Items.Count, Pointer(Integer(mm.data) + datatOffset)^, 2);
  datatOffset := datatOffset + 2;
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    //65536个大小一般情况下是够了，如果是image类型可能会超过此大小 ，所以这个直接定义成Dword大小 ，如果文件超过4GB，这里就呵呵哒了

    Move(TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize, Pointer(Integer(mm.data) + datatOffset)^, 4);
    datatOffset := datatOffset + 4;
  end;

  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    Move(TTransPkgItem(FTranspkg.Items[I]).Raw.data^, Pointer(Integer(mm.data) + datatOffset)^, TTransPkgItem(FTranspkg.Items[I]).Raw.dataSize);
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

function Tsql2014RowData.getFieldStrValue(FieldName: string): string;
var
  I: Integer;
  pdd: PdbFieldValue;
begin
  //TODO:此方式效率低，应该在代码中直接循环取值
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

end.

