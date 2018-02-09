unit logRecdItemSave;

interface

uses
  System.SyncObjs, System.Contnrs, Winapi.Windows, System.Classes;

type
  TLSN = packed record
    lsn_1: DWORD;
    lsn_2: DWORD;
    lsn_3: WORD;
  end;

  TLSNBuffer = packed record
    lsn_3: WORD;
    Offset: DWORD;
  end;

  PlogRecdItem = ^TlogRecdItem;

  TlogRecdItem = packed record
    n: PlogRecdItem;
    TranID_1: DWORD;
    TranID_2: WORD;
    lsn: TLSN;
    length: DWORD;
    dbId: Word;
    val: Pointer;
  end;

  PIdxData = ^TIdxData;

  TIdxData = packed record
    lsn2: DWORD;
    Size: Word;
    lsn3: array of WORD;
    offse: array of DWORD;
  end;

type
  TDbidCustomBucketList = class(TBucketList)
  protected
    function GetData(AItem: NativeInt): Pointer;
    procedure SetData(AItem: NativeInt; const AData: Pointer);
  public
    property Data[AItem: NativeInt]: Pointer read GetData write SetData; default;
  end;

  TVlfMgr = class(TObject)
  private
    Fdbid: Word;
    ReqNo: DWORD;

    cachelst: TList;
    IdxFile:THandle;
    IdxFileCS:TCriticalSection;
    DataFile:THandle;
    DataFileCS:TCriticalSection;
    procedure WriteIdxExists(tmpxx: PIdxData);
  public
    constructor Create(dbid: Word; lsn1: DWORD; slogPath: string);
    destructor Destroy; override;
    function Save(lsn2: WORD; logs: TList; data: TMemoryStream): Boolean;
  end;

type
  TPagelogFileMgr = class(TObject)
  private
    const
      SsPath = 'data\';
    var
      f_path: string;
      SaveCs: TCriticalSection;
      dbids: TDbidCustomBucketList;
  public
    constructor Create;
    destructor Destroy; override;
    function LogDataSaveToFile(dbid: Word; lsn1: DWORD; lsn2: WORD; logs: TList; data: TMemoryStream): Boolean;
  end;

function savePageLog: Boolean;

function savePageLog2: Boolean;

var
  PagelogFileMgr: TPagelogFileMgr;

implementation

uses
  pageCapture, System.SysUtils, pluginlog;

function savePageLog: Boolean;
const
  MAX_BUF_SIZE = $2000;
var
  DataPnt: Pointer;
  lri: PlogRecdItem;
  beginLsn, endLSN: TLSN;
  dataBuf: Pointer;
  dataBufPosition: DWORD;
begin
  if Assigned(_Lc_Get_PaddingDataCnt) and (_Lc_Get_PaddingDataCnt > 0) then
  begin
    DataPnt := _Lc_Get_PaddingData;
    lri := PlogRecdItem(DataPnt);
    beginLsn := lri.lsn;
    endLSN := beginLsn;
    dataBuf := GetMemory(MAX_BUF_SIZE); //缓冲区大小
    dataBufPosition := 0;
    while lri <> nil do
    begin
      if (lri.length + 20) < (MAX_BUF_SIZE - dataBufPosition) then
      begin
        Move(lri.TranID_1, pointer(Cardinal(dataBuf) + dataBufPosition)^, 20);
        dataBufPosition := dataBufPosition + 20;
        Move(lri.val^, pointer(Cardinal(dataBuf) + dataBufPosition)^, lri.length);
        dataBufPosition := dataBufPosition + lri.length;
      end
      else
      begin
        if dataBufPosition = 0 then
        begin
          //单行超过2K的都是废数据
        end
        else
        begin
//          PagelogFileMgr.LogDataSaveToFile(dataBuf, dataBufPosition, beginLsn);
          beginLsn := lri.lsn;
          dataBufPosition := 0;
          Continue;
        end;
      end;
      endLSN := lri.lsn;
      //todo:这里释放 PlogRecdItem
      lri := lri.n;
    end;
    if dataBufPosition > 0 then
    begin
