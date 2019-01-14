unit pagecache;

interface

uses
  windows,p_structDefine, databaseConnection, System.SysUtils, System.Contnrs,
  LogtransPkg, System.SyncObjs, System.Generics.Collections;

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
    FlsnLstCs: TCriticalSection;
    FpageDict:array of TDictionary<Integer, TObjectList>;
    function getSoltDataFromFullPagedata(PageHeader: PPage_Header; soltid: Word): TBytes;
    procedure UnDoUpdate(RawData: TBytes; RlOpt: PRawLog_DataOpt);
    procedure applyChange(srcData, pdata: Pointer; offset, size_old, size_new, datarowCnt: Integer);
    procedure UnDoUpdate_LOP_MODIFY_ROW(RawData: TBytes; RlOpt: PRawLog_DataOpt);
    procedure UnDoUpdate_LOP_MODIFY_COLUMNS(RawData: TBytes; RlOpt: PRawLog_DataOpt);
    function LoadFullDataFromDb(LSN: Tlog_LSN; pageid: TPage_Id): TBytes;
    function LoadFullDataFromDb_after(LSN: Tlog_LSN; pageid: TPage_Id;FlsnLst :TObjectList;Transpkg: TTransPkg): TBytes;
    function getTranslogby(LSN: Tlog_LSN; Transpkg: TTransPkg): TBytes;
  public
    constructor Create(DbCon: TdatabaseConnection);
    destructor Destroy; override;
    function get(LSN: Tlog_LSN; pageid: TPage_Id; Transpkg: TTransPkg = nil): TBytes;
  end;

  TPageCache = class(TObject)
  private
    pccData: array[0..255] of TPageCacheDB;
  public
    destructor Destroy; override;
    function getUpdateSoltData(databaseConnection: TdatabaseConnection; LSN: Tlog_LSN; pageid: TPage_Id;Transpkg: TTransPkg=nil): TBytes;
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

function TPageCache.getUpdateSoltData(databaseConnection: TdatabaseConnection; LSN: Tlog_LSN; pageid: TPage_Id;Transpkg: TTransPkg): TBytes;
begin
  if pccData[databaseConnection.dbID] = nil then
  begin
    pccData[databaseConnection.dbID] := TPageCacheDB.Create(databaseConnection);
  end;

  result := pccData[databaseConnection.dbID].get(LSN, pageid, Transpkg);
end;

{ TPageCacheDB }

constructor TPageCacheDB.Create(DbCon: TdatabaseConnection);
begin
  FDbCon := DbCon;
  FlsnLstCs := TCriticalSection.Create;
end;

destructor TPageCacheDB.Destroy;
var
  I: Integer;
  jobo: TObjectList;
begin
  for I := 0 to Length(FpageDict)-1 do
  begin
    for jobo in FpageDict[i].Values do
    begin
      jobo.Free;
    end;
    FpageDict[i].free;
  end;

  SetLength(FpageDict, 0);
  FlsnLstCs.Free;
  inherited;
end;

function TPageCacheDB.get(LSN: Tlog_LSN; pageid: TPage_Id;Transpkg: TTransPkg): TBytes;
var
  I: Integer;
  pcd: TPageCacheRawData;
  FlsnLst: TObjectList;
  Adbpage :TDictionary<Integer, TObjectList>;
begin
  Result := nil;
  if pageid.FID >= Length(FpageDict) then
  begin
    SetLength(FpageDict, pageid.FID);
  end;
  Adbpage := FpageDict[pageid.FID - 1];
  if Adbpage = nil then
  begin
    FlsnLstCs.Enter;
    try
      Adbpage := FpageDict[pageid.FID - 1];
      if Adbpage = nil then
      begin
        Adbpage := TDictionary<Integer, TObjectList>.Create;
        FpageDict[pageid.FID - 1] := Adbpage;
      end;
    finally
      FlsnLstCs.Leave;
    end;
  end;
  if Adbpage.TryGetValue(pageid.PID, FlsnLst) then
  begin
    //同一个page只会有一个线程访问。
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
    if FlsnLst.Count=0 then
    begin
      FlsnLstCs.Enter;
      try
        Adbpage.Remove(pageid.PID);
        FlsnLst.free;
      finally
        FlsnLstCs.Leave;
      end;
    end;
  end else begin
    //还未创建
    FlsnLst := TObjectList.Create;
    FlsnLstCs.Enter;
    try
      Adbpage.Add(pageid.PID, FlsnLst);
    finally
      FlsnLstCs.Leave;
    end;
  end;
  if Length(Result) = 0 then
  begin
    Result := LoadFullDataFromDb_after(LSN, pageid, FlsnLst, Transpkg);
  end;
end;

function TPageCacheDB.getSoltDataFromFullPagedata(PageHeader: PPage_Header; soltid: Word): TBytes;
var
  dataStartOffset: UIntPtr;
  RecordLen: Word;
