unit Sql2014logAnalyzer;

interface

uses
  Classes, I_logAnalyzer, LogtransPkg, p_structDefine, Contnrs, LogSource,
  dbDict, System.SysUtils;

type
  Tsql2014RowData = class(TObject)
    Fields: TList;
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
    procedure serializeToBin(var mm: TMemory_data);
    procedure PriseRowLog(tPkg: TTransPkgItem);
    procedure PriseRowLog_Insert(tPkg: TTransPkgItem);
    function getDataFrom_TEXT_MIX(idx: TBytes; tPkg: TTransPkgItem): TBytes;
  public
    constructor Create(LogSource: TLogSource; Transpkg: TTransPkg);
    destructor Destroy; override;
    procedure Execute; override;
  end;

implementation

uses
  pluginlog, plugins, OpCode, hexValUtils, contextCode, BinDataUtils,
  dbFieldTypes;

{ TSql2014logAnalyzer }

constructor TSql2014logAnalyzer.Create(LogSource: TLogSource; Transpkg: TTransPkg);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FTranspkg := Transpkg;
  FLogSource := LogSource;
  FRows := TObjectList.Create;
end;

destructor TSql2014logAnalyzer.Destroy;
begin
  FTranspkg.Free;
  FRows.Free;
  inherited;
end;

procedure TSql2014logAnalyzer.Execute;
var
  mm: TMemory_data;
  I: Integer;
  TTpi: TTransPkgItem;
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
end;

function TSql2014logAnalyzer.getDataFrom_TEXT_MIX(idx: TBytes; tPkg: TTransPkgItem): TBytes;
begin
  //toDO: ��ȡ�ֿ�����
  Loger.Add('TSql2014logAnalyzer.getDataFrom_TEXT_MIX��δ��� ');

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
  DataRow:Tsql2014RowData;
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
            DataRow := Tsql2014RowData.Create;
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
            //TODO: ����Ӧ��Ч��InsertRowFlag������
            TmpInt := BinReader.readWord; //�������� Offset
            BinReader.seek(TmpInt, soBeginning);
            ColCnt := BinReader.readWord;
            if ColCnt <> DbTable.Fields.Count then
            begin
              Loger.Add('ʵ����������־��ƥ�䣡��������޸ı����ɵģ�����������LSN��' + LSN2Str(tPkg.LSN));
              exit;
            end;
            nullMap := BinReader.readBytes((ColCnt + 7) shr 3);
            TmpInt := BinReader.readWord; //var �ֶ�����
            SetLength(VarFieldValEndOffset, TmpInt);
            for I := 0 to TmpInt - 1 do
            begin
              VarFieldValEndOffset[I] := BinReader.readWord;
            end;
            VarFieldValBase := BinReader.Position;
            boolbit := 0;
            for I := 0 to DbTable.Fields.Count do
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
                      val_begin := VarFieldValBase + (VarFieldValEndOffset[Idx - 1] and $7FFF);
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
                        on exx:Exception do
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
                    on exx:Exception do
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

          end;
        LCX_TEXT_MIX: //�зֿ�����
          begin

          end;
      else


      end;
      FRows.Add(DataRow);
    Except
      if DataRow<>nil then
        DataRow.Free;

      Loger.Add('PriseRowLog_Insert ������δ����� ContextCode :' + contextCodeToStr(Rldo.normalData.ContextCode));
    end;
  finally
    if BinReader<>nil then
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
  Fields := TList.Create;
end;

destructor Tsql2014RowData.Destroy;
var
  I: Integer;
begin
  for I := 0 to Fields.Count do
  begin
    Dispose(Fields[I]);
  end;
  Fields.free;
  inherited;
end;

end.