//      PagelogFileMgr.LogDataSaveToFile(dataBuf, dataBufPosition, beginLsn);
    end;
  end;
end;

function savePageLog2: Boolean;
const
  MAX_BUF_SIZE = $2000;
var
  DataPnt: Pointer;
  lri: PlogRecdItem;
  logs: TList;
  prevLsn: TLSN;
  prevDBid: Word;
  mmData: TMemoryStream;
  tmpLsn: ^TLSNBuffer;
  I: Integer;
begin
  if Assigned(_Lc_Get_PaddingDataCnt) and (_Lc_Get_PaddingDataCnt > 0) then
  begin
    logs := TList.create;
    mmData := TMemoryStream.Create;
    try
      try
        DataPnt := _Lc_Get_PaddingData;
        lri := PlogRecdItem(DataPnt);
        prevDBid := 0;
        prevLsn.lsn_1 := 0;
        while lri <> nil do
        begin
          if (prevDBid <> lri.dbId) or (prevLsn.lsn_1 <> lri.lsn.lsn_1) or (prevLsn.lsn_2 <> lri.lsn.lsn_2) then
          begin
            //不同组
            PagelogFileMgr.LogDataSaveToFile(prevDBid, prevLsn.lsn_1, prevLsn.lsn_2, logs, mmData);
            for I := 0 to logs.Count - 1 do
            begin
              tmpLsn := logs[I];
              Dispose(tmpLsn);
            end;
            logs.Clear;
            mmData.Clear;
            prevLsn := lri.lsn;
            Continue;
          end
          else
          begin
            //同一组

            new(tmpLsn);
            tmpLsn.lsn_3 := lri.lsn.lsn_3;
            tmpLsn.Offset := mmData.Size;
            logs.Add(tmpLsn);

            mmData.Write(lri.length, 4);
            mmData.Write(lri.val, lri.length)
          end;
          lri := lri.n;
        end;
        if logs.Count > 0 then
        begin
          PagelogFileMgr.LogDataSaveToFile(prevDBid, prevLsn.lsn_1, prevLsn.lsn_2, logs, mmData);
        end;
        Result := True;
      except
        Result := False;
      end;
    finally
      mmData.Free;
      logs.Free;
    end;
  end;
end;

{ TPagelogFileMgr }

constructor TPagelogFileMgr.Create;
var
  Pathbuf: array[0..MAX_PATH + 2] of Char;
begin
  inherited;
  SaveCs := TCriticalSection.Create;

  GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
  f_path := ExtractFilePath(string(Pathbuf)) + SsPath;
  ForceDirectories(f_path);
  dbids := TDbidCustomBucketList.Create;
end;

destructor TPagelogFileMgr.Destroy;
begin
  SaveCs.Free;
  dbids.Free;
  inherited;
end;

function TPagelogFileMgr.LogDataSaveToFile(dbid: Word; lsn1: DWORD; lsn2: WORD; logs: TList; data: TMemoryStream): Boolean;
var
  DB: TDbidCustomBucketList;
  ReqNo: TVlfMgr;
begin
  DB := dbids[dbid];
  if DB = nil then
  begin
    DB := TDbidCustomBucketList.Create;
    dbids[dbid] := DB;
  end;
  ReqNo := DB[lsn1];
  if ReqNo = nil then
  begin
    ReqNo := TVlfMgr.Create(dbid, lsn1, f_path);
    DB[lsn1] := ReqNo;
  end;
  Result := ReqNo.save(lsn2, logs, data);
end;

{ TDbidCustomBucketList }

function TDbidCustomBucketList.GetData(AItem: NativeInt): Pointer;
var
  LBucket, LIndex: Integer;
begin
  if not FindItem(Pointer(AItem), LBucket, LIndex) then
  begin
    Result := nil;
  end
  else
    Result := Buckets[LBucket].Items[LIndex].data;
end;

procedure TDbidCustomBucketList.SetData(AItem: NativeInt; const AData: Pointer);
begin
  inherited data[Pointer(AItem)] := AData;
end;

{ TVlfMgr }