begin
  if soltid > PageHeader.m_slotCnt then
    result := nil;
  SetLength(Result, $2000); //预留整页空间
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
        //没找到。越过
        Break;
      end;

      //继续找
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
          //update 保存当前lsn 页数据
          RecordLen := PageRowCalcLength(@soltBuffer[RlOpt.pageId.solt][0]);
          SetLength(TmpBytes, RecordLen);
          Move(soltBuffer[RlOpt.pageId.solt][0], TmpBytes[0], RecordLen);
          if (tmpLsn.LSN_1 = LSN.LSN_1) and (tmpLsn.LSN_2 = LSN.LSN_2) and (tmpLsn.LSN_3 = LSN.LSN_3) then
          begin
            Result := TmpBytes;
            break;
          end;
          //FlsnLst.Add(TPageCacheRawData.Create(tmpLsn, TmpBytes));
        end
        else
        begin
          //初始化页或复制页
          //TODO:如果是复制页，尝试从日志中提取数据
          FDbCon.FlogSource.Loger.Add('提取页数据未完成：pageid：0x%.4X:%.8X', [pageid.FID, pageid.PID], LOG_IMPORTANT);
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

function TPageCacheDB.getTranslogby(LSN: Tlog_LSN; Transpkg: TTransPkg): TBytes;
var
  tpi:TTransPkgItem;
  I: Integer;
  minLsn,maxLsn:Tlog_LSN;
begin
  SetLength(Result, 0);
  minLsn := TTransPkgItem(Transpkg.Items[0]).lsn;
  maxLsn := TTransPkgItem(Transpkg.Items[Transpkg.Items.Count - 1]).lsn;
  if ((LSN.LSN_1 > minLsn.LSN_1) or ((LSN.LSN_1 = minLsn.LSN_1) and (LSN.LSN_2 >= minLsn.LSN_2)))
    and ((LSN.LSN_1 < maxLsn.LSN_1) or ((LSN.LSN_1 = maxLsn.LSN_1) and (LSN.LSN_2 <= maxLsn.LSN_2)))
  then
  begin
    for I := 0 to Transpkg.Items.count - 1 do
    begin
      tpi := TTransPkgItem(Transpkg.Items[I]);
      if (tpi.LSN.LSN_1 = LSN.LSN_1) and (tpi.LSN.LSN_2 = LSN.LSN_2) and (tpi.LSN.LSN_3 = LSN.LSN_3) then
      begin
        SetLength(Result, tpi.Raw.dataSize);
        Move(tpi.Raw.data^, Result[0], tpi.Raw.dataSize);
      end;
    end;
  end;
  if length(Result) = 0 then
  begin
    Result := getSingleTransLogFromFndblog(FDbCon, LSN);
  end;
end;

function TPageCacheDB.LoadFullDataFromDb_after(LSN: Tlog_LSN; pageid: TPage_Id;FlsnLst :TObjectList;Transpkg: TTransPkg): TBytes;
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
        //没找到。越过
        Break;
      end;

      //继续找
      transLog := getTranslogby(tmpLsn, Transpkg);
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

          //update 保存当前lsn 页数据
          RecordLen := PageRowCalcLength(@soltBuffer[RlOpt.pageId.solt][0]);
          SetLength(TmpBytes, RecordLen);
          Move(soltBuffer[RlOpt.pageId.solt][0], TmpBytes[0], RecordLen);
          if (tmpLsn.LSN_1 = LSN.LSN_1) and (tmpLsn.LSN_2 = LSN.LSN_2) and (tmpLsn.LSN_3 = LSN.LSN_3) then
          begin
            Result := TmpBytes;
            break;
          end;
          FlsnLst.Add(TPageCacheRawData.Create(tmpLsn, TmpBytes));

          UnDoUpdate(soltBuffer[RlOpt.pageid.solt], RlOpt);
        end
        else
        begin
          //初始化页或复制页
          //TODO:如果是复制页，尝试从日志中提取数据
          FDbCon.FlogSource.Loger.Add('提取页数据未完成：pageid：0x%.4X:%.8X', [pageid.FID, pageid.PID], LOG_IMPORTANT);
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
  //取R0回滚操作
  R0Offset := SizeOf(TRawLog_DataOpt) + RlOpt.NumElements * 2;
  //4字节对齐
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
  0:更新的Offset
  1:更新的大小
  2:聚集索引信息
  3:锁信息，object_id和 lock_key
  --之后是修改的内容，类似Log_MODIFY_ROW的r0和r1
  每2个为一组，至少有2组
  *)
  setlength(R_len, RlOpt.NumElements);
  setlength(ModifyblockInfo, (RlOpt.NumElements - 4) div 2);
  //长度
  TmpPosition := UIntPtr(RlOpt) + SizeOf(TRawLog_DataOpt);
  for I := 0 to RlOpt.NumElements - 1 do
  begin
    R_len[I] := Pword(TmpPosition + I * 2)^;
  end;
  TmpPosition := TmpPosition + RlOpt.NumElements * 2;
  TmpPosition := (TmpPosition + 3) and $FFFFFFFC;
  //读Offset
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
    //取前面一个块，用于回滚。
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
      //数据后移
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
      //前移
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

