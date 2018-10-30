unit p_RawMgr_2;

interface

uses
  System.Classes, System.Contnrs, System.SyncObjs, Winapi.Windows;

function PageLog_save: Boolean;
function PageLog_load(dbid: Word; lsn1: DWORD; lsn2: DWORD; lsn3: WORD; data: TMemoryStream): Boolean;


type
  TloopSaveMgr = class(TThread)
  public
    procedure Execute; override;
    constructor Create;
    destructor Destroy; override;
  end;
  
var
  loopSaveMgr: TloopSaveMgr;

implementation

uses
  loglog, System.SysUtils, pageCaptureDllHandler, Memory_Common;

type
  TLSN = packed record
    lsn_1: DWORD;
    lsn_2: DWORD;
    lsn_3: WORD;
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

  PLidxItem_Offset = ^TLidxItem_Offset; 
  TLidxItem_Offset = packed record
    DataOffset: DWORD;
    DataOffsetH: WORD;
    LogSize: WORD;
  end;
  
  PLidxItem = ^TLidxItem;

  TLidxItem = packed record      
    case Integer of
      0:
        (Lsn3: Word;
        ReqNo: DWORD;
        Reserve: Word;
        DataOffset: DWORD;
        DataOffsetH: WORD;
        LogSize: WORD;);
      1:
        (HHH: Uint64;
        LLL: Uint64);

  end;

  TLidxMgr = class(TObject)
  const
    IdxFileHeader: array[0..$F] of AnsiChar = ('L', 'R', 'I', 'D', 'X', 'P', 'K', 'G', #0, #0, #0, #0, #0, #0, #0, #2);
    BUFMAXSIZE = $1000;
  private
    Fvlf:TObject;
    FHandle:THandle;
    Wbuff:Pointer;        //文件缓存
    WbuffPosi:Cardinal;   //Wbuff对应文件的真实位置。自后往前查找的
    WbuffLen:Cardinal;    //Wbuff内容的实际长度

    procedure addOutOfBuf(_key, _offset: UInt64);
  public
    constructor Create(IdxHandle:THandle;vlf:TObject);
    destructor Destroy; override;
    procedure add(_key:UInt64; _offset:UInt64);
    function get(_key:UInt64;out _offset:UInt64): Boolean;
  end;

  TVlfMgr = class(TObject)
  private
    Fdbid: Word;
    ReqNo: DWORD;
    Handle_IdxFile:THandle;
    Handle_DataFile:THandle;
    idxObj : TLidxMgr;
  public
    constructor Create(dbid: Word; lsn1: DWORD; slogPath: string);
    destructor Destroy; override;
    function Save(Lri: TlogRecdItem): Boolean;
    function Get(lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
  end;

  TDBidObj = class;

  TDbidCustomList = class(TObject)
  private
    FIdxs:TList;
    FObjs:TObjectList;
    FsCS: TCriticalSection;
    procedure Add(idx:NativeInt; AData: Pointer);
  public
    constructor Create;
    destructor Destroy; override;
    function GetObj(idx:NativeInt):TDBidObj;
    procedure Remove(idx:NativeInt);
  end;

  TDBidObj = class(TDbidCustomList)
  public
    function GetObj(dbid: Word; lsn1: DWORD; slogPath: string): TVlfMgr;
  end;

  TPagelogFileMgr = class(TObject)
  private
    const
      SsPath = 'data\';
    var
      f_path: string;
      dbids: TDbidCustomList;
      FaddCS:TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    function LogDataSaveToFile(Lri:TlogRecdItem): Boolean;
    function LogDataGetData(dbid: Word; lsn1: DWORD; lsn2: DWORD; lsn3: WORD; data: TMemoryStream): Boolean;
  end;  

var
  PagelogFileMgr: TPagelogFileMgr;


function PageLog_load(dbid: Word; lsn1: DWORD; lsn2: DWORD; lsn3: WORD; data: TMemoryStream): Boolean;
begin  
  Result := PagelogFileMgr.LogDataGetData(dbid, lsn1, lsn2, lsn3, data);
end;

function PageLog_save: Boolean;
const
  MAX_BUF_SIZE = $2000;
var
  DataPnt: Pointer;
  lri: PlogRecdItem;
  logs: TList;
  tmpPtr:Pointer;
begin
  if Assigned(_Lc_Get_PaddingDataCnt) and (_Lc_Get_PaddingDataCnt > 0) then
  begin
    logs := TList.create;
    try
      try
        DataPnt := _Lc_Get_PaddingData;
        lri := PlogRecdItem(DataPnt);
        while lri <> nil do
        begin
          Loger.Add('saveOne:%.8x:%.8x:%.4x,n:%x',[lri^.lsn.lsn_1,lri^.lsn.lsn_2,lri^.lsn.lsn_3,Uint_ptr(lri^.n)], LOG_INFORMATION or LOG_DATA);
          PagelogFileMgr.LogDataSaveToFile(lri^);
          Loger.Add('saveOne_ok:%.8x:%.8x:%.4x,n:%x',[lri^.lsn.lsn_1,lri^.lsn.lsn_2,lri^.lsn.lsn_3,Uint_ptr(lri^.n)], LOG_INFORMATION or LOG_DATA);
          tmpPtr := lri;
          lri := lri^.n;
          try
            _Lc_Free_PaddingData(tmpPtr);
          except
            on exc:Exception do
            begin
              Loger.Add('调用_Lc_Free_PaddingData失败！' + exc.Message, LOG_ERROR or LOG_IMPORTANT);
            end;
          end;
        end;
        Result := True;
      except
        on EEx:Exception do
        begin
          Loger.Add('savePageLog2 fail ' + EEx.Message, LOG_ERROR or LOG_IMPORTANT);
          Result := False;
        end;
      end;
    finally
      logs.Free;
    end;
  end;
end;

constructor TPagelogFileMgr.Create;
var
  Pathbuf: array[0..MAX_PATH + 2] of Char;
begin
  inherited;
  GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
  f_path := ExtractFilePath(string(Pathbuf)) + SsPath;
  ForceDirectories(f_path);
  dbids := TDbidCustomList.Create;

  FaddCS := TCriticalSection.Create;
end;

destructor TPagelogFileMgr.Destroy;
begin
  FaddCS.Free;
  dbids.Free;
  inherited;
end;

function TPagelogFileMgr.LogDataGetData(dbid: Word; lsn1, lsn2: DWORD; lsn3: WORD; data: TMemoryStream): Boolean;
var
  dbdiObj:TDBidObj;
  vlf:TVlfMgr;
begin
  Result := False;
  try
    if (dbId > 0) and (lsn1 > 0) then
    begin
      dbdiObj := dbids.GetObj(dbId);
      vlf := dbdiObj.GetObj(dbId, lsn1, f_path);
      Result := vlf.Get(lsn2, lsn3, data);
    end;
  except
    on e:Exception do
    begin
      Loger.Add(' LogDataGetData fail! ' + e.Message, LOG_ERROR);
    end;
  end;
end;

function TPagelogFileMgr.LogDataSaveToFile(Lri: TlogRecdItem): Boolean;
var
  dbdiObj:TDBidObj;
  vlf:TVlfMgr;
begin
  Loger.Add('...LogDataSaveToFile.......');
  Result := False;
  try
    if (Lri.dbId > 0) and (Lri.lsn.lsn_1 > 0) then
    begin
      Loger.Add('...LogDataSaveToFile...1....');
      dbdiObj := dbids.GetObj(Lri.dbId);
      Loger.Add('...LogDataSaveToFile...2....');
      vlf := dbdiObj.GetObj(Lri.dbId, Lri.lsn.lsn_1, f_path);
      Loger.Add('...LogDataSaveToFile...3....');
      Result := vlf.Save(Lri);
      Loger.Add('...LogDataSaveToFile...4....');
    end;
    Loger.Add('...LogDataSaveToFile...5....');
  except
    on e:Exception do
    begin
      Loger.Add(' LogDataSaveToFile fail! ' + e.Message, LOG_ERROR);
    end;
  end;
  Loger.Add('...LogDataSaveToFile...EEE....');
end;

{ TDbidCustomList }

procedure TDbidCustomList.Add(idx: NativeInt; AData: Pointer);
begin
  FsCS.Enter;
  try
    FIdxs.Add(Pointer(idx));
    FObjs.Add(AData);
  finally
    FsCS.Leave;
  end;
end;

constructor TDbidCustomList.Create;
begin
  FsCS := TCriticalSection.Create;
  FIdxs := TList.Create;
  FObjs := TObjectList.Create
end;

destructor TDbidCustomList.Destroy;
begin
  FObjs.Free;
  FIdxs.Free;
  FsCS.Free;
  inherited;
end;

function TDbidCustomList.GetObj(idx: NativeInt): TDBidObj;
var
  I: Integer;
begin
  Result := nil;
  FsCS.Enter;
  try
    for I := FIdxs.Count - 1 downto 0 do
    begin
      if NativeInt(FIdxs[I]) = idx then
      begin
        Result := TDBidObj(FObjs[I]);
        Break;
      end;
    end;
    if Result = nil then
    begin
      Result := TDBidObj.Create;
      Add(idx, Result);
      //TODO:这里删除不使用的
    end;
  finally
    FsCS.Leave;
  end;
end;

procedure TDbidCustomList.Remove(idx: NativeInt);
var
  I:Integer;
begin
  FsCS.Enter;
  try
    for I := FIdxs.Count - 1 downto 0 do
    begin
      if NativeInt(FIdxs[I]) = idx then
      begin
        FObjs.Delete(i);
        FIdxs.Delete(i);
        Break;
      end;
    end;
  finally
    FsCS.Leave;
  end;
end;

{ TDBidObj }

function TDBidObj.GetObj(dbid: Word; lsn1: DWORD; slogPath: string): TVlfMgr;
var
  I: Integer;
begin
  Result := nil;
  FsCS.Enter;
  try
    for I := FIdxs.Count - 1 downto 0 do
    begin
      if NativeInt(FIdxs[I]) = lsn1 then
      begin
        Result := TVlfMgr(FObjs[I]);
        Break;
      end;
    end;
    if Result = nil then
    begin
      Result := TVlfMgr.Create(dbid, lsn1, slogPath);
      Add(lsn1, Result);
      //TODO:这里删除不使用的
    end;
  finally
    FsCS.Leave;
  end;

end;

{ TVlfMgr }

constructor TVlfMgr.Create(dbid: Word; lsn1: DWORD; slogPath: string);
var
  tmpFilePath:string;
begin
  Fdbid := dbid;
  ReqNo := lsn1;
  Handle_IdxFile := 0;
  Handle_DataFile := 0;

  tmpFilePath := slogPath + IntToStr(dbid) + '\' + IntToStr(lsn1) + '\';
  ForceDirectories(tmpFilePath);

  Handle_IdxFile := CreateFile(PChar(tmpFilePath+'1.idx'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED, 0);
  if Handle_IdxFile = INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！' + syserrormessage(GetLastError) + ':' + tmpFilePath + '1.idx', LOG_ERROR);
    loger.Add('之后采集数据将输出到本日志文件！');
  end;

  Handle_DataFile := CreateFile(PChar(tmpFilePath+'1.data'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED, 0);
  if Handle_DataFile = INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！' + syserrormessage(GetLastError) + ':' + tmpFilePath + '1.data');
    loger.Add('之后采集数据将输出到本日志文件！');
  end;
  idxObj := TLidxMgr.Create(Handle_IdxFile, Self);
end;

destructor TVlfMgr.Destroy;
begin
  idxObj.Free;
  if Handle_IdxFile <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(Handle_IdxFile);
  end;

  if Handle_DataFile <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(Handle_DataFile);
  end;
  inherited;
end;

function TVlfMgr.Get(lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
var
  UniId:Int64;
  DataOffset:UInt64; 
  DataLen:Word;
  Rsize:Cardinal;  
begin
  Result := False;
  UniId := (lsn2 shl 16) or lsn3;
  if UniId > 0 then
  begin
    if idxObj.get(UniId, DataOffset) then
    begin
      DataLen := (DataOffset shr 48) and $FFFF;
      DataOffset := DataOffset and $FFFFFFFFFFFF;
      if DataLen > 0 then
      begin
        data.Size := DataLen;
        if ReadFile_OverLapped(Handle_DataFile, data.Memory^, DataLen, Rsize, DataOffset) and (Rsize > 0) then
        begin
          Result := True;
        end;
      end;
    end;
  end;
end;

function TVlfMgr.Save(Lri: TlogRecdItem): Boolean;
var
  OutPutStr:string;
  TmpDataStr:string;
  lsize:LARGE_INTEGER;
  Rsize:Cardinal;

  UniId:UInt64;
begin
  Result := False;
  if (Handle_IdxFile = INVALID_HANDLE_VALUE) or (Handle_DataFile = INVALID_HANDLE_VALUE) then
  begin
    //如果日志输出文件打开失败，将数据直接输出到日志，
    OutPutStr := '<Root>';
    OutPutStr := OutPutStr + Format('<dbid>%d</dbid>', [fdbid]);
    OutPutStr := OutPutStr + Format('<lsn1>%d</lsn1>', [ReqNo]);
    OutPutStr := OutPutStr + Format('<lsn2>%d</lsn2>', [Lri.lsn.lsn_2]);
    OutPutStr := OutPutStr + Format('<lsn3>%d</lsn3>', [Lri.lsn.lsn_3]);
    TmpDataStr := DumpMemory2Str(Lri.val, Lri.length);
    OutPutStr := OutPutStr + '<data>' + TmpDataStr + '</data></root>';
    //TODO:输出到日志的数据是否需要加密？
    Loger.Add(OutPutStr, LOG_DATA or LOG_IMPORTANT);
    Result := False;
    Exit;
  end;

  UniId := (UInt64(Lri.lsn.lsn_2) shl 16) or Lri.lsn.lsn_3;
  if UniId > 0 then
  begin
    lsize.QuadPart := 0;
    SetFilePointerEx(Handle_DataFile, 0, @lsize, soFromEnd);
    WriteFile_OverLapped(Handle_DataFile, Lri.val^, Lri.length, Rsize, lsize.QuadPart, True);

    lsize.HighPart := Cardinal(lsize.HighPart) or ((Lri.length and $FFFF) shl 16);
    idxObj.add(UniId, lsize.QuadPart);
    Result := True;
  end;
end;

{ TLidxMgr }
procedure TLidxMgr.addOutOfBuf(_key, _offset: UInt64);
const
  _10MB_ = 10*1024*1024;
var
  IdxBuf:Pointer;
  IdxBufPosi:Cardinal;
  Pli:PLidxItem;
  Rsize,RRsize:Cardinal;
  tmpIdx:Cardinal;
  wSize, RwSize:Cardinal;
  IdxfileSize:Cardinal;
  WwwBuf:Pointer;
begin
  IdxBuf := GetMemory(BUFMAXSIZE);
  try
    IdxBufPosi := WbuffPosi;
    Pli := nil;
    while True do
    begin
      if Uint_Ptr(Pli) < Uint_Ptr(IdxBuf) then
      begin
        //Reload
        if Uint_Ptr(IdxBufPosi)+_10MB_ < Uint_Ptr(WbuffPosi) then
        begin
          //最大深度10MB，超过了，的直接丢弃！
          Loger.Add('Idx 最大深度10MB，跳过了当前内容 !db:%d,RNo:%d', [TVlfMgr(Fvlf).Fdbid, TVlfMgr(Fvlf).ReqNo], LOG_ERROR);
          Exit;
        end;

        if IdxBufPosi > BUFMAXSIZE then
        begin
          IdxBufPosi := IdxBufPosi - BUFMAXSIZE;
          Rsize := BUFMAXSIZE;
        end else begin
          Rsize := IdxBufPosi;
          IdxBufPosi := 0;
        end;

        if not ReadFile_OverLapped(FHandle, IdxBuf^, Rsize, RRsize, IdxBufPosi) then
        begin
          Loger.Add('Idx 读取失败，跳过了当前内容!db:%d,RNo:%d', [TVlfMgr(Fvlf).Fdbid, TVlfMgr(Fvlf).ReqNo], LOG_ERROR);
          Exit;
        end;
        Pli := Pointer(Uint_Ptr(IdxBuf) + Rsize - SizeOf(TLidxItem)); //选中最后一个
      end;

      if Pli.HHH = 0 then
      begin
        if IdxBufPosi<$100 then
        begin
          //到首行
          tmpIdx := $100;
          Break;
        end else begin
          //文件损坏
          Loger.Add('Idx文件损坏!db:%d,RNo:%d', [TVlfMgr(Fvlf).Fdbid, TVlfMgr(Fvlf).ReqNo], LOG_ERROR);
          //TODO:修复！？
          Exit;
        end;
      end else
      if Pli.HHH = _key then
      begin
        //不可能相等吧(重复数据)
        Exit;
      end
      else if Pli.HHH > _key then
      begin
        //继续查找前一个
      end
      else
      begin
        tmpIdx := Uint_Ptr(Pli) - Uint_Ptr(IdxBuf) + SizeOf(TLidxItem);
        Break;
      end;
      Dec(Pli);
    end;
    IdxfileSize := GetFileSize(FHandle, nil);

    wSize := IdxfileSize - IdxBufPosi - tmpIdx + SizeOf(TLidxItem);
    if wSize < _10MB_ then
    begin
      WwwBuf := GetMemory(wSize);
      PLidxItem(WwwBuf)^.HHH := _key;
      PLidxItem(WwwBuf)^.LLL := _offset;
      if ReadFile_OverLapped(FHandle, Pointer(Uint_Ptr(WwwBuf) + SizeOf(TLidxItem))^, wSize, RRsize, IdxBufPosi + tmpIdx) then
      begin
        WriteFile_OverLapped(FHandle, WwwBuf^, wSize, RwSize, IdxBufPosi + tmpIdx);
      end;
      FreeMemory(WwwBuf);

      WbuffPosi := WbuffPosi + SizeOf(TLidxItem);
    end;
  finally
    FreeMemory(IdxBuf);
  end;
end;

procedure TLidxMgr.add(_key, _offset: UInt64);
var
  tmpIdx:Cardinal;
  Pli:PLidxItem;
  wSize, RwSize:Cardinal;
  TmpMem:Pointer;
begin
  if WbuffLen + SizeOf(TLidxItem) > BUFMAXSIZE then
  begin
    //缓冲区满，削减三分之一
    wSize := ((BUFMAXSIZE div SizeOf(TLidxItem)) div 3) * SizeOf(TLidxItem);
    Move(Pointer(Uint_Ptr(Wbuff) + wSize)^, Wbuff^, BUFMAXSIZE - wSize);
    WbuffLen := WbuffLen - wSize;
    WbuffPosi := WbuffPosi + wSize;
  end;

  Pli := Pointer(Uint_Ptr(Wbuff) + WbuffLen - SizeOf(TLidxItem)); //选中最后一个
  while True do
  begin
    if Pli.HHH = 0 then
    begin
      if WbuffPosi<$100 then
      begin
        //到首行
        tmpIdx := $100;
        Break;
      end else begin
        //文件损坏
        Loger.Add('Idx文件损坏!db:%d,RNo:%d', [TVlfMgr(Fvlf).Fdbid, TVlfMgr(Fvlf).ReqNo], LOG_ERROR);
        //TODO:修复！？
        Exit;
      end;
    end else
    if Pli.HHH = _key then
    begin
      //不可能相等吧(重复数据)
      Exit;
    end
    else if Pli.HHH > _key then
    begin
      //继续查找前一个
    end
    else
    begin
      tmpIdx := Uint_Ptr(Pli) - Uint_Ptr(Wbuff) + SizeOf(TLidxItem);
      Break;
    end;
    Dec(Pli);
    if Uint_Ptr(Pli) < Uint_Ptr(Wbuff) then
    begin
      //TODO:搜索完缓冲区。任然没有找到，继续向前读取
      addOutOfBuf(_key, _offset);
      Exit;
    end;
  end;
  if tmpIdx >= WbuffLen then
  begin
    //append
    PLidxItem(Uint_Ptr(Wbuff) + tmpIdx)^.HHH := _key;
    PLidxItem(Uint_Ptr(Wbuff) + tmpIdx)^.LLL := _offset;
    wSize := SizeOf(TLidxItem);
  end else begin
    //insert
    wSize := WbuffLen - tmpIdx + SizeOf(TLidxItem);
    TmpMem := GetMemory(wSize);
    PLidxItem(TmpMem)^.HHH := _key;
    PLidxItem(TmpMem)^.LLL := _offset;
    Move(Pointer(Uint_Ptr(Wbuff) + tmpIdx)^, Pointer(Uint_Ptr(TmpMem) + SizeOf(TLidxItem))^, wSize - SizeOf(TLidxItem));
    Move(TmpMem^, Pointer(Uint_Ptr(Wbuff) + tmpIdx)^, wSize);
    FreeMemory(TmpMem);
  end;
  WbuffLen := WbuffLen + SizeOf(TLidxItem);
  WriteFile_OverLapped(FHandle, Pointer(Uint_Ptr(Wbuff) + tmpIdx)^, wSize, RwSize, WbuffPosi + tmpIdx);
end;

function TLidxMgr.get(_key: UInt64; out _offset: UInt64): Boolean;
var
  RBuf:Pointer;
  RBufLen:Cardinal;
  RBufPosi:Cardinal;
  Pli:PLidxItem; 
  Rsize,RRsize:Cardinal; 
begin
  _offset := 0; 
  Result := False;
  RBuf := GetMemory(BUFMAXSIZE);
  try
    RBufLen := WbuffLen;
    RBufPosi := WbuffPosi;
    Move(Wbuff^, RBuf^, BUFMAXSIZE);
    Pli := Pointer(Uint_Ptr(RBuf) + RBufLen - SizeOf(TLidxItem));
    while True do
    begin
      if Uint_Ptr(Pli) < Uint_Ptr(RBuf) then
      begin
        //Reload
        if RBufPosi > BUFMAXSIZE then
        begin
          RBufPosi := RBufPosi - BUFMAXSIZE;
          Rsize := BUFMAXSIZE;
        end else begin
          Rsize := RBufPosi;
          RBufPosi := 0;
        end;

        if not ReadFile_OverLapped(FHandle, RBuf^, Rsize, RRsize, RBufPosi) then
        begin
          Exit;
        end;
        Pli := Pointer(Uint_Ptr(RBuf) + Rsize - SizeOf(TLidxItem));
      end;

      if Pli.HHH = _key then
      begin
        //找到
        _offset := Pli.LLL;
        Result := True;
        Break;
      end
      else if Pli.HHH > _key then
      begin
        //继续查找前一个
      end
      else
      begin
        //没有找到        
        Break;
      end;
      Dec(Pli);
    end;   
  finally
    FreeMemory(RBuf);
  end;
end;

constructor TLidxMgr.Create(IdxHandle: THandle; vlf:TObject);
var
  fsize:Cardinal;
  RRsize:Cardinal;
begin
  Fvlf := vlf;
  FHandle := IdxHandle;
  Wbuff := GetMemory(BUFMAXSIZE);
  WbuffLen := 0;
  WbuffPosi := 0;
  //读取已有文件
  fsize := GetFileSize(FHandle, nil);
  if fsize > BUFMAXSIZE then
  begin
    //太大的，直接先读
    WbuffPosi := fsize - BUFMAXSIZE;
  end;
  if not ReadFile_OverLapped(FHandle, Wbuff^, BUFMAXSIZE, RRsize, WbuffPosi) then
  begin
    Loger.Add('无法读取索引文件！db:%d,RNo:%d', [TVlfMgr(Fvlf).Fdbid, TVlfMgr(Fvlf).ReqNo], LOG_ERROR);
  end else begin
    if RRsize = 0 then
    begin
      // CreateFile
      WbuffLen := $100;
      ZeroMemory(Wbuff, $100);
      Move(IdxFileHeader[0], Wbuff^, Length(IdxFileHeader));
      WriteFile_OverLapped(FHandle, Wbuff^, $100, RRsize, 0)
    end else begin
      WbuffLen := RRsize;
    end;
  end;
end;

destructor TLidxMgr.Destroy;
begin
  FreeMem(Wbuff);
  inherited;
end;

{ TloopSaveMgr }

constructor TloopSaveMgr.Create;
begin
  inherited Create(False);
  //FreeOnTerminate := True;        //TODO:这里如果设置自动释放，停止时会引发错误： Thread Error: 句柄无效。 (6)
  Self.NameThreadForDebugging('TloopSaveMgr', Self.ThreadID);
end;

destructor TloopSaveMgr.Destroy;
begin

  inherited;
end;

procedure TloopSaveMgr.Execute;
var
  I:Integer;
begin
  while not Terminated do
  begin
    try
     // Loger.Add('ontimer...', LOG_INFORMATION or LOG_DATA);
      PageLog_save;
    except
      on eee:Exception do
      begin
        Loger.Add('TloopSaveMgr.Execute fail ' + eee.Message, LOG_ERROR or LOG_IMPORTANT);
      end;
    end;
    //2S
    for I := 0 to 20 - 1 do
    begin
      Sleep(100);
      if Terminated then
      begin
        Break;
      end;
    end;
  end;
  loopSaveMgr := nil;
end;

initialization
  PagelogFileMgr := TPagelogFileMgr.Create;
  loopSaveMgr := nil;
  
finalization
  PagelogFileMgr.Free;

end.