constructor TVlfMgr.Create(dbid: Word; lsn1: DWORD; slogPath: string);
var
  tmpFilePath:string;
begin
  cachelst := TList.Create;
  Fdbid := dbid;
  ReqNo := lsn1;
  IdxFile := 0;
  DataFile := 0;

  IdxFileCS:=TCriticalSection.Create;
  DataFileCS:=TCriticalSection.Create;

  tmpFilePath := slogPath + IntToStr(dbid) + '\' + IntToStr(lsn1) + '\';

  ForceDirectories(tmpFilePath);

  IdxFile := CreateFile(PChar(tmpFilePath+'1.idx'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if IdxFile <> INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！'+syserrormessage(GetLastError));
  end;

  DataFile := CreateFile(PChar(tmpFilePath+'1.data'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if DataFile <> INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！'+syserrormessage(GetLastError));
  end;
end;

destructor TVlfMgr.Destroy;
begin
  cachelst.Free;
  IdxFileCS.Free;
  DataFileCS.Free;
  inherited;
end;


procedure TVlfMgr.WriteIdxExists(tmpxx: PIdxData);
  procedure IdxMovebackData(xoffset, paddingCount:Cardinal;moveCount :Cardinal = 0);
  var
    rSize:Cardinal;
    pp:Pointer;
  begin
    if moveCount=0 then
    begin
      moveCount := GetFileSize(IdxFile ,nil);
      moveCount := moveCount - xoffset;
    end;
    SetFilePointer(IdxFile, xoffset, nil, soFromBeginning);
    pp := AllocMem(moveCount);
    if ReadFile(IdxFile, pp^, moveCount, rSize, nil) and (rSize = moveCount) then
    begin
      SetFilePointer(IdxFile, xoffset+paddingCount, nil, soFromBeginning);
      WriteFile(IdxFile, pp^, moveCount, rSize, nil);
    end;
    FreeMem(pp);
  end;
var
  aBuf:Pointer;
  rSize,wSize:Cardinal;
  id2:Integer;
  position:Cardinal;

  b_lsn2:DWORD;
  wcnt:Word;
  blankSize:Word;
  itemIdx:DWORD;//目录项的真实地址
  tmpSize:DWORD;
  tmpOffset:DWORD;
  tmpBuf:Pointer;
  TmpPosi:Cardinal;
begin
  IdxFileCS.Enter;
  try
    aBuf := AllocMem($2000);
    id2 := 0; //第几次读取数据
    SetFilePointer(IdxFile, 0, nil, soFromBeginning);
    while ReadFile(IdxFile, aBuf^, $2000, rSize, nil) and (rSize > 0) do
    begin
      position := 0;
//          TIdxData = packed record
//            lsn2: DWORD;
//            Size: Word;
//            lsn3: array[0..0] of WORD;
//            offse: array[0..0] of DWORD;
//          end;
      //+12一个项目最小有12字节
      while (position + 12) < rSize do
      begin
        //判断当前项目是否完整
        wcnt := PWORD(Cardinal(aBuf) + position + 4)^;
        if position + 6 + (wcnt * 6) > rSize then
        begin
          //不完整
          Break;
        end;


        b_lsn2 := PDWORD(Cardinal(aBuf)+position)^;
        if b_lsn2 = tmpxx.lsn2 then
        begin
          //存在
          itemIdx := (id2 * $2000) + position;
          //计算目录末尾位置
          tmpOffset := itemIdx + 4 + 2 + wcnt * (2 + 4);
          position := position + 4;
          wcnt := PWORD(Cardinal(aBuf)+position)^;
          position := position + 2;
          //写入内容大小
          blankSize := tmpxx.Size * (2 + 4);
          //后移目录
          IdxMovebackData(tmpOffset, blankSize);
          //新的项目大小 (不包含lsn2)
          tmpSize := 2 + (wcnt + tmpxx.Size) * (2 + 4);

          tmpBuf := AllocMem(tmpSize);
          TmpPosi := 0;
          //TIdxData.Size
          PWORD(Cardinal(tmpBuf)+TmpPosi)^ := wcnt + tmpxx.Size;
          TmpPosi := TmpPosi + 2;
          //老的lsn3
          Move(Pbyte(Cardinal(aBuf)+position)^, PByte(Cardinal(tmpBuf)+TmpPosi)^, wcnt*2);
          TmpPosi := TmpPosi + wcnt*2;
          //后面跟新的lsn3
          Move(tmpxx.lsn3[0], PByte(Cardinal(tmpBuf)+TmpPosi)^, tmpxx.Size*2);
          TmpPosi := TmpPosi + tmpxx.Size*2;


          position := position + wcnt * 2;
          //老的offse
          Move(Pbyte(Cardinal(aBuf)+position)^, PByte(Cardinal(tmpBuf)+TmpPosi)^, wcnt*4);
          TmpPosi := TmpPosi + wcnt*4;
          //后面跟新的offset
          Move(tmpxx.offse[0], PByte(Cardinal(tmpBuf)+TmpPosi)^, tmpxx.Size*4);
          TmpPosi := TmpPosi + tmpxx.Size*4;

          //重写当前条目(不包含lsn2)
          SetFilePointer(IdxFile, itemIdx + 4, nil, soFromBeginning);
          WriteFile(IdxFile, tmpBuf^, tmpSize, wSize, nil);
          FreeMem(tmpBuf);
          Exit;
        end else if b_lsn2 > tmpxx.lsn2 then
        begin
          //不存在
          itemIdx := (id2 * $2000) + position;
          //项目大小
          tmpSize := 4 + 2 + tmpxx.Size * (2 + 4);
          //后移目录
          IdxMovebackData(itemIdx, tmpSize);
          tmpBuf := AllocMem(tmpSize);

          TmpPosi := 0;
          //TIdxData.lsn2
          PDWORD(Cardinal(tmpBuf)+TmpPosi)^ := wcnt + tmpxx.lsn2;
          TmpPosi := TmpPosi + 4;
          //TIdxData.Size
          PWORD(Cardinal(tmpBuf)+TmpPosi)^ := wcnt + tmpxx.Size;
          TmpPosi := TmpPosi + 2;
          //后面跟新的lsn3
          Move(tmpxx.lsn3[0], PByte(Cardinal(tmpBuf)+TmpPosi)^, tmpxx.Size*2);
          TmpPosi := TmpPosi + tmpxx.Size*2;
          //后面跟新的offset
          Move(tmpxx.offse[0], PByte(Cardinal(tmpBuf)+TmpPosi)^, tmpxx.Size*4);
          TmpPosi := TmpPosi + tmpxx.Size*4;

          //重写当前条目
          SetFilePointer(IdxFile, itemIdx, nil, soFromBeginning);
          WriteFile(IdxFile, tmpBuf^, tmpSize, wSize, nil);
          FreeMem(tmpBuf);
          Exit;
        end else begin
          //焦点下一个项目
          position := position + 6 + (wcnt * 6);
        end;
      end;
      SetFilePointer(IdxFile, (id2 * $2000) + position, nil, soFromBeginning);
      id2 := id2 + 1;
    end;
  finally
    FreeMem(aBuf);
    IdxFileCS.Leave;
  end;
end;

function TVlfMgr.Save(lsn2: WORD; logs: TList; data: TMemoryStream): Boolean;
  procedure WriteIdx(tmp: PIdxData);
  var
    Wsize, Rsize: DWORD;
    buf:Pointer;
    I:Integer;
  begin
    IdxFileCS.Enter;
    try
//          TIdxData = packed record
//            lsn2: DWORD;
//            Size: Word;
//            lsn3: array[0..0] of WORD;
//            offse: array[0..0] of DWORD;
//          end;
      Wsize := SizeOf(DWORD) + SizeOf(WORD) + tmp.Size * SizeOf(WORD) + tmp.Size * SizeOf(DWORD);
      buf := AllocMem(Wsize + 10);
      PDWORD(buf)^ := tmp.lsn2;
      PWORD(Cardinal(buf) + 4)^ := tmp.Size;
      for I := 0 to tmp.Size - 1 do
      begin
        PWORD(Cardinal(buf) + 4 + Cardinal(i * 2))^ := tmp.lsn3[i];
        PDWORD(Cardinal(buf) + 4 + Cardinal(tmp.Size*2 + i * 2))^ := tmp.offse[i];
      end;

      SetFilePointer(IdxFile, 0, nil, soFromEnd);
      WriteFile(IdxFile, buf^, Wsize, Rsize, nil);
    finally
      IdxFileCS.Leave;
    end;
  end;

var
  I, J: Integer;
  tmp: PIdxData;
  tmpLsn: ^TLSNBuffer;
  lsize:DWORD;
  Wsize:DWORD;
  hasFound:Boolean;
  min_id:Integer;
begin
  if logs.Count > 0 then
  begin
    //先直接写入log到文件
    DataFileCS.Enter;
    try
      lsize := SetFilePointer(DataFile, 0, nil, soFromEnd);
      WriteFile(DataFile, data.Memory^, data.Size, Wsize, nil);
    finally
      DataFileCS.Leave;
    end;

    //先在cache里面找，如果没有找到，
    //小于cache里最小的，就到已保存的文件中找，
    //大于cache里最小的，新增cache内容，并保存最小的到文件
    hasFound := False;
    for I := 0 to cachelst.Count - 1 do
    begin
      tmp := cachelst[I];
      if tmp.lsn2 = lsn2 then
      begin
        Wsize := tmp.Size;
        tmp.Size := tmp.Size + logs.Count;
        SetLength(tmp.lsn3, tmp.Size);
        SetLength(tmp.offse, tmp.Size);
        for J := 0 to logs.Count - 1 do
        begin
//          TIdxData = packed record
//            lsn2: DWORD;
//            Size: Word;
//            lsn3: array[0..0] of WORD;
//            offse: array[0..0] of DWORD;
//          end;
          tmpLsn := logs[J];
          tmp.lsn3[Wsize + Cardinal(J)] := tmpLsn.lsn_3;
          tmp.offse[Wsize + Cardinal(J)] := lsize + tmpLsn.Offset;
        end;
        hasFound := True;
        Break;
      end;
    end;

    if not hasFound then
    begin
      //cache中不存在
      //循环找最小的
      Wsize := $FFFFFFFF;
      min_id := -1;
      for I := 0 to cachelst.Count - 1 do
      begin
        tmp := cachelst[I];
        if tmp.lsn2 < Wsize then
        begin
          Wsize := tmp.lsn2;
          min_id := I;
        end;
      end;

      //cachelst为空，或 lsn2大于cachelst中最小的
      if (min_id = -1) or (Wsize < lsn2) then
      begin
        //写入缓存
        new(tmp);
        tmp.lsn2 := lsn2;
        tmp.Size := logs.Count;
        SetLength(tmp.lsn3, tmp.Size);
        SetLength(tmp.offse, tmp.Size);
        for J := 0 to logs.Count - 1 do
        begin
          tmpLsn := logs[J];
          tmp.lsn3[J] := tmpLsn.lsn_3;
          tmp.offse[J] := lsize + tmpLsn.Offset;
        end;
        cachelst.Add(tmp);
        if (cachelst.Count > 5) and (min_id > -1)  then
        begin
          //把5个之前的index写到文件
          tmp := cachelst[min_id];
          WriteIdx(tmp);
          cachelst.Delete(min_id);
          Dispose(tmp);
        end;

      end else begin
        //直接搞文件
        new(tmp);
        tmp.lsn2 := lsn2;
        tmp.Size := logs.Count;
        SetLength(tmp.lsn3, tmp.Size);
        SetLength(tmp.offse, tmp.Size);
        for J := 0 to logs.Count - 1 do
        begin
          tmpLsn := logs[J];
          tmp.lsn3[J] := tmpLsn.lsn_3;
          tmp.offse[J] := lsize + tmpLsn.Offset;
        end;
        WriteIdxExists(tmp);
        Dispose(tmp);
      end;
    end;
  end;
end;

initialization
  PagelogFileMgr := TPagelogFileMgr.Create;

finalization
  pageCapture_finit;
  PagelogFileMgr.Free;

end.

