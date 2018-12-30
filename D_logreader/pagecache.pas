unit pagecache;

interface

uses
  p_structDefine, databaseConnection, System.SysUtils, System.Contnrs;

type
  TPageCacheRawData = class(TObject)
    lsn: Tlog_LSN;
    PageRawData: TBytes;
    constructor Create(lsn: Tlog_LSN; PageRawData: TBytes);
    destructor Destroy; override;
  end;

  TPageCacheDB = class(TObject)
  private
    FDbCon: TdatabaseConnection;
    FlsnLst: TObjectList;
    function LoadFullDataFromDb(LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
    function getSoltDataFromFullPagedata(PageHeader: PPage_Header; soltid: Word): TBytes;
    procedure UnDoUpdate(RawData: TBytes; RlOpt: PRawLog_DataOpt);
    procedure ApplyUpdateLog2Raw(RawData, newData: TBytes; ModifyOffset: Word; oldDataLen: Word);deprecated 'not use';
    procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
    procedure UnDoUpdate_LOP_MODIFY_ROW(RawData: TBytes; RlOpt: PRawLog_DataOpt);
    procedure UnDoUpdate_LOP_MODIFY_COLUMNS(RawData: TBytes; RlOpt: PRawLog_DataOpt);
  public
    constructor Create(DbCon: TdatabaseConnection);
    destructor Destroy; override;
    function get(LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
  end;

  TPageCache = class(TObject)
  private
    pccData: array[0..255] of TPageCacheDB;
  public
    destructor Destroy; override;
    function getUpdateSoltData(databaseConnection: TdatabaseConnection; LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
  end;

var
  pc__PageCache: TPageCache;

implementation

uses
  System.Classes,sqlextendedprocHelper, OpCode, loglog;

{ TPageCache }

destructor TPageCache.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(pccData) - 1 do
  begin
    if pccData[I] <> nil then
      pccData[I].Free;
  end;
  inherited;
end;

function TPageCache.getUpdateSoltData(databaseConnection: TdatabaseConnection; LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
begin
  if pccData[databaseConnection.dbID] = nil then
  begin
    pccData[databaseConnection.dbID] := TPageCacheDB.Create(databaseConnection);
  end;

  result := pccData[databaseConnection.dbID].get(LSN, pageid);
end;

{ TPageCacheDB }

constructor TPageCacheDB.Create(DbCon: TdatabaseConnection);
begin
  FDbCon := DbCon;
  FlsnLst := TObjectList.Create;
end;

destructor TPageCacheDB.Destroy;
begin
  FlsnLst.Free;
  inherited;
end;

function TPageCacheDB.get(LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
var
  I: Integer;
  pcd: TPageCacheRawData;
begin
  Result := nil;
  for I := 0 to FlsnLst.Count - 1 do
  begin
    pcd := TPageCacheRawData(FlsnLst[I]);
    if (pcd.lsn.LSN_1 = LSN.LSN_1) and (pcd.lsn.LSN_2 = LSN.LSN_2) and (pcd.lsn.LSN_3 = LSN.LSN_3) then
    begin
      SetLength(result, Length(pcd.PageRawData));
      Move(pcd.PageRawData[0], Result[0], Length(pcd.PageRawData));
      FlsnLst.Delete(I);
      Break;
    end;
  end;

  if Length(Result) = 0 then
  begin
    Result := LoadFullDataFromDb(LSN, pageid);
  end;
end;

function TPageCacheDB.getSoltDataFromFullPagedata(PageHeader: PPage_Header; soltid: Word): TBytes;
var
  dataStartOffset: UIntPtr;
  RecordLen: Word;
begin
  if soltid > PageHeader.m_slotCnt then
    result := nil;
  SetLength(Result, $2000); //Ԥ����ҳ�ռ�
  dataStartOffset := PWORD(UIntPtr(PageHeader) + $2000 - 2 - soltid * 2)^;
  dataStartOffset := dataStartOffset + UIntPtr(PageHeader);
  RecordLen := PageRowCalcLength(Pointer(dataStartOffset));
  Move(Pointer(dataStartOffset)^, Result[0], RecordLen);
end;

function TPageCacheDB.LoadFullDataFromDb(LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
var
  FullPageData: TBytes;
  PageHeader: PPage_Header;
  tmpLsn: Tlog_LSN;
  transLog: TBytes;
  TmpBytes: Tbytes;
  Rl: PRawLog;
  RlOpt: PRawLog_DataOpt;
  soltBuffer: array of TBytes;
  RecordLen: Word;
  RecordOffset: Cardinal;
begin
  Result := nil;
  FullPageData := getDbccPageFull(FDbCon, pageid);
  if Length(FullPageData) > 0 then
  begin
    PageHeader := PPage_Header(@FullPageData[0]);
    tmpLsn := PageHeader.m_lsn;
    SetLength(soltBuffer, PageHeader.m_slotCnt);
    while True do
    begin
      if (tmpLsn.LSN_1 < LSN.LSN_1) or ((tmpLsn.LSN_1 = LSN.LSN_1) and (tmpLsn.LSN_2 < LSN.LSN_2)) or ((tmpLsn.LSN_1 = LSN.LSN_1) and (tmpLsn.LSN_2 = LSN.LSN_2) and (tmpLsn.LSN_3 < LSN.LSN_3)) then
      begin
        //û�ҵ���Խ��
        Break;
      end;

      //������
      transLog := getSingleTransLogFromFndblog(FDbCon, tmpLsn);
      if length(transLog) = 0 then
      begin
        Break;
      end;
      try
        Rl := PRawLog(@transLog[0]);
        RlOpt := PRawLog_DataOpt(Rl);
        if Rl.OpCode = LOP_INSERT_ROWS then
        begin
          SetLength(soltBuffer[RlOpt.pageId.solt], 0);
        end
        else if Rl.OpCode = LOP_DELETE_ROWS then
        begin
          RecordLen := PWord(@transLog[SizeOf(TRawLog_DataOpt)])^;   //R0
          RecordOffset := SizeOf(TRawLog_DataOpt) + RlOpt.NumElements * 2;
          RecordOffset := (RecordOffset + 3) and $FFFFFFFC;
          SetLength(soltBuffer[RlOpt.pageId.solt], $2000);
          Move(transLog[RecordOffset], soltBuffer[RlOpt.pageId.solt][0], RecordLen);
        end
        else if (Rl.OpCode = LOP_MODIFY_ROW) or (Rl.OpCode = LOP_MODIFY_COLUMNS) then
        begin
          if Length(soltBuffer[RlOpt.pageId.solt]) = 0 then
          begin
            soltBuffer[RlOpt.pageId.solt] := getSoltDataFromFullPagedata(PageHeader, RlOpt.pageId.solt);
          end;

          UnDoUpdate(soltBuffer[RlOpt.pageid.solt], RlOpt);
          //update ���浱ǰlsn ҳ����
          RecordLen := PageRowCalcLength(@soltBuffer[RlOpt.pageId.solt][0]);
          SetLength(TmpBytes, RecordLen);
          Move(soltBuffer[RlOpt.pageId.solt][0], TmpBytes[0], RecordLen);
          if (tmpLsn.LSN_1 = LSN.LSN_1) and (tmpLsn.LSN_2 = LSN.LSN_2) and (tmpLsn.LSN_3 = LSN.LSN_3) then
          begin
            Result := TmpBytes;
            break;
          end;
          FlsnLst.Add(TPageCacheRawData.Create(tmpLsn, TmpBytes));
        end
        else
        begin
          //��ʼ��ҳ����ҳ
          //TODO:����Ǹ���ҳ�����Դ���־����ȡ����
          FDbCon.FlogSource.Loger.Add('��ȡҳ����δ��ɣ�pageid��0x%.4X:%.8X', [pageid.FID, pageid.PID], LOG_IMPORTANT);
          Break;
        end;

        tmpLsn := RlOpt.previousPageLsn;
      finally
        SetLength(transLog, 0);
      end;
    end;
    SetLength(soltBuffer, 0);
    SetLength(FullPageData, 0);
  end;
end;

procedure TPageCacheDB.UnDoUpdate_LOP_MODIFY_ROW(RawData: TBytes; RlOpt: PRawLog_DataOpt);
var
  R0len, R1len: Word;
  R0Offset: Word;
  RecordLen: Word;
begin
  R0len := PWord(UIntPtr(RlOpt) + SizeOf(TRawLog_DataOpt))^;        //R0=oldData
  R1len := PWord(UIntPtr(RlOpt) + SizeOf(TRawLog_DataOpt) + 2)^;    //R1=newData
  //ȡR0�ع�����
  R0Offset := SizeOf(TRawLog_DataOpt) + RlOpt.NumElements * 2;
  //4�ֽڶ���
  R0Offset := (R0Offset + 3) and $FFFFFFFC;
  RecordLen := PageRowCalcLength(@RawData[0]);
  applyChange(@RawData[0], Pointer(UIntPtr(RlOpt) + R0Offset), RlOpt.OffsetInRow, R1len, R0len, RecordLen);
end;

procedure TPageCacheDB.UnDoUpdate_LOP_MODIFY_COLUMNS(RawData: TBytes; RlOpt: PRawLog_DataOpt);
type
  Ttos = record
    oldlen: Word;
    newlen: Word;
    ModifyOffset: Word;
    oldDataOffset: UIntPtr;
  end;
var
  I: Integer;
  ModifyblockInfo: array of Ttos;
  R_len: array of Word;
  TmpPosition: UIntPtr;
  RecordLen: Word;
begin
  (*
  0:���µ�Offset
  1:���µĴ�С
  2:�ۼ�������Ϣ
  3:����Ϣ��object_id�� lock_key
  --֮�����޸ĵ����ݣ�����Log_MODIFY_ROW��r0��r1
  ÿ2��Ϊһ�飬������2��
  *)
  setlength(R_len, RlOpt.NumElements);
  setlength(ModifyblockInfo, (RlOpt.NumElements - 4) div 2);
  //����
  TmpPosition := UIntPtr(RlOpt) + SizeOf(TRawLog_DataOpt);
  for I := 0 to RlOpt.NumElements - 1 do
  begin
    R_len[I] := Pword(TmpPosition + I * 2)^;
  end;
  TmpPosition := TmpPosition + RlOpt.NumElements * 2;
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  //��Offset
  for I := 0 to (R_len[0] div 2) - 1 do
  begin
    ModifyblockInfo[I].ModifyOffset := Pword(TmpPosition + I * 4)^;
  end;
  TmpPosition := TmpPosition + R_len[0];
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  TmpPosition := TmpPosition + R_len[1];
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  TmpPosition := TmpPosition + R_len[2];
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  TmpPosition := TmpPosition + R_len[3];
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;

  for I := 0 to Length(ModifyblockInfo) - 1 do
  begin
    ModifyblockInfo[I].oldlen := R_len[4 + I * 2];
    ModifyblockInfo[I].newlen := R_len[4 + I * 2 + 1];
    //ȡǰ��һ���飬���ڻع���
    ModifyblockInfo[I].oldDataOffset := TmpPosition;

    TmpPosition := TmpPosition + ModifyblockInfo[I].oldlen;
    TmpPosition := (TmpPosition + 3) and $FFFFFFFC;

    TmpPosition := TmpPosition + ModifyblockInfo[I].newlen;
    TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  end;

  for I := 0 to Length(ModifyblockInfo) - 1  do
  begin
    RecordLen := PageRowCalcLength(@RawData[0]);
    applyChange(@RawData[0], Pointer(ModifyblockInfo[I].oldDataOffset), ModifyblockInfo[I].ModifyOffset,
     ModifyblockInfo[I].newlen, ModifyblockInfo[I].oldlen, RecordLen);
  end;
end;

procedure TPageCacheDB.UnDoUpdate(RawData: TBytes; RlOpt: PRawLog_DataOpt);
begin
  if (RlOpt.normalData.OpCode = LOP_MODIFY_ROW) then
  begin
    UnDoUpdate_LOP_MODIFY_ROW(RawData, RlOpt);
  end
  else if (RlOpt.normalData.OpCode = LOP_MODIFY_COLUMNS) then
  begin
    UnDoUpdate_LOP_MODIFY_COLUMNS(RawData, RlOpt);
  end;
end;

procedure TPageCacheDB.applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
var
  tmpdata: Pointer;
  tmpLen: Integer;
begin
  if size_old = size_new then
  begin
    Move(pdata^, Pointer(uintptr(srcData) + offset)^, size_old);
  end
  else
  begin
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
    end
    else
    begin
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

procedure TPageCacheDB.ApplyUpdateLog2Raw(RawData, newData: TBytes; ModifyOffset: Word; oldDataLen: Word);
var
  RecordLen: Word;
  tmpOffset: Word;
  mriBuf: TBytes;
begin
  RecordLen := PageRowCalcLength(@RawData[0]);
  if oldDataLen = length(newData) then
  begin
    Move(newData[0], RawData[ModifyOffset], Length(newData));
  end
  else if oldDataLen > length(newData) then
  begin
    Move(newData[0], RawData[ModifyOffset], Length(newData));
    //ǰ��
    tmpOffset := ModifyOffset + length(newData) + oldDataLen - length(newData);
    Move(RawData[tmpOffset], RawData[ModifyOffset + length(newData)], RecordLen - tmpOffset);
  end
  else
  begin
    //����
    SetLength(mriBuf, RecordLen - ModifyOffset - oldDataLen);

    tmpOffset := ModifyOffset + length(newData) + oldDataLen - length(newData);

    Move(newData[0], RawData[ModifyOffset], Length(newData));
  end;

end;


{ TPageCacheData }

constructor TPageCacheRawData.Create(lsn: Tlog_LSN; PageRawData: TBytes);
begin
  self.lsn := lsn;
  self.PageRawData := PageRawData;
end;

destructor TPageCacheRawData.Destroy;
begin
  SetLength(PageRawData, 0);
  inherited;
end;

initialization
  pc__PageCache := TPageCache.Create;

finalization
  pc__PageCache.Free;

end.

