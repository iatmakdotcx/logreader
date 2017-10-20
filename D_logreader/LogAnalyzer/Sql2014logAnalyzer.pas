unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, LogSource, dbDict, System.SysUtils,
  Contnrs, BinDataUtils;

type
  TOperationType = (Opt_Insert, Opt_Update, Opt_Delete);

type
  Tsql2014RowData = class(TObject)
    OperaType: TOperationType;
    Fields: TList;
    Table: TdbTableItem;
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

  TDDLItem = class(TObject)
    xType: string; //v,u,s,d
    function getObjId: Integer; virtual; abstract;
  end;

  TDDL_Create_Table = class(TDDLItem)
    TableObj: TdbTableItem;
  public
    constructor Create;
    destructor Destroy; override;
    function getObjId: Integer; override;
  end;

  TDDL_Create_View = class(TDDLItem)
  //TODO:TDDL_Create_View
  end;

  TDDL_Create_Procedure = class(TDDLItem)
  //TODO:TDDL_Create_View
  end;

  TDDL_Create_Def = class(TDDLItem)
    objId: Integer;
    objName: string;
    tableid: Integer;
    colid: Integer;
    value: string;
    constructor Create;
    function getObjId: Integer; override;
  end;

  TDDLMgr = class(TObject)
    FItems_id: TList;
    FItems: TObjectList;
  public
    function GetItem(ObjId: Integer): TDDLItem;
    procedure Add(obj: TDDLItem);
    constructor Create;
    destructor Destroy; override;
  end;

  TAllocUnitMgr = class(TObject)
  private
    type
      TAllocUnitMgrItrem = class(TObject)
        AllocId: Int64;
        ObjId: Integer;
      end;
    var
      FItems: TObjectList;
  public
    function AllocIdExists(AllocId: Int64): Boolean;
    function GetObjId(AllocId: Int64): Integer;
    procedure Add(AllocId: Int64; ObjId: Integer);
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
    function getDataFrom_TEXT_MIX(idx: TBytes; tPkg: TTransPkgItem): TBytes;
    function BuilderSql_Insert(aRowData: Tsql2014RowData): string;
    function BuilderSql(aRowData: Tsql2014RowData): string;
    function Read_LCX_TEXT_MIX_DATA(tPkg: TTransPkgItem; BinReader: TbinDataReader): TBytes;
    procedure PriseDDLPkg(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysrscols(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysschobjs(DataRow: Tsql2014RowData);
    procedure PriseDDLPkg_sysobjvalues(DataRow: Tsql2014RowData);
  public
    constructor Create(LogSource: TLogSource; Transpkg: TTransPkg);
    destructor Destroy; override;
    procedure Execute; override;
  end;

implementation

uses
  pluginlog, plugins, OpCode, hexValUtils, contextCode, dbFieldTypes,
  Memory_Common;

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

function TSql2014logAnalyzer.BuilderSql(aRowData: Tsql2014RowData): string;
begin
  case aRowData.OperaType of
    Opt_Insert:
      Result := BuilderSql_Insert(aRowData);
    Opt_Update:
      ;
    Opt_Delete:
      ;
  else
    Loger.Add('��δ���x��SQLBuilder');
  end;
end;

function TSql2014logAnalyzer.BuilderSql_Insert(aRowData: Tsql2014RowData): string;
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

procedure TSql2014logAnalyzer.Execute;
var
  mm: TMemory_data;
  I: Integer;
  TTpi: TTransPkgItem;
  DataRow: Tsql2014RowData;
begin
  Loger.Add('TSql2014logAnalyzer.Execute ==> ' + TranId2Str(FTranspkg.Ftransid));
  //֪ͨ���
  serializeToBin(mm);
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
    DataRow := Tsql2014RowData(FRows[I]);
    if DataRow.Table.Owner = 'sys' then
    begin
      //�����������ϵͳ������ddl���
      PriseDDLPkg(DataRow);
    end
    else
    begin
      // dml ���


    end;

  end;
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
    //������,�洢���̡���ͼ ��Ĭ��ֵ�ȶ���
    PriseDDLPkg_sysschobjs(DataRow);
  end
  else if DataRow.Table.TableNmae = 'syscolpars' then
  begin
    if TryStrToInt(DataRow.getFieldStrValue('id'), ObjId) then
    begin
      ddlitem := DDL.GetItem(ObjId);
      if (ddlitem <> nil) and (ddlitem.xType = 'u') then
      begin
        //������ֶ�
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
    //Ĭ��ֵ����ֵ
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
  ;
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
  else if ObjType = 'd' then
  begin
    //Ĭ��ֵ
    DefObj := TDDL_Create_Def.Create;
    DefObj.objId := ObjId;
    DefObj.objName := ObjName;
    DefObj.tableid := pid;
    DefObj.colid := initprop;
    DDL.Add(DefObj);
  end
  else if ObjType = 'p' then
  begin
    //����


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
      FieldItem.is_nullable := (statusCode and $80) > 0;
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

function TSql2014logAnalyzer.getDataFrom_TEXT_MIX(idx: TBytes; tPkg: TTransPkgItem): TBytes;
var
  MIXDATAPkg: PLogMIXDATAPkg;
  MixItem: TMIX_DATA_Item;
begin
  MIXDATAPkg := @idx[0];
  MixItem := MIX_DATAs.GetItem(MIXDATAPkg.key);
  if MixItem = nil then
  begin
    Loger.Add('TSql2014logAnalyzer.getDataFrom_TEXT_MIX fail!Lsn:%s,Idx:%s', [LSN2Str(tPkg.LSN), bytestostr_singleHex(idx)], LOG_ERROR);
    Result := nil;
  end
  else
  begin
    Result := MixItem.data;
  end;
end;

procedure TSql2014logAnalyzer.PriseRowLog_Insert(tPkg: TTransPkgItem);
type
  TRawElement = packed record
    Offset: Cardinal;
    Length: Word;
  end;
var
  Rldo: PRawLog_DataOpt;
  R_: array of TBytes;
  R_Info: array of TRawElement;
  I: Integer;
  BinReader: TbinDataReader;
  TableId: Integer;
  DbTable: TdbTableItem;
  nullMap: TBytes;
  TmpInt: Integer;
  Idx, b: Integer;
  //
  InsertRowFlag: Word;
  ColCnt: Word;
  VarFieldValEndOffset: array of Word;
  VarFieldValBase: Cardinal;  //var �ֶ�ֵ��ʼλ��
  val_begin, val_len: Cardinal;
  aField: TdbFieldItem;
  fieldval: PdbFieldValue;
  boolbit: Integer;
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
            //һ���� 3 ������
            //1. ��ʵд�������
            //2. 0 ���ȣ�
            //3. ����Ϣ
            BinReader.SetRange(R_Info[2].Offset, R_Info[2].Length);
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
            InsertRowFlag := BinReader.readWord;
            //DONE: ����Ӧ��Ч��InsertRowFlag������
            TmpInt := BinReader.readWord; //�������� Offset
            BinReader.seek(TmpInt, soBeginning);
            ColCnt := BinReader.readWord;
            if ColCnt <> DbTable.Fields.Count then
            begin
              Loger.Add('ʵ����������־��ƥ�䣡��������޸ı����ɵģ�����������LSN��' + LSN2Str(tPkg.LSN));
              exit;
            end;
            DataRow := Tsql2014RowData.Create;
            DataRow.Table := DbTable;
            if (InsertRowFlag and $10) > 0 then
            begin
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
                          fieldval.value := getDataFrom_TEXT_MIX(fieldval.value, tPkg);
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
          end;
        LCX_INDEX_LEAF: //����д��
          begin
            //�ⶫ��Ӧ�ÿ��Ժ��԰ɣ�����
          end;
        LCX_TEXT_MIX: //�зֿ�����
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
        FRows.Add(DataRow);
        Loger.Add(BuilderSql(DataRow));
      end;
    except
      on eexx: Exception do
      begin
        Loger.Add(eexx.Message + '-->LSN:' + lsn2str(tPkg.LSN), LOG_ERROR);
        if DataRow <> nil then
          DataRow.Free;
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

procedure TSql2014logAnalyzer.PriseRowLog(tPkg: TTransPkgItem);
var
  Rl: PRawLog;
  Rlbx: PRawLog_BEGIN_XACT;
  Rlcx: PRawLog_COMMIT_XACT;
begin
  Rl := tPkg.Raw.data;

  if Rl.OpCode = LOP_INSERT_ROWS then //����
  begin
    PriseRowLog_Insert(tPkg);
  end
  else if Rl.OpCode = LOP_DELETE_ROWS then  //ɾ��
  begin

  end
  else if Rl.OpCode = LOP_MODIFY_ROW then  //�޸ĵ�����
  begin

  end
  else if Rl.OpCode = LOP_MODIFY_COLUMNS then  //�޸Ķ����
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

end;

procedure TSql2014logAnalyzer.serializeToBin(var mm: TMemory_data);
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
  Move(FTranspkg.Items.Count, Pointer(Integer(mm.data) + datatOffset)^, 2);
  datatOffset := datatOffset + 2;
  for I := 0 to FTranspkg.Items.Count - 1 do
  begin
    //65536����Сһ��������ǹ��ˣ������image���Ϳ��ܻᳬ���˴�С ���������ֱ�Ӷ����Dword��С ������ļ�����4GB������ͺǺ�����

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
  //TODO:�˷�ʽЧ�ʵͣ�Ӧ���ڴ�����ֱ��ѭ��ȡֵ
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

{ TDDL_Create_Table }

constructor TDDL_Create_Table.Create;
begin
  TableObj := TdbTableItem.Create;
  xType := 'u';
end;

destructor TDDL_Create_Table.Destroy;
begin
  TableObj.Free;
  inherited;
end;

function TDDL_Create_Table.getObjId: Integer;
begin
  Result := TableObj.TableId;
end;

{ TDDLMgr }

procedure TDDLMgr.Add(obj: TDDLItem);
begin
  FItems.Add(obj);
  FItems_id.Add(Pointer(obj.getObjId));
end;

constructor TDDLMgr.Create;
begin
  FItems := TObjectList.Create;
  FItems_id := TList.Create;
end;

destructor TDDLMgr.Destroy;
begin
  FItems.Free;
  FItems_id.Free;
  inherited;
end;

function TDDLMgr.GetItem(ObjId: Integer): TDDLItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FItems_id.Count - 1 do
  begin
    if Integer(FItems_id[I]) = ObjId then
    begin
      Result := TDDLItem(FItems[I]);
      Exit;
    end;
  end;
end;

{ TAllocUnitMgr }

procedure TAllocUnitMgr.Add(AllocId: Int64; ObjId: Integer);
var
  NewItem: TAllocUnitMgrItrem;
begin
  if not AllocIdExists(AllocId) then
  begin
    NewItem := TAllocUnitMgrItrem.Create;
    NewItem.AllocId := AllocId;
    NewItem.ObjId := ObjId;
    FItems.Add(NewItem);
  end;
end;

function TAllocUnitMgr.AllocIdExists(AllocId: Int64): Boolean;
begin
  Result := GetObjId(AllocId) <> 0;
end;

constructor TAllocUnitMgr.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TAllocUnitMgr.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TAllocUnitMgr.GetObjId(AllocId: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if TAllocUnitMgrItrem(FItems[I]).AllocId = AllocId then
    begin
      Result := TAllocUnitMgrItrem(FItems[I]).ObjId;
      Exit;
    end;
  end;
  Result := 0;
end;

{ TDDL_Create_Def }

constructor TDDL_Create_Def.Create;
begin
  xType := 'd';
end;

function TDDL_Create_Def.getObjId: Integer;
begin
  Result := ObjId;
end;

end.

