unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, LogSource, dbDict, System.SysUtils,
  Contnrs, BinDataUtils, SqlDDLs, LogtransPkgMgr, hexValUtils;

type

  /// <summary>
  /// һ��������������
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
  /// һ�������Ĳ��������ܰ������Lsn�����н��
  /// ������־��COMPENSATION���ܻ��޸�����
  /// </summary>
  Tsql2014Opt = class(TObject)
    OperaType: TOperationType;
    page:TPage_Id;
    table:TdbTableItem;
    UnReliableRData:Boolean;       //��ʶR0��R1��ֵ�ǲ��ɿ��� (��ԴΪdbcc page
    R0:Pointer;                    //������
    R1:Pointer;                    //������
    UniqueClusteredKeys:string;
    deleteFlag:Boolean;            //����ɾ����־�� Ϊture�����ݲ�����Sql
    //
    old_data:Tsql2014RowData;
    new_data:Tsql2014RowData;
    //�������
    deleteFromUpdate:Boolean;
    isMixData:Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  end;


  TMIX_DATA_Item = class(TObject)
    Idx: QWORD;
    pageid:TPage_Id;
    data: TBytes;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TMIX_DATAs = class(TObject)
    FItems: TObjectList;
  public
    function GetItem_Idx(Key: Qword): TMIX_DATA_Item;
    function GetItem_Pageid(pageid:TPage_Id): TMIX_DATA_Item;
    procedure add(idx:QWORD;pageid:TPage_Id;data:TBytes);
    constructor Create;
    destructor Destroy; override;
  end;


  TDDL_IDX_stats = class(TObject)
    tableId:Integer;
    idxName:string;
    isCLUSTERED:Boolean;
    isUnique:Boolean;
  end;

  TDDL_RsCols = class(TObject)
    rowsetid: int64;
    ColId: Integer;
    statusCode: Integer;
    DataOffset: Integer;
    Nullbit: Integer;
    TableObj:TdbTableItem;
  end;

  TSql2014logAnalyzer = class(TlogAnalyzer)
  private
    FPkgMgr:TTransPkgMgr; //�������
    Hvu:THexValueHelper;
    TransId: TTrans_Id;
    TransBeginTime: TDateTime;
    TransCommitTime: TDateTime;
    TransCommitLsn:Tlog_LSN;
    FLogSource: TLogSource;
    //ÿ������ʼҪ���³�ʼ�����¶���
    FRows: TObjectList;
    DDL: TDDLMgr;
    AllocUnitMgr: TAllocUnitMgr;
    IDXs:TDDL_Idxs_ColsMgr;
    IDXstats:TObjectList;
    Rscols:TObjectList;
    function binEquals(v1, v2: TBytes): Boolean;
    procedure serializeToBin(FTranspkg: TTransPkg; var mm: TMemory_data);
    procedure PriseRowLog(tPkg: TTransPkgItem);
    procedure PriseRowLog_Insert(tPkg: TTransPkgItem);
    function getDataFrom_TEXT_MIX(idx: TBytes): TBytes;
    function GenSql: string;
    function DML_BuilderSql(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Insert(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Update(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Delete(aRowData: Tsql2014Opt): string;
    function DML_BuilderSql_Where(aRowData: Tsql2014Opt): string;
    function GenXML: string;
    function DML_BuilderXML(aRowData: Tsql2014Opt): string;
    function DML_BuilderXML_SafeStr(aVal:string): string;
    function DML_BuilderXML_Insert(aRowData: Tsql2014Opt): string;
    function DML_BuilderXML_Update(aRowData: Tsql2014Opt): string;
    function DML_BuilderXML_Delete(aRowData: Tsql2014Opt): string;
    procedure PriseDDLPkg(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysrscols(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysschobjs(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_sysobjvalues(DataRow: Tsql2014Opt);
    function GenSql_CreateDefault(ddlitem: TDDLItem): string;
    function GenSql_CreateTable(ddlitem: TDDLItem): string;
    procedure PriseRowLog_Delete(tPkg: TTransPkgItem);
    function PriseRowLog_InsertDeleteRowData(DbTable: TdbTableItem; BinReader: TbinDataReader): Tsql2014RowData;
    procedure PriseDDLPkg_D(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_D_syscolpars(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_U(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_U_sysschobjs(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_U_syscolpars(DataRow: Tsql2014Opt);
    procedure PriseDDLPkg_U_sysrscols(DataRow: Tsql2014Opt);
    function GenSql_DDL_Insert(ddlitem: TDDLItem_Insert): string;
    function GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
    function GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
    function GenSql_DropConstraint(ddlitem: TDDL_Delete_Constraint): string;
    function GenSql_DropTable(ddlitem: TDDL_Delete_Table): string;
    function GenSql_DropColumn(ddlitem: TDDL_Delete_Column): string;
    function GenSql_CreatePrimaryKey(ddlitem: TDDL_Create_PrimaryKey): string;
    function GenSql_CreateUniqueKey(ddlitem: TDDL_Create_UniqueKey): string;
    function GenSql_CreateCheck(ddlitem: TDDL_Create_Check): string;
    function GenSql_CreateColumn(ddlitem: TDDL_Create_Column): string;
    function GenSql_UpdateColumn(ddlitem: TDDL_Update_Column): string;
    function GenSql_UpdateRenameObj(ddlitem: TDDL_Update_RenameObj): string;
    procedure PriseDDLPkg_sysiscols(DataRow: Tsql2014Opt);
    procedure Execute2(FTranspkg: TTransPkg);
    procedure PriseDDLPkg_syscolpars(DataRow: Tsql2014Opt);
    procedure PriseRowLog_MODIFY_ROW(tPkg: TTransPkgItem);
    procedure PriseRowLog_MODIFY_COLUMNS(tPkg: TTransPkgItem);
    function PriseRowLog_UniqueClusteredKeys(BinReader: TbinDataReader; DbTable: TdbTableItem): string;
    procedure DDLClear;
    procedure DDLPretreatment;
    procedure PriseDDLPkg_sysidxstats(DataRow: Tsql2014Opt);
    procedure logTranPkg(FTranspkg: TTransPkg);
    function getDataFrom_TEXT_MIX_DATA(Page: TPage_Id): TBytes;
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
    function ApplySysDDLChange:Boolean;
  end;

implementation

uses
  loglog, plugins, OpCode, contextCode, dbFieldTypes,comm_func,
  Memory_Common, sqlextendedprocHelper, Windows, Xml.XMLIntf,Xml.XMLDoc;

type
  TRawElement = packed record
    Offset: Cardinal;
    Length: Word;
  end;

{ TSql2014logAnalyzer }

function TSql2014logAnalyzer.binEquals(v1, v2: TBytes): Boolean;
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

constructor TSql2014logAnalyzer.Create(PkgMgr:TTransPkgMgr;LogSource: TLogSource);
begin
  inherited Create(False);

  FPkgMgr := PkgMgr;
  FLogSource := LogSource;
  FRows := TObjectList.Create;
  FRows.OwnsObjects := True;
  DDL := TDDLMgr.Create;
  AllocUnitMgr := TAllocUnitMgr.Create;
  IDXs:=TDDL_Idxs_ColsMgr.Create;
  IDXstats:=TObjectList.create;
  Rscols := TObjectList.create;
  Hvu := THexValueHelper.Create(LogSource);
  Self.NameThreadForDebugging('TSql2014logAnalyzer', Self.ThreadID);
  FLogSource.Loger.Add('Analyzer init...');
end;

destructor TSql2014logAnalyzer.Destroy;
begin
  Rscols.Free;
  FRows.Clear;
  FRows.Free;
  DDL.Free;
  AllocUnitMgr.Free;
  IDXs.Free;
  IDXstats.free;
  Hvu.Free;
  inherited;
end;

procedure TSql2014logAnalyzer.DDLClear;
var
  I,J:Integer;
  ddlitem :TDDLItem;
  ddlitem_J: TDDLItem;
begin
  //���drop table������drop column,drop index�ȡ�������
  for I := 0 to DDL.FItems.Count - 1 do
  begin
    ddlitem := TDDLItem(DDL.FItems[I]);
    if (ddlitem.OpType = Opt_Delete) and (ddlitem.xType = 'u') then
    begin
      for J := DDl.FItems.Count - 1 downto 0 do
      begin
        ddlitem_J := TDDLItem(DDl.FItems[J]);
        if ddlitem_J.OpType = Opt_Delete then
        begin
          if TDDLItem_Delete(ddlitem_J).ParentId = ddlitem.getObjId then
          begin
            ddlitem_J.isSkip := True;
          end;
        end;
      end;
    end;
  end;
end;

procedure TSql2014logAnalyzer.DDLPretreatment;
var
  I,J:Integer;
  ddlitem :TDDLItem;
  idxObj:TDDL_IDX_stats;
  cUniKey:TDDL_Create_UniqueKey;
  cColumn:TDDL_Create_Column;
  uColumn:TDDL_Update_Column;
  rsC:TDDL_RsCols;
  dck:TDDL_Delete_Constraint_key;
begin
  for I := 0 to DDL.FItems.Count - 1 do
  begin
    ddlitem := TDDLItem(DDL.FItems[I]);
    if not ddlitem.isSkip then
    begin
      if (ddlitem is TDDL_Create_UniqueKey) then
      begin
        cUniKey := TDDL_Create_UniqueKey(ddlitem);
        for J := 0 to IDXstats.Count - 1 do
        begin
          idxObj := TDDL_IDX_stats(IDXstats[J]);
          if (cUniKey.tableid = idxObj.tableId) and (cUniKey.objName = idxObj.idxName) then
          begin
            cUniKey.isCLUSTERED := idxObj.isCLUSTERED;
            cUniKey.isUnique := idxObj.isUnique;
            Break;
          end;
        end;
      end else if (ddlitem is TDDL_Create_Column) then
      begin
        cColumn := TDDL_Create_Column(ddlitem);
        for J := 0 to Rscols.Count - 1 do
        begin
          rsC := TDDL_RsCols(Rscols[J]);
          if (rsC.TableObj.TableId = cColumn.Table.TableId) and (rsC.ColId = cColumn.field.Col_id) then
          begin
            cColumn.field.nullMap := rsC.Nullbit - 1;
            cColumn.field.is_nullable := (rsC.statusCode and $80) = 0;
            cColumn.field.leaf_pos := rsC.DataOffset;
            Break;
          end;
        end;
      end else if (ddlitem is TDDL_Update_Column) then
      begin
        uColumn := TDDL_Update_Column(ddlitem);
        for J := 0 to Rscols.Count - 1 do
        begin
          rsC := TDDL_RsCols(Rscols[J]);
          if (rsC.TableObj.TableId = uColumn.Table.TableId) and (rsC.ColId = uColumn.field.Col_id) then
          begin
            uColumn.field.nullMap := rsC.Nullbit - 1;
            uColumn.field.is_nullable := (rsC.statusCode and $80) = 0;   //128 not null
            uColumn.field.leaf_pos := rsC.DataOffset;
            Break;
          end;
        end;
      end else if (ddlitem is TDDL_Delete_Constraint_key) then
      begin
        dck := TDDL_Delete_Constraint_key(ddlitem);
        for J := 0 to IDXstats.Count - 1 do
        begin
          idxObj := TDDL_IDX_stats(IDXstats[J]);
          if (dck.tableid = idxObj.tableId) and (dck.objName = idxObj.idxName) then
          begin
            dck.isCLUSTERED := idxObj.isCLUSTERED;
            dck.isUnique := idxObj.isUnique;
            Break;
          end;
        end;
      end;
    end;
  end;
end;

function TSql2014logAnalyzer.ApplySysDDLChange:Boolean;
procedure addUcK(tableid:Integer);
var
  cols:TObjectList;
  I:Integer;
  TempItem : TDDL_Idxs_ColsItem;
  tableL:TdbTableItem;
  colItem:TdbFieldItem;
begin
  tableL := FLogSource.Fdbc.dict.tables.GetItemById(tableid);
  if tableL <> nil then
  begin
    cols := IDXs.GetById(tableid);
    if (cols <> nil) and (cols.Count > 0) then
    begin
      for I := 0 to cols.Count - 1 do
      begin
        TempItem := TDDL_Idxs_ColsItem(cols[I]);
        colItem := tableL.Fields.GetItemById(TempItem.ColId);
        if colItem <> nil then
        begin
          tableL.UniqueClusteredKeys.Add(colItem);
        end;
      end;
    end;
  end;
end;
var
  I:Integer;
  ddlitem :TDDLItem;
  ctable:TDDL_Create_Table;
  dtable:TDDL_Delete_Table;

  cColumn:TDDL_Create_Column;
  dColumn:TDDL_Delete_Column;

  uColumn:TDDL_Update_Column;

  cPk:TDDL_Create_PrimaryKey;
  cUq:TDDL_Create_UniqueKey;

  TableObj: TdbTableItem;
  FieldObj:TdbFieldItem;
  renameObj:TDDL_Update_RenameObj;
  ddlDck:TDDL_Delete_Constraint_key;
begin
  Result := False;
  for I := 0 to DDL.FItems.Count - 1 do
  begin
    ddlitem := TDDLItem(DDL.FItems[I]);
    if ddlitem.isSkip then
      Continue;

    if (ddlitem.OpType = Opt_Insert) then
    begin
      Result := True;
      if ddlitem.xType = 'u' then
      begin
        ctable := TDDL_Create_Table(ddlitem);
        FLogSource.Fdbc.dict.tables.addTable(ctable.TableObj);
        ctable.TableObj := nil;
      end else if ddlitem.xType = 'column' then
      begin
        cColumn := TDDL_Create_Column(ddlitem);
        cColumn.Table.Fields.addField(cColumn.field);
      end else if ddlitem.xType = 'pk' then
      begin
        cPk := TDDL_Create_PrimaryKey(ddlitem);
        if cPk.isCLUSTERED then
        begin
          addUcK(cPk.tableid);
        end;
      end else if ddlitem.xType = 'uq' then
      begin
        cUq := TDDL_Create_UniqueKey(ddlitem);
        if cUq.isCLUSTERED and cUq.isUnique then
        begin
          addUcK(cUq.tableid);
        end;
      end;
    end else if (ddlitem.OpType = Opt_Delete) then begin
      Result := True;
      if ddlitem.xType = 'u' then
      begin
        dtable := TDDL_Delete_Table(ddlitem);
        FLogSource.Fdbc.dict.tables.RemoveTable(dtable.getObjId);
      end else if ddlitem.xType = 'column' then
      begin
        dColumn := TDDL_Delete_Column(ddlitem);
        TableObj := FLogSource.Fdbc.dict.tables.GetItemById(dColumn.TableId);
        if TableObj <> nil then
        begin
          TableObj.Fields.RemoveField(dColumn.objName);
        end;
      end else if ddlitem.xType = 'constraint' then
      begin
        if ddlitem is TDDL_Delete_Constraint_key then
        begin
          ddlDck := TDDL_Delete_Constraint_key(ddlitem);
          if ddlDck.isCLUSTERED and ddlDck.isUnique then
          begin
            TableObj := FLogSource.Fdbc.dict.tables.GetItemById(ddlDck.tableid);
            if TableObj <> nil then
            begin
              TableObj.UniqueClusteredKeys.Clear;
            end;
          end;
        end;
      end;
    end else if (ddlitem.OpType = Opt_Update) then begin
      Result := True;
      if ddlitem.xType = 'rename' then
      begin
        renameObj := TDDL_Update_RenameObj(ddlitem);
        if renameObj.subType='u' then
        begin
          //table
          TableObj := FLogSource.Fdbc.dict.tables.GetItemById(renameObj.ObjId);
          if TableObj <> nil then
          begin
            TableObj.TableNmae := renameObj.newName
          end;
        end else if renameObj.subType='column' then
        begin
          //column
          TableObj := FLogSource.Fdbc.dict.tables.GetItemById(renameObj.ObjId);
          if TableObj <> nil then
          begin
            FieldObj := TableObj.Fields.GetItemById(renameObj.colId);
            FieldObj.ColName := renameObj.newName;
          end;
        end;
      end else if ddlitem.xType = 'column' then
      begin
        uColumn := TDDL_Update_Column(ddlitem);
        FieldObj := uColumn.Table.Fields.GetItemById(uColumn.field.Col_id);
        if FieldObj<>nil then
        begin
          FieldObj.ColName := uColumn.field.ColName;
          FieldObj.type_id := uColumn.field.type_id;
          FieldObj.Max_length := uColumn.field.Max_length;

          FieldObj.procision := uColumn.field.procision;
          FieldObj.scale := uColumn.field.scale;
          FieldObj.collation_name := uColumn.field.collation_name;
          FieldObj.CodePage := uColumn.field.CodePage;

          if uColumn.field.leaf_pos<>0 then
          begin
            FieldObj.nullMap := uColumn.field.nullMap;
            FieldObj.is_nullable := uColumn.field.is_nullable;
            FieldObj.leaf_pos := uColumn.field.leaf_pos;
          end;
        end;
      end;
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
      FLogSource.Loger.Add('��δ�����SQLBuilder��%d', [Integer(aRowData.OperaType)], log_error or LOG_IMPORTANT);
    end;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderSql_Update(aRowData: Tsql2014Opt): string;
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
    //û�оۺϼ�
    if aRowData.old_data<>nil then
    begin
      //��oldԴ��ͨ��olddata����where
      for I := 0 to aRowData.old_data.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.old_data.Fields[I]);
        whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
      end;
      if whereStr.Length > 0 then
      begin
        Delete(whereStr, 1, 4);  //"and "
      end;
    end else begin
      //û��Ψһ�ۺ�,Ҳû��oldԴ
      whereStr :=' 1=2 --������Ψһ�ۺ�,���޷���ȡ����Դ����Ϊ�����á�Ψһ�ۺϡ���ʹ������Դ��ȡ���';
    end
  end;

  if aRowData.new_data = nil then
  begin
    //û�������ݡ�ʹ��select��װ
    updateStr := FLogSource.Fdbc.getUpdateSQLfromSelect(aRowData.Table, whereStr);
    if updateStr='' then
    begin
      Result := '�������Ѷ�ʧ��'+whereStr;
      Exit;
    end;
  end else begin
    if aRowData.old_data<>nil then
    begin
      //�¾����ݶ��У���ԱȲ�������update
      updateStr := '';
      for I := 0 to aRowData.Table.Fields.Count - 1 do
      begin
        if not aRowData.Table.Fields[i].isLogSkipCol then
        begin
          raw_old := aRowData.old_data.getField(aRowData.Table.Fields[i].Col_id);
          raw_new := aRowData.new_data.getField(aRowData.Table.Fields[i].Col_id);
          if (raw_new=nil)  and (raw_old=nil)then
          begin

          end else
          if raw_new = nil then
          begin
            //var ֵ ��������>  null
            updateStr := updateStr + Format(', %s=NULL',[raw_old.field.getSafeColName]);
          end else if (raw_old = nil) or (not binEquals(raw_new.value, raw_old.value)) then begin
            updateStr := updateStr + Format(', %s=%s',[raw_new.field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(raw_new.field, raw_new.value)]);
          end
        end;
      end;
      if updateStr.Length = 0 then
      begin
        //��������ֶ�һ�����϶����Ǹ��»�ԭʼ״̬�ˣ�
        Result := '';
        exit;
      end;
      Delete(updateStr, 1, 2);  //", "
    end else begin
      //û��old�������µ�ȫ���ֶ�����update����Ψһ�ۺ�
      updateStr := '';
      for I := 0 to aRowData.Table.Fields.Count - 1 do
      begin
        if aRowData.Table.Fields[i].isLogSkipCol then Continue;

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
            //var ֵ ��������>  null
            updateStr := updateStr + Format(', %s=NULL',[raw_new.field.getSafeColName]);
          end else begin
            updateStr := updateStr + Format(', %s=%s',[raw_new.field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(raw_new.field, raw_new.value)]);
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
    if aRowData.R1<>nil then
    begin
      //Update��delete
      for I := 0 to aRowData.old_data.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.old_data.Fields[I]);
        whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
      end;
    end else begin
      for I := 0 to aRowData.new_data.Fields.Count - 1 do
      begin
        fieldval := PdbFieldValue(aRowData.new_data.Fields[I]);
        whereStr := whereStr + Format('and %s=%s ', [fieldval.field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
      end;
    end;
    if whereStr.Length > 0 then
    begin
      Delete(whereStr, 1, 4);  //"and "
    end;
    Result := whereStr;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderXML(aRowData: Tsql2014Opt): string;
begin
  if not aRowData.deleteFlag then
  begin
    case aRowData.OperaType of
      Opt_Insert:
        Result := DML_BuilderXML_Insert(aRowData);
      Opt_Update:
        Result := DML_BuilderXML_Update(aRowData);
      Opt_Delete:
        Result := DML_BuilderXML_Delete(aRowData);
    else
      FLogSource.Loger.Add('��δ�����XMLBuilder��%d', [Integer(aRowData.OperaType)], log_error or LOG_IMPORTANT);
    end;
  end;
end;

function TSql2014logAnalyzer.DML_BuilderXML_SafeStr(aVal: string): string;
begin
  if aVal <> '' then
  begin
    result := aVal.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('''','&apos;').Replace('"','&quot;');
  end else begin
    Result := ''
  end;
end;

function TSql2014logAnalyzer.DML_BuilderXML_Delete(aRowData: Tsql2014Opt): string;
var
  I,j: Integer;
  field: TdbFieldItem;
  fieldval: PdbFieldValue;
  StrVal: string;
begin
  Result := '<opt type="delete" table="'+aRowData.Table.getFullName+'">';
  Result := Result + '<data>';
  if aRowData.R1<>nil then
  begin
    //Update��delete
    for I := 0 to aRowData.old_data.Fields.Count - 1 do
    begin
      fieldval := PdbFieldValue(aRowData.old_data.Fields[I]);
      StrVal := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
      StrVal := DML_BuilderXML_SafeStr(StrVal);
      Result := Result + Format('<%s>%s</%s>', [fieldval.field.ColName,StrVal,fieldval.field.ColName]);
    end;
  end else begin
    for I := 0 to aRowData.new_data.Fields.Count - 1 do
    begin
      fieldval := PdbFieldValue(aRowData.new_data.Fields[I]);
      StrVal := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
      StrVal := DML_BuilderXML_SafeStr(StrVal);
      Result := Result + Format('<%s>%s</%s>', [fieldval.field.ColName,StrVal,fieldval.field.ColName]);
    end;
  end;
  Result := Result + '</data>';
  Result := Result + '<key>';
  if aRowData.table.UniqueClusteredKeys.Count>0 then
  begin
    for I := 0 to aRowData.table.UniqueClusteredKeys.Count-1 do
    begin
      field := TdbFieldItem(aRowData.table.UniqueClusteredKeys[i]);
      for J := 0 to aRowData.new_data.Fields.Count -1 do
      begin
        fieldval := PdbFieldValue(aRowData.new_data.Fields[j]);
        if fieldval.field.Col_id=field.Col_id then
        begin
          StrVal := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
          StrVal := DML_BuilderXML_SafeStr(StrVal);
          Result := Result + Format('<%s>%s</%s>', [fieldval.field.ColName,StrVal,fieldval.field.ColName]);
          Break;
        end;
      end;
    end;
  end;
  Result := Result + '</key>';
  Result := Result + '</opt>';
end;

function TSql2014logAnalyzer.DML_BuilderXML_Insert(aRowData: Tsql2014Opt): string;
var
  StrVal: string;
  I: Integer;
  fieldval: PdbFieldValue;
begin
  Result := '<opt type="insert" table="'+aRowData.Table.getFullName+'">';
  for I := 0 to aRowData.new_data.Fields.Count - 1 do
  begin
    fieldval := PdbFieldValue(aRowData.new_data.Fields[I]);
    StrVal := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
    StrVal := DML_BuilderXML_SafeStr(StrVal);
    Result := Result + Format('<%s>%s</%s>', [fieldval.field.ColName,StrVal,fieldval.field.ColName]);
  end;
  Result := Result + '</opt>';
end;

function TSql2014logAnalyzer.DML_BuilderXML_Update(aRowData: Tsql2014Opt): string;
var
  StrVal: string;
  I,J,L: Integer;
  raw_old,raw_new: PdbFieldValue;

  xml:IXMLDocument;
  rootNode,fieldNode,TmpNode:IXMLNode;
  nodeName:string;
begin
  xml := TXMLDocument.Create(nil);
  xml.Active := True;
  rootNode := xml.AddChild('opt');
  rootNode.Attributes['type'] := 'update';
  rootNode.Attributes['table'] := aRowData.Table.getFullName;
  try
    if (aRowData.new_data <> nil) and (aRowData.old_data <> nil) then
    begin
      for I := 0 to aRowData.Table.Fields.Count - 1 do
      begin
        if aRowData.Table.Fields[i].isLogSkipCol then Continue;
        raw_old := aRowData.old_data.getField(aRowData.Table.Fields[i].Col_id);
        raw_new := aRowData.new_data.getField(aRowData.Table.Fields[i].Col_id);

        nodeName := XML_SafeNodeName(aRowData.Table.Fields[i].ColName);
        if nodeName = '' then
          nodeName := '_';
        if checkXmlNodeExists(rootNode, nodeName) then
        begin
          for L := 0 to 10000 do
          begin
            if not checkXmlNodeExists(rootNode, nodeName + '_' + inttostr(L)) then
            begin
              nodeName := nodeName + '_' + inttostr(L);
              Break;
            end;
          end;
        end;
        fieldNode := rootNode.AddChild(nodeName);
        fieldNode.Attributes['dtype'] := getSingleDataTypeStr(aRowData.Table.Fields[i].type_id);
        for J := 0 to aRowData.Table.UniqueClusteredKeys.Count-1 do
        begin
          if TdbFieldItem(aRowData.Table.UniqueClusteredKeys[j]).Col_id = aRowData.Table.Fields[i].Col_id then
          begin
            fieldNode.Attributes['iskey'] := '1';
            Break;
          end;
        end;
        TmpNode := fieldNode.AddChild('old');
        if raw_old = nil then
        begin
          TmpNode.Attributes['null']:= '1';
        end else begin
          StrVal := Hvu.GetFieldStrValue(raw_old.field, raw_old.value);
          if StrVal='NULL' then
          begin
            TmpNode.Attributes['null']:= '1';
          end else begin
            TmpNode.Text := StrVal;
          end;
        end;

        TmpNode := fieldNode.AddChild('new');
        if raw_new = nil then
        begin
          TmpNode.Attributes['null']:= '1';
        end else begin
          StrVal := Hvu.GetFieldStrValue(raw_new.field, raw_new.value);
          if StrVal='NULL' then
          begin
            TmpNode.Attributes['null']:= '1';
          end else begin
            TmpNode.Text := StrVal;
          end;
        end;
      end;
    end;
  except
    on ee:Exception do
    begin
      FLogSource.Loger.Add('DML_BuilderXML_Update ����xml ʧ�ܣ�' + ee.Message);
    end
  end;
  Result := xml.XML.Text;
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
    StrVal := StrVal + ',' + Hvu.GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value);
  end;
  if aRowData.new_data.Fields.Count > 0 then
  begin
    Delete(fields, 1, 1);
    Delete(StrVal, 1, 1);
  end;
  Result := '';
  if aRowData.Table.hasIdentity then
    Result := Format('SET IDENTITY_INSERT %s ON', [aRowData.Table.getFullName]) + WIN_EOL;
  Result := Result + Format('INSERT INTO %s(%s)values(%s);', [aRowData.Table.getFullName, fields, StrVal]) + WIN_EOL;
  if aRowData.Table.hasIdentity then
    Result := Result + Format('SET IDENTITY_INSERT %s OFF', [aRowData.Table.getFullName]) + WIN_EOL;
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
          whereStr := whereStr + Format('and %s=%s ', [field.getSafeColName, Hvu.GetFieldStrValueWithQuoteIfNeed(field, fieldval.value)]);
          Break;
        end;
      end;
    end;
    Delete(whereStr, 1, 4);
  end else
    whereStr := DML_BuilderSql_Where(aRowData);
  Result := Format('DELETE FROM %s WHERE %s;', [aRowData.Table.getFullName, whereStr]);
end;

procedure TSql2014logAnalyzer.logTranPkg(FTranspkg: TTransPkg);
var
  xmlStr:string;
  I:Integer;
  TTpi: TTransPkgItem;
  rl:PRawLog;
  OriginRowData:TBytes;
  partition_id :UInt64;
  Rldo: PRawLog_DataOpt;
  table:TdbTableItem;
  objlst:TList;
begin
  try
    objlst:=TList.Create;
    xmlStr := '<root><transId>' + TranId2Str(FTranspkg.Ftransid) + '</transId><rows>';
    for I := 0 to FTranspkg.Items.Count - 1 do
    begin
      TTpi := TTransPkgItem(FTranspkg.Items[I]);
      xmlStr := xmlStr + '<item lsn="' + lsn2str(TTpi.LSN) + '">';
      xmlStr := xmlStr + '<bin>' + DumpMemory2Str(TTpi.Raw.data, TTpi.Raw.dataSize) + '</bin>';
      rl := TTpi.Raw.data;
      partition_id := 0;
      if (rl.OpCode = LOP_MODIFY_ROW) or (rl.OpCode = LOP_MODIFY_COLUMNS) then
      begin
        OriginRowData := getUpdateSoltData(FLogSource.Fdbc, rl.PreviousLSN);
        if OriginRowData <> nil then
        begin
          xmlStr := xmlStr + '<data>' + DumpMemory2Str(@OriginRowData[0], Length(OriginRowData)) + '</data>';
        end;
        Rldo := TTpi.Raw.data;
        partition_id := Rldo.PartitionId;
      end else if (rl.OpCode = LOP_INSERT_ROWS) or (rl.OpCode = LOP_DELETE_ROWS) then begin
        Rldo := TTpi.Raw.data;
        partition_id := Rldo.PartitionId;
      end;
      if partition_id>0 then
      begin
        if objlst.IndexOf(Pointer(partition_id))=-1 then
          objlst.Add(Pointer(partition_id));

      end;
      xmlStr := xmlStr + '</item>'
    end;
    xmlStr := xmlStr + '</rows><tables>';
    for I := 0 to objlst.Count - 1 do
    begin
      table := FLogSource.Fdbc.dict.tables.GetItemByPartitionId(uint64(objlst[I]));
      if table <> nil then
      begin
        xmlStr := xmlStr + table.AsXml;
      end;
    end;
    xmlStr := xmlStr + '</tables></root>';
    FLogSource.Loger.Add(xmlStr, LOG_IMPORTANT or LOG_DATA);
  except
    on dd: Exception do
    begin
      FLogSource.Loger.Add('dump logTranPkg fail!!' + dd.Message, LOG_ERROR);
    end;
  end;
end;

procedure TSql2014logAnalyzer.Execute;
var
  TTsPkg: TTransPkg;
begin
  inherited;
  FLogSource.Loger.Add('Analyzer Start...');
  while not Terminated do
  begin
    if FPkgMgr.FpaddingPrisePkg.Count > 0 then
    begin
      TTsPkg := TTransPkg(FPkgMgr.FpaddingPrisePkg.Pop);
      try
        FRows.Clear;
        DDL.FItems.Clear;
        AllocUnitMgr.FItems.Clear;
        IDXs.FItems.Clear;
        IDXstats.Clear;
        Rscols.Clear;
        Execute2(TTsPkg);
      except
        on ee:Exception do
        begin
          FLogSource.Loger.Add('TSql2014logAnalyzer.����鴦��ʧ�ܣ�TranId:' + TranId2Str(TTsPkg.Ftransid) + '.' + ee.Message, LOG_ERROR);
          logTranPkg(TTsPkg);
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
  FLogSource.Loger.Add(FormatDateTime('====>yyyy-MM-dd HH:nn:ss.zzz',now), LOG_DEBUG);
  FLogSource.Loger.Add('TSql2014logAnalyzer.Execute ==> transId:%s, MinLsn:%s, cnt:%d', [TranId2Str(FTranspkg.Ftransid),LSN2Str(TTransPkgItem(FTranspkg.Items[0]).lsn), FTranspkg.Items.Count],LOG_DEBUG);
  //֪ͨ���
  serializeToBin(FTranspkg, mm);
  PluginsMgr.onTransPkgRev(FLogSource.Fdbc.GetPlgSrc, mm);
  FreeMem(mm.data);

//  if FTranspkg.Ftransid.Id1>=$83D then
//    Exit;

  //��ʼ��������
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    TTpi := TTransPkgItem(FTranspkg.Items[I]);
    PriseRowLog(TTpi);
  end;

  //����Sql
  for I := 0 to FRows.Count - 1 do
  begin
    DataRow_buf := Tsql2014Opt(FRows[i]);
    if DataRow_buf.deleteFlag or DataRow_buf.isMixData then
    begin
      Continue;
    end;
    if DataRow_buf.R0<>nil then
    begin
      TmpBinReader := TbinDataReader.Create(DataRow_buf.R0, $2000);
      try
        DataRow_buf.new_data := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
      finally
        TmpBinReader.Free;
      end;
      if DataRow_buf.R1 <> nil then
      begin
        TmpBinReader := TbinDataReader.Create(DataRow_buf.R1, $2000);
        try
          DataRow_buf.old_data := PriseRowLog_InsertDeleteRowData(DataRow_buf.table, TmpBinReader);
        finally
          TmpBinReader.Free;
        end;
      end;
    end;

    FLogSource.Loger.Add('-->' + DML_BuilderSql(DataRow_buf), LOG_DEBUG);
    //continue;
    if DataRow_buf.Table.Owner = 'sys' then
    begin
      //�����������ϵͳ������ddl���
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
      // dml ���
      DMLitem := TDMLItem.Create;
      DMLitem.data := DataRow_buf;
      DDL.Add(DMLitem);
    end;
  end;
  DDLClear;
  DDLPretreatment;
  PluginsMgr.onTranSql(FLogSource.Fdbc.GetPlgSrc, GenSql);
  PluginsMgr.onTransXml(FLogSource.Fdbc.GetPlgSrc, GenXML);
//  Loger.Add(GenSql);
//  Loger.Add(GenXML);
Exit;
  if ApplySysDDLChange then
  begin
    //�����ṹ�б�������±����ṹ
    FLogSource.saveToFile;
  end;

  FLogSource.FProcCurLSN := TransCommitLsn;
  FLogSource.saveToFile_LSN;
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
    ResList.Add('--TransId:' + TranId2Str(TransId));
    ResList.Add('--TranBeinTime:' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransBeginTime));
    ResList.Add('--CommitTranTime:' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransCommitTime));

    for I := 0 to DDL.FItems.Count - 1 do
    begin
      ddlitem := TDDLItem(DDL.FItems[I]);
      if not ddlitem.isSkip then
      begin
        Tmpstr := '';
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
    end;
    ResList.Add('--genSql end--');
    Result := ResList.Text;
  finally
    ResList.Free;
  end;
end;

function TSql2014logAnalyzer.GenXML: string;
var
  ddlitem: TDDLItem;
  I: Integer;
  ResList: TStringList;
  Tmpstr:string;
begin
  ResList := TStringList.Create;
  try
    ResList.Add('<?xml version="1.0" encoding="gb2312"?>');
    ResList.Add('<root>');
    ResList.Add('<TransId>' + TranId2Str(TransId)+'</TransId>');
    ResList.Add('<TranBeinTime>' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransBeginTime)+'</TranBeinTime>');
    ResList.Add('<CommitTranTime>' + formatdatetime('yyyy-MM-dd HH:nn:ss.zzz', TransCommitTime)+'</CommitTranTime>');
    ResList.Add('<details>');
    for I := 0 to DDL.FItems.Count - 1 do
    begin
      ddlitem := TDDLItem(DDL.FItems[I]);
      if not ddlitem.isSkip then
      begin
        Tmpstr := '';
        case ddlitem.OpType of
          Opt_Insert:
            begin
              Tmpstr := '<row id="' + IntToStr(I) + '" type="ddl">' + GenSql_DDL_Insert(TDDLItem_Insert(ddlitem)) + '</row>';
            end;
          Opt_Update:
            begin
              Tmpstr := '<row id="' + IntToStr(I) + '" type="ddl">' + GenSql_DDL_Update(TDDLItem_Update(ddlitem)) + '</row>';
            end;
          Opt_Delete:
            begin
              Tmpstr := '<row id="' + IntToStr(I) + '" type="ddl">' + GenSql_DDL_Delete(TDDLItem_Delete(ddlitem)) + '</row>';
            end;
          Opt_DML:
            begin
              Tmpstr := '<row id="' + IntToStr(I) + '" type="dml">' + DML_BuilderXML(TDMLItem(DDL.FItems[I]).data) + '</row>';
            end;
        end;
        if Tmpstr <> '' then
          ResList.Add(Tmpstr);
      end;
    end;
    ResList.Add('</details>');
    ResList.Add('</root>');
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
  end else if ddlitem.xType = 'uq' then
  begin
    Result := GenSql_CreateUniqueKey(TDDL_Create_UniqueKey(ddlitem));
  end else if ddlitem.xType = 'c' then
  begin
    Result := GenSql_CreateCheck(TDDL_Create_Check(ddlitem));
  end else if ddlitem.xType = 'column' then
  begin
    Result := GenSql_CreateColumn(TDDL_Create_Column(ddlitem));
  end
  else
  begin

  end;
end;

function TSql2014logAnalyzer.GenSql_DDL_Delete(ddlitem: TDDLItem_Delete): string;
begin
  if ddlitem.xType = 'u' then
  begin
    Result := GenSql_DropTable(TDDL_Delete_Table(ddlitem));
  end
  else if ddlitem.xType = 'constraint' then
  begin
    Result := GenSql_DropConstraint(TDDL_Delete_Constraint(ddlitem));
  end else if ddlitem.xType = 'column' then
  begin
    Result := GenSql_DropColumn(TDDL_Delete_Column(ddlitem));
  end
  else
  begin

  end;
end;

function TSql2014logAnalyzer.GenSql_DDL_Update(ddlitem: TDDLItem_Update): string;
begin
  if ddlitem.xType = 'u' then
  begin
    //Result := GenSql_UpdateTable(TDDL_Update_Table(ddlitem));
  end else if ddlitem.xType = 'rename' then
  begin
    Result := GenSql_UpdateRenameObj(TDDL_Update_RenameObj(ddlitem));
  end else if ddlitem.xType = 'column' then
  begin
    Result := GenSql_UpdateColumn(TDDL_Update_Column(ddlitem));
  end
  else
  begin

  end;
end;

function TSql2014logAnalyzer.GenSql_UpdateRenameObj(ddlitem: TDDL_Update_RenameObj): string;
const
  SQLTEMPLATE = 'exec sp_rename ''%s'',''%s'';';
begin
  Result := '--sp_rename Obj id:'+IntToStr(ddlitem.ObjId);
  Result := Result + #$D#$A + Format(SQLTEMPLATE, [ddlitem.oldName, ddlitem.newName ]);
end;

function TSql2014logAnalyzer.GenSql_UpdateColumn(ddlitem: TDDL_Update_Column): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s alter column %s';
var
  tmpStr:string;
begin
  Result := '--alter Column table id:'+IntToStr(ddlitem.Table.TableId);
  tmpStr := ddlitem.field.getSafeColName + ' ';
  tmpStr := tmpStr + ddlitem.field.getTypeStr + ' ';
  if ddlitem.field.collation_name<>'' then
  begin
    tmpStr := tmpStr + 'COLLATE '+ ddlitem.field.collation_name + ' ';
  end;
  if ddlitem.field.is_nullable then
    tmpStr := tmpStr + 'NULL'
  else
     tmpStr := tmpStr + 'NOT NULL';

  Result := Result + #$D#$A + Format(SQLTEMPLATE, [ddlitem.Table.getFullName, tmpStr]);
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
  if (DDLtable <> nil) and (DDLtable.OpType = Opt_Insert) then
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

function TSql2014logAnalyzer.GenSql_DropConstraint(ddlitem: TDDL_Delete_Constraint): string;
var
  Table:TdbTableItem;
  resStr:Tstringlist;
begin
  resStr := Tstringlist.Create;
  try
    resStr.Add('--drop constraint');
    resStr.Add('--subType:'+ddlitem.subType);
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
  SQLTEMPLATE = 'ALTER TABLE %s ADD %s %s; ';
var
  resStr:Tstringlist;
  tmpStr:string;
begin
  resStr:=Tstringlist.Create;
  try
    resStr.Add('--ALTER TABLE Add Column');
    resStr.Add('--Tableid:'+inttostr(ddlitem.Table.TableId));
    resStr.Add('--columnName:'+ddlitem.field.ColName);
    tmpStr := ddlitem.field.getTypeStr + ' ';
    if ddlitem.field.collation_name<>'' then
    begin
      tmpStr := tmpStr + 'COLLATE '+ ddlitem.field.collation_name + ' ';
    end;
    if ddlitem.field.is_nullable then
    begin
      tmpStr := tmpStr + 'NULL';
    end
    else
    begin
      tmpStr := tmpStr + 'NOT NULL';
    end;
    resStr.Add(Format(SQLTEMPLATE, [ddlitem.Table.getFullName, ddlitem.field.getSafeColName, tmpStr]));
    Result := resStr.Text;
  finally
    resStr.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_CreateCheck(ddlitem: TDDL_Create_Check): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s ADD CONSTRAINT [%s] CHECK(%s) ';
var
  DDLtable: TDDLItem;
  tableL: TdbTableItem;
  resStr:Tstringlist;
  TmpStr:string;
begin
  Result := '';
  DDLtable := ddl.GetItem(ddlitem.tableid);
  if DDLtable <> nil then
  begin
    tableL := TDDL_Create_Table(DDLtable).TableObj;
  end
  else
  begin
    tableL := FLogSource.Fdbc.dict.tables.GetItemById(ddlitem.tableid);
  end;

  if tableL = nil then
  begin
    TmpStr := 'objId:'+ IntToStr(ddlitem.objId) + WIN_EOL;
    TmpStr := TmpStr +'objName:'+ ddlitem.objName+ WIN_EOL;
    TmpStr := TmpStr +'tableid:'+ IntToStr(ddlitem.tableid)+ WIN_EOL;
    TmpStr := TmpStr +'value:'+ ddlitem.value+ WIN_EOL;
    FLogSource.Loger.Add('GenSql_CreateCheck fail! ->' + TmpStr, LOG_ERROR or LOG_IMPORTANT);

    Exit;
  end;

  resStr:=Tstringlist.Create;
  try
    resStr.Add('--Create Check key');
    resStr.Add('--Tableid:'+inttostr(ddlitem.tableid));
    resStr.Add('--id:'+inttostr(ddlitem.objId));
    resStr.Add('--Name:'+ddlitem.objName);
    resStr.Add(Format(SQLTEMPLATE, [tableL.getFullName, ddlitem.objName, ddlitem.value]));
    Result := resStr.Text;
  finally
    resStr.Free;
  end;
end;

function TSql2014logAnalyzer.GenSql_CreateUniqueKey(ddlitem: TDDL_Create_UniqueKey): string;
const
  SQLTEMPLATE = 'ALTER TABLE %s ADD CONSTRAINT [%s] UNIQUE %s (%s) ';
var
  DDLtable: TDDLItem;
  tableL: TdbTableItem;
  colName: string;
  CLUSTEREDType:string;
  cols:TObjectList;
  I: Integer;
  TempItem:TDDL_Idxs_ColsItem;
  dbfield:TdbFieldItem;
  resStr:Tstringlist;
  TmpStr:string;
begin
  Result := '';
  DDLtable := ddl.GetItem(ddlitem.tableid);
  if DDLtable <> nil then
  begin
    tableL := TDDL_Create_Table(DDLtable).TableObj;
  end
  else
  begin
    tableL := FLogSource.Fdbc.dict.tables.GetItemById(ddlitem.tableid);
  end;

  if tableL = nil then
  begin
    TmpStr := 'objId:'+ IntToStr(ddlitem.objId) + WIN_EOL;
    TmpStr := TmpStr +'objName:'+ ddlitem.objName+ WIN_EOL;
    TmpStr := TmpStr +'tableid:'+ IntToStr(ddlitem.tableid)+ WIN_EOL;
    TmpStr := TmpStr +'colid:'+ IntToStr(ddlitem.colid)+ WIN_EOL;
    TmpStr := TmpStr +'value:'+ ddlitem.value+ WIN_EOL;
    TmpStr := TmpStr +'isCLUSTERED:'+ BoolToStr(ddlitem.isCLUSTERED,True)+ WIN_EOL;
    FLogSource.Loger.Add('GenSql_CreateUniqueKey fail! ->' + TmpStr, LOG_ERROR or LOG_IMPORTANT);

    Exit;
  end;

  cols := IDXs.GetById(ddlitem.tableid);
  if (cols <> nil) and (cols.Count > 0) then
  begin
    colName := '';
    for I := 0 to cols.Count - 1 do
    begin
      TempItem := TDDL_Idxs_ColsItem(cols[I]);
      dbfield := tableL.Fields.GetItemById(TempItem.ColId);
      if dbfield <> nil then
      begin
        colName := colName + ',' + dbfield.getSafeColName + ' ' + TempItem.orderType;
      end;
    end;
    if colName<>'' then
      Delete(colName, 1, 1);
  end;

  if ddlitem.isCLUSTERED then
    CLUSTEREDType := 'CLUSTERED'
  else
    CLUSTEREDType := 'NONCLUSTERED';

  resStr:=Tstringlist.Create;
  try
    resStr.Add('--Create Unique key');
    resStr.Add('--Tableid:'+inttostr(ddlitem.tableid));
    resStr.Add('--id:'+inttostr(ddlitem.objId));
    resStr.Add('--Name:'+ddlitem.objName);
    resStr.Add(Format(SQLTEMPLATE, [tableL.getFullName, ddlitem.objName, CLUSTEREDType, colName]));
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
  idxObj :TDDL_IDX_stats;
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


  for I := 0 to IDXstats.Count-1 do
  begin
    idxObj := TDDL_IDX_stats(IDXstats[i]);
    if (ddlitem.tableid = idxObj.tableId) and (ddlitem.objName=idxObj.idxName) then
    begin
      ddlitem.isCLUSTERED := idxObj.isCLUSTERED;
    end;
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
          colName := colName + ',' + dbfield.getSafeColName + ' ' + TempItem.orderType;
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

function TSql2014logAnalyzer.GenSql_CreateTable(ddlitem: TDDLItem): string;
const
  SQLTEMPLATE = 'CREATE TABLE %s(%s);';
var
  table: TDDL_Create_Table;
  colsStr: TStringList;
  I: Integer;
  tmpStr: string;
  FieldItem: TdbFieldItem;
begin
  table := TDDL_Create_Table(ddlitem);
  colsStr := TStringList.Create;
  try
    colsStr.Add(Format('-- Table id :%d', [table.TableObj.TableId]));
    colsStr.Add(Format('CREATE TABLE %s(', [table.TableObj.getFullName]));
    for I := 0 to table.TableObj.Fields.Count - 1 do
    begin
      FieldItem:=TdbFieldItem(table.TableObj.Fields[I]);
      tmpStr := FieldItem.getSafeColName + ' ';
      tmpStr := tmpStr + FieldItem.getTypeStr + ' ';
      if (FieldItem.collation_name<>'') then
      begin
        tmpStr := tmpStr + 'COLLATE '+ FieldItem.collation_name + ' ';
      end;
      if FieldItem.is_nullable then
      begin
        tmpStr := tmpStr + 'NULL';
      end
      else
      begin
        tmpStr := tmpStr + 'NOT NULL';
      end;
      if (FieldItem.Idt_seed>0) and (FieldItem.Idt_increment>0) then
      begin
        tmpStr := tmpStr + Format(' IDENTITY(%d,%d)',[FieldItem.Idt_seed, FieldItem.Idt_increment]);
      end;
      if I <> table.TableObj.Fields.Count - 1 then
      begin
        tmpStr := tmpStr + ', '
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
      colName := tableL.Fields.GetItemById(DefObj.colid).getSafeColName;
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
    //ɾ����,�洢���̡���ͼ ��Ĭ��ֵ�ȶ���
    PriseDDLPkg_D_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    //ɾ������
    PriseDDLPkg_D_syscolpars(DataRow);
  end else if DataRow.Table.TableNmae = 'sysidxstats' then
  begin
    //index ��Ϣ
    PriseDDLPkg_sysidxstats(DataRow);
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
      TableId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ColName := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end;
  end;

  ColObj := TDDL_Delete_Column.Create;
  ColObj.TableId := TableId;
  ColObj.objName := ColName;
  DDL.Add(ColObj);
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_U(DataRow: Tsql2014Opt);
begin
  if DataRow.Table.TableNmae = 'sysschobjs' then
  begin
    PriseDDLPkg_U_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    //�޸���
    PriseDDLPkg_U_syscolpars(DataRow);
  end else if DataRow.Table.TableNmae = 'sysrscols' then
  begin
    //�޸���
    PriseDDLPkg_U_sysrscols(DataRow);
  end
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_U_sysschobjs(DataRow: Tsql2014Opt);
var
  ObjId: Integer;
  oldName,newName:string;
  renameObj:TDDL_Update_RenameObj;
  DDLtable: TDDLItem;
  table: TdbTableItem;
begin
  if TryStrToInt(DataRow.new_data.getFieldStrValue('id'), ObjId) then
  begin
    newName := DataRow.new_data.getFieldStrValue('name');
    oldName := DataRow.old_data.getFieldStrValue('name');
    if oldName <> newName then
    begin
      //ObjReName
      DDLtable := ddl.GetItem(ObjId);
      if DDLtable <> nil then
      begin
        table := TDDL_Create_Table(DDLtable).TableObj;
      end
      else
      begin
        table := FLogSource.Fdbc.dict.tables.GetItemById(ObjId);
      end;

      renameObj := TDDL_Update_RenameObj.Create;
      renameObj.oldName := '[' + table.Owner + '].[' + oldName.Replace(']', ']]') + ']';
      renameObj.newName := newName;
      renameObj.ObjId := ObjId;
      renameObj.subType := DataRow.new_data.getFieldStrValue('type');
      DDL.Add(renameObj);
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_U_syscolpars(DataRow: Tsql2014Opt);
var
  ddlitem: TDDLItem;
  FieldItem: TdbFieldItem;
  table:TdbTableItem;
  //tmpVar
  collation_id: Integer;
  TmpStr: string;
  ObjId: Integer;
  ddl_col:TDDL_Update_Column;
  I:Integer;
  pdd: PdbFieldValue;
  OldCol:TdbFieldItem;
  oldName,newName:string;
  renameObj:TDDL_Update_RenameObj;
begin
  if TryStrToInt(DataRow.new_data.getFieldStrValue('id'), ObjId) then
  begin
    newName := DataRow.new_data.getFieldStrValue('name');
    oldName := DataRow.old_data.getFieldStrValue('name');
    if oldName <> newName then
    begin
      //ObjReName
      ddlitem := ddl.GetItem(ObjId);
      if ddlitem <> nil then
      begin
        table := TDDL_Create_Table(ddlitem).TableObj;
      end
      else
      begin
        table := FLogSource.Fdbc.dict.tables.GetItemById(ObjId);
      end;

      renameObj := TDDL_Update_RenameObj.Create;
      renameObj.oldName := table.getFullName+'.['+oldName.Replace(']',']]')+']';
      renameObj.newName := newName;
      renameObj.ObjId := table.TableId;
      renameObj.colId := ObjId;
      renameObj.subType := 'column';
      DDL.Add(renameObj);
      exit;
    end;

    FieldItem := TdbFieldItem.Create;
    FieldItem.Col_id := StrToInt(DataRow.new_data.getFieldStrValue('colid'));
    FieldItem.ColName := newName;
    FieldItem.type_id := StrToInt(DataRow.new_data.getFieldStrValue('xtype')) and $FF;
    FieldItem.Max_length := StrToInt(DataRow.new_data.getFieldStrValue('length'));
    FieldItem.procision := StrToInt(DataRow.new_data.getFieldStrValue('prec'));
    FieldItem.scale := StrToInt(DataRow.new_data.getFieldStrValue('scale'));
    FieldItem.is_nullable := (StrToInt(DataRow.new_data.getFieldStrValue('status')) and 1) = 0;
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

    for I := DataRow.new_data.fields.Count - 1 downto 0 do
    begin
      pdd := PdbFieldValue(DataRow.new_data.fields[I]);
      if LowerCase(pdd.field.ColName) = 'idtval' then
      begin
        FieldItem.Idt_seed := PDWORD(@pdd.value[0])^;
        FieldItem.Idt_increment := PDWORD(@pdd.value[4])^;
        Break;
      end;
    end;

    ddlitem := DDL.GetItem(ObjId);
    if (ddlitem <> nil) and (ddlitem.xType = 'u') then
    begin
      //���޸��ֶ�
      OldCol := TDDL_Create_Table(ddlitem).TableObj.Fields.GetItemById(FieldItem.Col_id);
      if OldCol<>nil then
      begin
        OldCol.ColName := FieldItem.ColName;
        OldCol.type_id := FieldItem.type_id;
        OldCol.Max_length := FieldItem.Max_length;

        OldCol.procision := FieldItem.procision;
        OldCol.scale := FieldItem.scale;
        OldCol.collation_name := FieldItem.collation_name;

        OldCol.CodePage := FieldItem.CodePage;
        OldCol.Idt_seed := FieldItem.Idt_seed;
        OldCol.Idt_increment := FieldItem.Idt_increment;
        if OldCol.Idt_increment>0 then
          TDDL_Create_Table(ddlitem).TableObj.hasIdentity := True;
      end;
      FieldItem.free;
    end
    else
    begin
      table := FLogSource.Fdbc.dict.tables.GetItemById(ObjId);
      if table<>nil then
      begin
        ddl_col := TDDL_Update_Column.Create;
        ddl_col.Table := table;
        ddl_col.field := FieldItem;
        DDL.Add(ddl_col);
      end else begin
        FieldItem.Free;
        //���Ǳ�����
        FLogSource.Loger.Add('Error Message:PriseDDLPkg_U_syscolpars table not exists!tableid:%d',[ObjId]);
      end;
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_U_sysrscols(DataRow: Tsql2014Opt);
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
  FieldItem: TdbFieldItem;
  TableItem:TdbTableItem;
  ctable: TDDL_Create_Table;
  rsC:TDDL_RsCols;
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
      rowsetid := StrToInt64(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'rscolid' then
    begin
      ColId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'status' then
    begin
      statusCode := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'offset' then
    begin
      DataOffset := Hvu.getShort(pdd.value, 0, 2);
    end
    else if pdd_field_ColName = 'nullbit' then
    begin
      Nullbit := Hvu.getShort(pdd.value, 0, 2);
    end;
  end;
  ObjId := AllocUnitMgr.GetObjId(rowsetid);
  if ObjId <> 0 then
  begin
    ddlitem := DDL.GetItem(ObjId);
    if (ddlitem <> nil) and (ddlitem.xType = 'u') then
    begin
      ctable := TDDL_Create_Table(ddlitem);
      FieldItem := ctable.TableObj.Fields.GetItemById(ColId);
      if FieldItem <> nil then
      begin
        FieldItem.nullMap := Nullbit - 1;
        FieldItem.is_nullable := (statusCode and $80) = 0;
        FieldItem.leaf_pos := DataOffset;
      end;
    end;
  end
  else
  begin
    //ֱ���޸ı�alter table xxx xxx xxx xx;
    TableItem := FLogSource.Fdbc.dict.tables.GetItemByPartitionId(rowsetid);
    if (TableItem <> nil) and (ColId < 65535) then
    begin
      rsC := TDDL_RsCols.Create;
      rsC.rowsetid := rowsetid;
      rsC.ColId := ColId;
      rsC.statusCode := statusCode;
      rsC.DataOffset := DataOffset;
      rsC.Nullbit := Nullbit;
      rsC.TableObj := TableItem;
      Rscols.Add(rsC);
    end else begin
      //���Ե�partition
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg(DataRow: Tsql2014Opt);
var
  rowsetid: int64;
  ObjId: Integer;
  idminor:Integer;
  I:Integer;
  cTable :TDDL_Create_Table;
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
    idminor := StrToInt64(DataRow.new_data.getFieldStrValue('idminor'));
    if idminor <= 1 then  //Composite ID
    begin
      rowsetid := StrToInt64(DataRow.new_data.getFieldStrValue('rowsetid'));
      ObjId := StrToInt(DataRow.new_data.getFieldStrValue('idmajor'));
      AllocUnitMgr.Add(rowsetid, ObjId);

      for I := 0 to DDL.FItems.Count -1 do
      begin
        if DDL.FItems[i] is TDDL_Create_Table then
        begin
          cTable := TDDL_Create_Table(DDL.FItems[I]);
          if cTable.TableObj.TableId=ObjId then
          begin
            cTable.TableObj.partition_id := rowsetid;
            Break;
          end;
        end;
      end;
    end;
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
  end else if DataRow.Table.TableNmae = 'sysidxstats' then
  begin
    //index ��Ϣ
    PriseDDLPkg_sysidxstats(DataRow);
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
  I:Integer;
  pdd: PdbFieldValue;
begin
  if TryStrToInt(DataRow.new_data.getFieldStrValue('id'), ObjId) then
  begin
    ddlitem := DDL.GetItem(ObjId);
    FieldItem := TdbFieldItem.Create;
    FieldItem.Col_id := StrToInt(DataRow.new_data.getFieldStrValue('colid'));
    FieldItem.ColName := DataRow.new_data.getFieldStrValue('name');
    FieldItem.type_id := StrToInt(DataRow.new_data.getFieldStrValue('xtype')) and $FF;
    FieldItem.Max_length := StrToInt(DataRow.new_data.getFieldStrValue('length'));
    FieldItem.procision := StrToInt(DataRow.new_data.getFieldStrValue('prec'));
    FieldItem.scale := StrToInt(DataRow.new_data.getFieldStrValue('scale'));
    FieldItem.is_nullable := (StrToInt(DataRow.new_data.getFieldStrValue('status')) and 1) = 0;
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


    for I := DataRow.new_data.fields.Count - 1 downto 0 do
    begin
      pdd := PdbFieldValue(DataRow.new_data.fields[I]);
      if LowerCase(pdd.field.ColName) = 'idtval' then
      begin
        FieldItem.Idt_seed := PDWORD(@pdd.value[0])^;
        FieldItem.Idt_increment := PDWORD(@pdd.value[4])^;
        Break;
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

procedure TSql2014logAnalyzer.PriseDDLPkg_sysidxstats(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  objId: Integer;
  idxName:string;
  status:integer;
  idxtype:integer;

  idxObj:TDDL_IDX_stats;
begin
  objId := 0;
  idxName := '';
  status := 0;
  idxtype := 0;
  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'id' then
    begin
      objId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'name' then
    begin
      idxName := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end else if pdd_field_ColName = 'status' then
    begin
      status := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'type' then
    begin
      idxtype := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;

  idxObj := TDDL_IDX_stats.Create;
  idxObj.tableId := objId;
  idxObj.idxName := idxName;
  idxObj.isUnique := (status and $8) > 0;
  idxObj.isCLUSTERED := idxtype = 1;
  IDXstats.Add(idxObj);
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
      objId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'idminor' then
    begin
      indexId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'status' then
    begin
      status := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end else if pdd_field_ColName = 'intprop' then
    begin
      fieldId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end;
  end;
  IDXs.Add(objId, indexId, fieldId, (status and 4) > 0);
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_sysobjvalues(DataRow: Tsql2014Opt);
var
  I: Integer;
  pdd: PdbFieldValue;
  pdd_field_ColName: string;
  valClass,objId: Integer;
  value: string;
  ddlitem: TDDLItem;
  DefObj: TDDL_Create_Def;
  chkObj :TDDL_Create_Check;
begin
  objId := 0;
  value := '';

  for I := 0 to DataRow.new_data.Fields.Count - 1 do
  begin
    pdd := PdbFieldValue(DataRow.new_data.Fields[I]);
    pdd_field_ColName := LowerCase(pdd.field.ColName);
    if pdd_field_ColName = 'valClass' then
    begin
      //1 default val
      valClass := SmallInt(pdd.value[0]);
    end else
    if pdd_field_ColName = 'objid' then
    begin
      objId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'imageval' then
    begin
      value := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end;
  end;

  ddlitem := DDL.GetItem(objId);
  if ddlitem=nil then
  begin
    //raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.1');
    //��������������
  end else begin
    if ddlitem.xType = 'd' then
    begin
      DefObj := TDDL_Create_Def(ddlitem);
      DefObj.value := hexToAnsiiData(value);
    end else if ddlitem.xType = 'c' then
    begin
      //check
      chkObj := TDDL_Create_Check(ddlitem);
      chkObj.value := hexToAnsiiData(value);
    end
    else if ddlitem.xType = 'u' then begin

    end else
    begin
      raise Exception.Create('Error Message:PriseDDLPkg_sysrscols.2');
    end;
  end;
end;

procedure TSql2014logAnalyzer.PriseDDLPkg_D_sysschobjs(DataRow: Tsql2014Opt);
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
  DefObj: TDDL_Delete_Constraint;
  DefObjkey : TDDL_Delete_Constraint_key;
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
      ObjId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ObjName := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'nsid' then
    begin
      nsid := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'type' then
    begin
      ObjType := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'pid' then
    begin
      pid := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
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
  end
  else if ObjType = 'v' then
  begin
    //todo:��ͼ

  end
  else if ObjType = 'p' then
  begin
    //todo:����


  end
  else if (ObjType = 'pk') or (ObjType = 'uq') then
  begin
    //primary key ,unique key
    DefObjkey := TDDL_Delete_Constraint_key.Create;
    DefObjkey.subType := ObjType;
    DefObjkey.objId := ObjId;
    DefObjkey.objName := ObjName;
    DefObjkey.tableid := pid;
    DDL.Add(DefObjkey);
  end
  else if (ObjType = 'd') or (ObjType = 'pk') or (ObjType = 'uq') or (ObjType = 'c') or (ObjType = 'fk') then
  begin
    //default   ,primary key   ,unique key    ,check   ,FOREIGN key
    DefObj := TDDL_Delete_Constraint.Create;
    DefObj.subType := ObjType;
    DefObj.objId := ObjId;
    DefObj.objName := ObjName;
    DefObj.tableid := pid;
    DDL.Add(DefObj);
  end
  else if ObjType = 'tr' then
  begin
  //todo:Trigger

  end
  else
  begin
  //δ֪����

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
  initprop: Integer; //��������Ǳ�ֵΪ���������������Ĭ��ֵΪ��id

  table: TDDL_Create_Table;
  DefObj: TDDL_Create_Def;
  pkObj:TDDL_Create_PrimaryKey;
  uqObj : TDDL_Create_UniqueKey;
  chkObj :TDDL_Create_Check;
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
      ObjId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'name' then
    begin
      ObjName := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'nsid' then
    begin
      nsid := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'type' then
    begin
      ObjType := Hvu.GetFieldStrValue(pdd.field, pdd.value);
    end
    else if pdd_field_ColName = 'pid' then
    begin
      pid := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'intprop' then
    begin
      initprop := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
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
    chkObj := TDDL_Create_Check.Create;
    chkObj.objId := ObjId;
    chkObj.objName := ObjName;
    chkObj.tableid := pid;
    DDL.Add(chkObj);
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
    //Unique key
    uqObj := TDDL_Create_UniqueKey.Create;
    uqObj.objId := ObjId;
    uqObj.objName := ObjName;
    uqObj.tableid := pid;
    DDL.Add(uqObj);
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
  FieldItem: TdbFieldItem;
  TableItem:TdbTableItem;
  ctable: TDDL_Create_Table;
  rsC:TDDL_RsCols;
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
      rowsetid := StrToInt64(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'rscolid' then
    begin
      ColId := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'status' then
    begin
      statusCode := StrToInt(Hvu.GetFieldStrValue(pdd.field, pdd.value));
    end
    else if pdd_field_ColName = 'offset' then
    begin
      DataOffset := Hvu.getShort(pdd.value, 0, 2);
    end
    else if pdd_field_ColName = 'nullbit' then
    begin
      Nullbit := Hvu.getShort(pdd.value, 0, 2);
    end;
  end;
  ObjId := AllocUnitMgr.GetObjId(rowsetid);
  if ObjId <> 0 then
  begin
    ddlitem := DDL.GetItem(ObjId);
    if (ddlitem <> nil) and (ddlitem.xType = 'u') then
    begin
      ctable := TDDL_Create_Table(ddlitem);
      FieldItem := ctable.TableObj.Fields.GetItemById(ColId);
      if FieldItem <> nil then
      begin
        FieldItem.nullMap := Nullbit - 1;
        FieldItem.is_nullable := (statusCode and $80) = 0;
        FieldItem.leaf_pos := DataOffset;
      end;
    end;
  end
  else
  begin
    //ֱ���޸ı�alter table xxx xxx xxx xx;
    TableItem := FLogSource.Fdbc.dict.tables.GetItemByPartitionId(rowsetid);
    if (TableItem <> nil) and (ColId < 65535) then
    begin
      rsC := TDDL_RsCols.Create;
      rsC.rowsetid := rowsetid;
      rsC.ColId := ColId;
      rsC.statusCode := statusCode;
      rsC.DataOffset := DataOffset;
      rsC.Nullbit := Nullbit;
      rsC.TableObj := TableItem;
      Rscols.Add(rsC);
    end else begin
      //���Ե�partition
    end;
  end;
end;

function TSql2014logAnalyzer.getDataFrom_TEXT_MIX(idx: TBytes): TBytes;
var
  MIXDATAPkg: PLogMIXDATAPkg;
begin
  MIXDATAPkg := @idx[0];
  //TODO:�������������(���ȿ���0x10��0x18.���8λ��pageid
  //0400000001000000 384E00005A1F0000 AC0D000001000000
  //000051C300000000 B500000001000000
  Result := getDataFrom_TEXT_MIX_DATA(PPage_Id(@idx[Length(idx) - 8])^);
end;

function TSql2014logAnalyzer.getDataFrom_TEXT_MIX_DATA(Page: TPage_Id): TBytes;
var
  I,J: Integer;
  DataRow :Tsql2014Opt;
  MPD:PMIX_Page_DATA;
  MPD_0:PMIX_Page_DATA_0;
  MPD_2:PMIX_Page_DATA_2;
  MPD_3:PMIX_Page_DATA_3;
  MPD_5:PMIX_Page_DATA_5;
  nsize:Cardinal;
  tmpData:TBytes;
begin
  for I := 0 to FRows.Count - 1 do
  begin
    DataRow := Tsql2014Opt(FRows[i]);
    if DataRow.isMixData and (DataRow.R0 <> nil) and (DataRow.page.FID = Page.FID) and (DataRow.page.PID = Page.PID) and (DataRow.page.solt = Page.solt) then
    begin
      MPD := PMIX_Page_DATA(DataRow.R0);
      if MPD.MixType = 0 then
      begin
        //С��0x40��ֵȫ���ں���,����0x40С��2x1F00��MixDataType = 5 ,����1F00�� MixDataType = 2
        MPD_0 := PMIX_Page_DATA_0(DataRow.R0);
        SetLength(Result, MPD_0.dataLen);
        Move(MPD_0.data[0], Result[0], MPD_0.dataLen);
      end
      else if MPD.MixType = 2 then
      begin
        //pageָ���б�
        //UNKNOWN(2){?0x01F5} +pagecount(4)+pageid(6)+slotID(2)
        MPD_2 := PMIX_Page_DATA_2(DataRow.R0);
        nsize := 0;
        for J := 0 to MPD_2.pageCount - 1 do
        begin
          tmpData := getDataFrom_TEXT_MIX_DATA(MPD_2.Idxs[J].Pageid);
          SetLength(Result, nsize + Length(tmpData));
          Move(tmpData[0], Result[nsize], Length(tmpData));
          nsize := nsize + Length(tmpData);
        end;
      end
      else if MPD.MixType = 3 then
      begin
        //���������ȫ��������
        MPD_3 := PMIX_Page_DATA_3(DataRow.R0);
        nsize := MPD_3.a.Recordlen - SizeOf(TMIX_Page_DATA);
        SetLength(Result, nsize);
        Move(MPD_3.data[0], Result[0], nsize);
      end
      else if MPD.MixType = 5 then
      begin
        //data ָ��
        //UNKNOWN(6)+dataversion(4)+dataLen(4)+pageid(6)+slotID(2)
        MPD_5 := PMIX_Page_DATA_5(DataRow.R0);
        Result := getDataFrom_TEXT_MIX_DATA(MPD_5.Pageid)
      end
      else
      begin
        FLogSource.Loger.Add('MIX_DATA:'+inttostr(MPD.MixType)+'>' + DumpMemory2Str(DataRow.R0, MPD.Recordlen), LOG_DATA or LOG_WARNING);
      end;
      Break;
    end;
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
  if (InsertRowFlag and $F) > 0 then
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
    raise Exception.Create('ʵ����������־��ƥ�䣡��������޸ı����ɵģ�����������');
  end;
  DataRow := Tsql2014RowData.Create;
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
          if val_len = 0 then
          begin
            //���ַ���
            New(fieldval);
            fieldval.field := aField;
            SetLength(fieldval.value,0);
            fieldval.StrValue := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
            DataRow.Fields.Add(fieldval);
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
                fieldval.value := BinReader.readBytes(val_len);
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
            fieldval.StrValue := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
            DataRow.Fields.Add(fieldval);
          end;
        end else begin
          //���ַ���
          New(fieldval);
          fieldval.field := aField;
          SetLength(fieldval.value,0);
          fieldval.StrValue := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
          DataRow.Fields.Add(fieldval);
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
        fieldval.StrValue := Hvu.GetFieldStrValue(fieldval.field, fieldval.value);
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
      LCX_HEAP,      //�ѱ�д��(û�оۺ������ı�
      LCX_CLUSTERED, //�ۺ�д��
      LCX_TEXT_TREE, LCX_TEXT_MIX://�зֿ����� image,text,ntext֮���
        begin
          if (Rldo.normalData.FlagBits and 1)>0 then
          begin
            //Rollback tran
            //COMPENSATION    �ָ�������Delete������
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //����֮ǰ������
                if DataRow.OperaType=Opt_Insert then
                begin
                  //insert�����ݡ�deleteȻ��ع�delete
                  DataRow.deleteFlag := False;

                  TmpCPnt :=  UIntPtr(Rldo)+ SizeOf(TRawLog_DataOpt) ;
                  TmpSize := PWord(TmpCPnt)^;
                  TmpCPnt := TmpCPnt + Rldo.NumElements*2;
                  TmpCPnt := (TmpCPnt + 3) and $FFFFFFFC;

                  //ֻ����һ����Ž�buf������
                  if DataRow.R0<>nil then
                    FreeMemory(DataRow.R0);
                  DataRow.R0 := GetMemory($2000);
                  Move(Pointer(TmpCPnt)^, DataRow.R0^, TmpSize);

                end else if DataRow.deleteFromUpdate then
                begin
                  DataRow.OperaType := Opt_Update;
                end else
                begin
                  FRows.Delete(i);
                  //DataRow.deleteFlag := True;
                end;

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
            //һ���� 3 ������ (������N����
            //1��n-2. ��ʵд�������
            //n-1. 0 �ۺ�������Ϣ������Insert��־����ֵ����null
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

            DataRow := Tsql2014Opt.Create;
            DataRow.OperaType := Opt_Insert;
            DataRow.page := Rldo.pageId;
            DataRow.table := DbTable;
            DataRow.R0 := GetMemory($2000);
            Move(Pointer(UIntPtr(Rldo)+R_Info[0].Offset)^, DataRow.R0^, R_Info[0].Length);
            if Rldo.normalData.ContextCode in [LCX_TEXT_TREE, LCX_TEXT_MIX] then
            begin
              DataRow.isMixData := True;
            end;
            FRows.Add(DataRow);
          end;
        end;
      LCX_INDEX_LEAF: //����д��
        begin
          //�ⶫ��Ӧ�ÿ��Ժ��԰ɣ�����
        end;
    else
      FLogSource.Loger.Add('PriseRowLog_Insert ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
    end;
  finally
    if BinReader <> nil then
      BinReader.Free;
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
            //COMPENSATION    ɾ��������insert������
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //����֮ǰ������
                FRows.Delete(i);
                Break;
              end
            end;
          end else begin
            //ɾ��ǰ���Ȳ�����֮ǰ��û�жԱ������ݵĲ�����insert��Update������ȡ��֮ǰ����
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow := Tsql2014Opt(FRows[i]);
              if (DataRow.page.PID = Rldo.pageId.PID) and
                (DataRow.page.FID = Rldo.pageId.FID) and
                (DataRow.page.solt = Rldo.pageId.solt) then
              begin
                //����֮ǰ������
                if DataRow.OperaType = Opt_Insert then
                begin
//                  if DataRow.deleteFlag then
//                    continue;
                  DataRow.deleteFlag := True;
                  //ͬһ����������insertȻ����delete(
                  Exit;
                end else begin
                  //ͬһ����������updateȻ����delete(

                  //�������ʱ��
                  DataRow.deleteFromUpdate := True;     //�����ɾ���ع������ڻ�ԭ֮ǰ��Update״̬
                  DataRow.OperaType := Opt_Delete;
                  //�滻R0
                  TmpCPnt :=  UIntPtr(Rldo)+ SizeOf(TRawLog_DataOpt) ;
                  TmpSize := PWord(TmpCPnt)^;
                  TmpCPnt := TmpCPnt + Rldo.NumElements*2;
                  TmpCPnt := (TmpCPnt + 3) and $FFFFFFFC;

                  //ֻ����һ����Ž�buf������
                  if DataRow.R0<>nil then
                    FreeMemory(DataRow.R0);
                  DataRow.R0 := GetMemory($2000);
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
            DataRow := Tsql2014Opt.Create;
            DataRow.OperaType := Opt_Delete;
            DataRow.page := Rldo.pageId;
            DataRow.table := DbTable;
            DataRow.R0 := GetMemory($2000);
            Move(Pointer(UIntPtr(Rldo)+R_Info[0].Offset)^, DataRow.R0^, R_Info[0].Length);
            if (Pbyte(DataRow.R0)^ and $F) > 0 then
            begin
              //not primary record
              DataRow.free;
            end else
              FRows.Add(DataRow);
          end;
        end;
      LCX_TEXT_MIX:
        begin
        //���Ժ��Եġ�ɾ�������ݵ�ʱ��������Զ�ɾ����
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
          //Ч�������ֶ�����
          if fieldCnt <> DbTable.UniqueClusteredKeys.Count then
          begin
          //���������ݣ�����
            Exit;
          end;
          //nullmap
          BinReader.skip((fieldCnt + 7) shr 3);
          if (flag and $20) = 0 then
          begin
            // ?? ������var�ֶ� ֵ
            Exit;
          end;
          //var �ֶ�����
          fieldCnt := BinReader.readWord;
          SetLength(varFxIdx, fieldCnt);
          tmpCardinal := BinReader.getRangePosition + fieldCnt * 2;
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
        Hvu.GetFieldStrValueWithQuoteIfNeed(fieldval.field, fieldval.value)]);
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
  //�ع�һ���޸�
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else begin
    if size_old < size_new then
    begin
      //���ݺ���
      tmpLen := datarowCnt - offset;
      if tmpLen > 0 then
      begin
        tmpdata := AllocMem(tmpLen);
        Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
        Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_new - size_old))^, tmpLen);
        FreeMem(tmpdata);
      end;
      Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
    end else begin
      //ǰ��
      tmpLen := datarowCnt - offset;
      tmpdata := AllocMem(tmpLen);
      Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
      Move(Pointer(uintptr(tmpdata) + (size_old - size_new))^, Pointer(uintptr(srcData) + offset)^, tmpLen - (size_old - size_new));
      Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
      FreeMem(tmpdata);
    end;
    if Pbyte(srcData)^ = $0008 then
    begin
      //mix data
      tmpLen := datarowCnt + size_new - size_old;
      PWord(uintptr(srcData) + 2)^ := tmpLen;
    end;
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
  Rawssssss:TTransPkgItem;
begin
  BinReader := nil;
  DataRow_buf := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_HEAP, //�ѱ�д��
      LCX_CLUSTERED, //�ۺ�д��
      LCX_TEXT_TREE, LCX_TEXT_MIX:
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
          //һ���� 6 ������
          //0, ������
          //1. ������
          //2. �ۺ�������Ϣ
          //3. ����Ϣ
          //4. 0
          //5. 0
          if (Rldo.normalData.FlagBits and 1) > 0 then
          begin
            //COMPENSATION
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //�ҵ�ҳ������ҳ����
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
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //�ҵ�ҳ������ҳ����
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
                  //��϶���ɾ��������Ȼ���ֻع��˵ģ�R0�а����˵�ǰ�е���������
                  DataRow_buf.OperaType := Opt_Update;
                  DataRow_buf.deleteFlag := False;
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                  //ˢ��Ψһ�ۺϣ�Ψһ�ۺ��ǲ��ᱻupdate�ģ�������Update�ۺ�=delete+insert
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
              //���Եı�
              Exit;
            end;

            DataRow_buf := Tsql2014Opt.Create;
            try
              if (DbTable.UniqueClusteredKeys.Count>0) and (R_Info[2].Length > 0) then
              begin
                //��ȡUniqueClusteredKeys
                BinReader.SetRange(R_Info[2].Offset, R_Info[2].Length);
                DataRow_buf.UniqueClusteredKeys := PriseRowLog_UniqueClusteredKeys(BinReader, DbTable);
              end;

              if FLogSource.FFFFIsDebug then
              begin
                for I := 0 to FLogSource.pageDatalist.Count-1 do
                begin
                  Rawssssss := TTransPkgItem(FLogSource.pageDatalist[i]);
                  if (Rawssssss.LSN.LSN_1=tPkg.LSN.LSN_1) and (Rawssssss.LSN.LSN_2=tPkg.LSN.LSN_2) and (Rawssssss.LSN.LSN_3=tPkg.LSN.LSN_3) then
                  begin
                    SetLength(OriginRowData,Rawssssss.Raw.dataSize);
                    CopyMemory(@OriginRowData[0], Rawssssss.Raw.data, Rawssssss.Raw.dataSize);
                  end;
                end;
              end else
              OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
              if OriginRowData = nil then
              begin
                FLogSource.Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
                if (DataRow_buf.UniqueClusteredKeys = '') or (DbTable.Owner='sys') then   //sys�����û��selectȨ�ޣ�����ֱ�Ӷ�page
                begin
                  FLogSource.Loger.Add('��[%s]û��Ψһ�ۺ�,�Դ˱��Update�����������ԣ�������ϣ��Update�����ԣ����������ݿ���.',[DbTable.getFullName]);
                  DataRow_buf.Free;
                  Exit;
                  //TODO:�������ף����ܱ�֤page�����뵱ǰlsn֮���������Щ�仯
                  //���û�оۺ���������dbcc page��ȡԭʼ������
                  {
                  OriginRowData := getUpdateSoltFromDbccPage(FLogSource.Fdbc, Rldo.pageId);
                  if OriginRowData = nil then
                  begin
                    //�����ѱ�ɾ��������������
                    Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�'+lsn2str(tPkg.LSN), LOG_ERROR or LOG_IMPORTANT);
                    DataRow_buf.Free;
                    Exit;
                  end;
                  }
                  DataRow_buf.UnReliableRData := true;
                end else begin
                  //���û��OriginRowData������ UniqueClusteredKeys�����ͨ��ֱ�Ӳ�ѯ�������ݷ�װ
                end
              end;

              DataRow_buf.OperaType := Opt_Update;
              DataRow_buf.page := Rldo.pageId;
              DataRow_buf.table := DbTable;
              if OriginRowData <> nil then
              begin
                //before
                tmpdata := GetMemory($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                RawDataLen := PageRowCalcLength(tmpdata);
                applyChange(tmpdata, R_[0], Rldo.OffsetInRow, R_Info[1].Length, R_Info[0].Length, RawDataLen);
                DataRow_buf.R1 := tmpdata;
                //after
                tmpdata := GetMemory($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                DataRow_buf.R0 := tmpdata;
              end;
              if Rldo.normalData.ContextCode in [LCX_TEXT_TREE, LCX_TEXT_MIX] then
              begin
                DataRow_buf.isMixData := True;
              end;
              FRows.Add(DataRow_buf);
            except
              DataRow_buf.Free;
            end;
            SetLength(OriginRowData, 0);
          end;
        end;
    else
      FLogSource.Loger.Add('PriseRowLog_MODIFY_ROW ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
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
  else if size_old < size_new then
  begin
    //���ݺ���
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(tmpdata^, Pointer(uintptr(srcData) + offset + (size_new - size_old))^, tmpLen);
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
    FreeMem(tmpdata);
  end else begin
    //ǰ��
    tmpLen := datarowCnt - offset;
    tmpdata := AllocMem(tmpLen);
    Move(Pointer(uintptr(srcData) + offset)^, tmpdata^, tmpLen);
    Move(Pointer(uintptr(tmpdata) + (size_old - size_new))^, Pointer(uintptr(srcData) + offset)^, tmpLen - (size_old - size_new));
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_new);
    FreeMem(tmpdata);
  end;
end;

var
  Rldo: PRawLog_DataOpt;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  BinReader: TbinDataReader;
  I, J:Integer;
  OriginRowData:TBytes;
  OffsetInRow:Word;
  TableId: Integer;
  DbTable: TdbTableItem;
  DataRow_buf: Tsql2014Opt;
  tmpdata:Pointer;
  RawDataLen:Integer;
  tmpLen:Word;
  Rawssssss :TTransPkgItem;
begin
  BinReader := nil;
  Rldo := tPkg.Raw.data;
  try
    case Rldo.normalData.ContextCode of
      LCX_HEAP, //�ѱ�д��
      LCX_CLUSTERED, //�ۺ�д��
      LCX_TEXT_TREE, LCX_TEXT_MIX:
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

          if (Rldo.normalData.FlagBits and 1) > 0 then
          begin
            //COMPENSATION
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //�ҵ�ҳ������ҳ����
                if DataRow_buf.OperaType = Opt_Update then
                begin
                  if (DataRow_buf.R0<>nil) and (not DataRow_buf.UnReliableRData) then
                  begin
                    RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                    for J := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                    begin
                      OffsetInRow := Pword(UIntPtr(R_[0]) + J*4)^;
                      tmpLen := Pword(UIntPtr(R_[1]) + J*2)^;
                      applyChange(DataRow_buf.R0, R_[4 + J * 2 + 1], OffsetInRow,
                         tmpLen, R_Info[4 + J * 2 + 1].Length,RawDataLen);
                      RawDataLen := RawDataLen + (R_Info[4 + J * 2 + 1].Length - tmpLen);
                    end;
                  end;
                end else if DataRow_buf.OperaType=Opt_Insert then
                begin
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  for J := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                  begin
                    OffsetInRow := Pword(UIntPtr(R_[0]) + J*4)^;
                    tmpLen := Pword(UIntPtr(R_[1]) + J*2)^;
                    applyChange(DataRow_buf.R0, R_[4 + J * 2 + 1], OffsetInRow,
                       tmpLen, R_Info[4 + J * 2 + 1].Length,RawDataLen);
                    RawDataLen := RawDataLen + (R_Info[4 + J * 2 + 1].Length - tmpLen);
                  end;
//                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
//                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                end;
                Break;
              end
            end;
          end else begin
            for I := FRows.Count - 1 downto 0 do
            begin
              DataRow_buf := Tsql2014Opt(FRows[i]);
              if (DataRow_buf.page.PID = Rldo.pageId.PID) and
                (DataRow_buf.page.FID = Rldo.pageId.FID) and
                (DataRow_buf.page.solt = Rldo.pageId.solt) then
              begin
                //�ҵ�ҳ������ҳ����
                if DataRow_buf.OperaType = Opt_Update then
                begin
                  if (DataRow_buf.R0<>nil) and (not DataRow_buf.UnReliableRData) then
                  begin
                    RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                    for J := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                    begin
                      OffsetInRow := Pword(UIntPtr(R_[0]) + J*4 + 2)^;
                      applyChange(DataRow_buf.R0, R_[4 + J * 2 + 1], OffsetInRow,
                        R_Info[4 + J * 2].Length, R_Info[4 + J * 2 + 1].Length, RawDataLen);
                        RawDataLen := RawDataLen + (R_Info[4 + J * 2 + 1].Length - R_Info[4 + J * 2].Length);
                    end;
                  //applyChangeAll(DataRow_buf.R0);
//                    RawDataLen := PageRowCalcLength(DataRow_buf.R0);
//                    applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, Rldo.ModifySize, R_Info[1].Length, RawDataLen);
                  end;
                end else if DataRow_buf.OperaType=Opt_Insert then
                begin
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  for J := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                  begin
                    OffsetInRow := Pword(UIntPtr(R_[0]) + J*4 + 2)^;
                    applyChange(DataRow_buf.R0, R_[4 + J * 2 + 1], OffsetInRow,
                      R_Info[4 + J * 2].Length, R_Info[4 + J * 2 + 1].Length, RawDataLen);
                    RawDataLen := RawDataLen + (R_Info[4 + J * 2 + 1].Length - R_Info[4 + J * 2].Length);
                  end;
//                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
//                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                end else  if DataRow_buf.OperaType=Opt_Delete then
                begin
                  //��϶���ɾ��������Ȼ���ֻع��˵ģ�R0�а����˵�ǰ�е���������
                  DataRow_buf.OperaType := Opt_Update;
                  DataRow_buf.deleteFlag := False;
                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
                  for J := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                  begin
                    OffsetInRow := Pword(UIntPtr(R_[0]) + J*4 + 2)^;
                    applyChange(DataRow_buf.R0, R_[4 + J * 2 + 1], OffsetInRow,
                      R_Info[4 + J * 2].Length, R_Info[4 + J * 2 + 1].Length, RawDataLen);
                    RawDataLen := RawDataLen + (R_Info[4 + J * 2 + 1].Length - R_Info[4 + J * 2].Length);
                  end;
//                  RawDataLen := PageRowCalcLength(DataRow_buf.R0);
//                  applyChange(DataRow_buf.R0, R_[1], Rldo.OffsetInRow, R_Info[0].Length, R_Info[1].Length, RawDataLen);
                  //ˢ��Ψһ�ۺϣ�Ψһ�ۺ��ǲ��ᱻupdate�ģ�������Update�ۺ�=delete+insert
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
              //���Եı�
              Exit;
            end;
            DataRow_buf := Tsql2014Opt.Create;
            try
              if (DbTable.UniqueClusteredKeys.Count>0) and (R_Info[2].Length > 0) then
              begin
                //��ȡUniqueClusteredKeys
                BinReader.SetRange(R_Info[2].Offset, R_Info[2].Length);
                DataRow_buf.UniqueClusteredKeys := PriseRowLog_UniqueClusteredKeys(BinReader, DbTable);
              end;
              if FLogSource.FFFFIsDebug then
              begin
                for I := 0 to FLogSource.pageDatalist.Count-1 do
                begin
                  Rawssssss := TTransPkgItem(FLogSource.pageDatalist[I]);
                  if (Rawssssss.LSN.LSN_1 = tPkg.LSN.LSN_1) and (Rawssssss.LSN.LSN_2 = tPkg.LSN.LSN_2) and (Rawssssss.LSN.LSN_3 = tPkg.LSN.LSN_3) then
                  begin
                    SetLength(OriginRowData, Rawssssss.Raw.dataSize);
                    CopyMemory(@OriginRowData[0], Rawssssss.Raw.data, Rawssssss.Raw.dataSize);
                  end;
                end;
              end else
              OriginRowData := getUpdateSoltData(FLogSource.Fdbc, Rldo.normalData.PreviousLSN);
              if OriginRowData = nil then
              begin
                FLogSource.Loger.Add('��ȡ��ԭʼ����ʧ�ܣ�' + lsn2str(tPkg.LSN) + ',pLSN:' + lsn2str(Rldo.normalData.PreviousLSN), LOG_WARNING or LOG_IMPORTANT);
                if (DataRow_buf.UniqueClusteredKeys = '') or (DbTable.Owner='sys') then   //sys�����û��selectȨ�ޣ�����ֱ�Ӷ�page
                begin
                  FLogSource.Loger.Add('��[%s]û��Ψһ�ۺ�,�Դ˱��Update�����������ԣ�������ϣ��Update�����ԣ����������ݿ���.',[DbTable.getFullName]);
                  DataRow_buf.Free;
                  Exit;
                end else begin
                  //���û��OriginRowData������ UniqueClusteredKeys�����ͨ��ֱ�Ӳ�ѯ�������ݷ�װ
                end
              end;

              //OriginRowData ���޸ĺ��������
              DataRow_buf.OperaType := Opt_Update;
              DataRow_buf.page := Rldo.pageId;
              DataRow_buf.table := DbTable;
              if OriginRowData <> nil then
              begin
                //after
                tmpdata := GetMemory($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                DataRow_buf.R0 := tmpdata;

                //before���ع����޸�֮ǰ��״̬
                tmpdata := GetMemory($2000);
                Move(OriginRowData[0], tmpdata^, Length(OriginRowData));
                RawDataLen := PageRowCalcLength(tmpdata);
                for I := 0 to ((Rldo.NumElements - 4) div 2) - 1 do
                begin
                  OffsetInRow := Pword(UIntPtr(R_[0]) + i*4)^;
                  applyChange(tmpdata, R_[4 + I * 2], OffsetInRow,
                    R_Info[4 + I * 2 + 1].Length, R_Info[4 + I * 2].Length,  RawDataLen);
                  RawDataLen := RawDataLen + (R_Info[4 + I * 2].Length - R_Info[4 + I * 2 + 1].Length);
                end;

//                applyChange(tmpdata, R_[0], Rldo.OffsetInRow, R_Info[1].Length, R_Info[0].Length, RawDataLen);
                DataRow_buf.R1 := tmpdata;
              end;

              FRows.Add(DataRow_buf);
            except
              DataRow_buf.Free;
            end;
          end;
        end;
    else
      FLogSource.Loger.Add('PriseRowLog_MODIFY_COLUMNS ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
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
      TransBeginTime := Hvu.Hex2Datetime(Rlbx.Time);
      TransId := Rlbx.normalData.TransID;
    end
    else if Rl.OpCode = LOP_COMMIT_XACT then
    begin
      Rlcx := tPkg.Raw.data;
      TransCommitLsn := tPkg.LSN;
      TransCommitTime := Hvu.Hex2Datetime(Rlcx.Time);
    end
    else
    begin

    end
  except
    on E: Exception do
    begin
      FLogSource.Loger.Add(E.Message + '-->LSN:' + lsn2str(tPkg.LSN), LOG_ERROR);
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
  //û�е��ֶ�Ĭ��null
  Result := 'NULL';
  FieldName := LowerCase(FieldName);
  for I := 0 to fields.Count - 1 do
  begin
    pdd := PdbFieldValue(fields[I]);
    if LowerCase(pdd.field.ColName) = FieldName then
    begin
      Result := pdd.StrValue;
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

procedure TMIX_DATAs.add(idx: QWORD; pageid: TPage_Id; data: TBytes);
var
  item :TMIX_DATA_Item;
begin
  item := TMIX_DATA_Item.Create;
  item.Idx := idx;
  item.pageid := pageid;
  item.data := data;
  FItems.Add(item);
end;

constructor TMIX_DATAs.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TMIX_DATAs.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TMIX_DATAs.GetItem_Idx(Key: Qword): TMIX_DATA_Item;
var
  I: Integer;
  item: TMIX_DATA_Item;
begin
  Result := nil;
  for I := 0 to FItems.Count - 1 do
  begin
    item := TMIX_DATA_Item(FItems[I]);
    if item.Idx = Key then
    begin
      Result := item;
    end;
  end;
end;

function TMIX_DATAs.GetItem_Pageid(pageid: TPage_Id): TMIX_DATA_Item;
var
  I: Integer;
  item: TMIX_DATA_Item;
begin
  Result := nil;
  for I := 0 to FItems.Count - 1 do
  begin
    item := TMIX_DATA_Item(FItems[I]);
    if (item.pageid.PID = pageid.PID) and (item.pageid.FID = pageid.FID) and (item.pageid.solt = pageid.solt) then
    begin
      Result := item;
    end;
  end;
end;

{ TsqlRawBuf }

constructor Tsql2014Opt.Create;
begin
  R0 := nil;
  R1 := nil;
  UnReliableRData := False;
  old_data := nil;
  new_data := nil;

  deleteFromUpdate := False;
  isMixData := False;
end;

destructor Tsql2014Opt.Destroy;
begin
  if R0<>nil then
    FreeMemory(R0);

  if R1<>nil then
    FreeMemory(R1);

  if old_data<>nil then
     old_data.Free;
  if new_data<>nil then
     new_data.Free;

  inherited;
end;

end.

