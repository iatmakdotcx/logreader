unit logRecdItemSave;

interface

uses
  System.SyncObjs, System.Contnrs, Winapi.Windows, System.Classes, LidxMgr;

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
    function Add(AItem:NativeInt; AData: Pointer): NativeInt;
    property Data[AItem: NativeInt]: Pointer read GetData write SetData; default;
  end;

  TVlfMgr = class(TObject)
  private
    Fdbid: Word;
    ReqNo: DWORD;
    IdxFile:THandle;
    IdxFileCS:TCriticalSection;
    DataFile:THandle;
    DataFileCS:TCriticalSection;
    idxObj : TLidxMgr;
  public
    constructor Create(dbid: Word; lsn1: DWORD; slogPath: string);
    destructor Destroy; override;
    function Save(lsn2: DWORD; logs: TList; data: TMemoryStream): Boolean;
    function Get(lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
  end;

  TPagelogFileMgr = class(TObject)
  private
    const
      SsPath = 'data\';
    var
      f_path: string;
      dbids: TDbidCustomBucketList;
    procedure dbidsObjAction(AItem, AData: Pointer; out AContinue: Boolean);
    procedure VlfMgrObjAction(AItem, AData: Pointer; out AContinue: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    function LogDataSaveToFile(dbid: Word; lsn1: DWORD; lsn2: DWORD; logs: TList; data: TMemoryStream): Boolean;
    function LogDataGetData(dbid: Word; lsn1: DWORD; lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
  end;

  TloopSaveMgr = class(TThread)
  public
    procedure Execute; override;
    constructor Create;
    destructor Destroy; override;
  end;


function savePageLog2: Boolean;

var
  PagelogFileMgr: TPagelogFileMgr;
  loopSaveMgr: TloopSaveMgr;

implementation

uses
  pageCaptureDllHandler, System.SysUtils, loglog,Memory_Common;


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
  tmpPtr:Pointer;
begin
  if Assigned(_Lc_Get_PaddingDataCnt) and (_Lc_Get_PaddingDataCnt > 0) then
  begin
    logs := TList.create;
    mmData := TMemoryStream.Create;
    try
      try
        DataPnt := _Lc_Get_PaddingData;  //这里过来的值是顺序的
        lri := PlogRecdItem(DataPnt);
        prevDBid := 0;
        prevLsn.lsn_1 := 0;
        while lri <> nil do
        begin
          //分组。一次更新多行的优化
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
            prevDBid := lri.dbId;
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

          //释放lri

          tmpPtr := lri;
          lri := lri.n;

          try
            _Lc_Free_PaddingData(tmpPtr);
          except
            on exc:Exception do
            begin
              Loger.Add('调用_Lc_Free_PaddingData失败！' + exc.Message);
            end;
          end;
        end;
        if logs.Count > 0 then
        begin
          PagelogFileMgr.LogDataSaveToFile(prevDBid, prevLsn.lsn_1, prevLsn.lsn_2, logs, mmData);
          for I := 0 to logs.Count - 1 do
          begin
            tmpLsn := logs[I];
            Dispose(tmpLsn);
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
  GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
  f_path := ExtractFilePath(string(Pathbuf)) + SsPath;
  ForceDirectories(f_path);
  dbids := TDbidCustomBucketList.Create;
end;

destructor TPagelogFileMgr.Destroy;
begin
  dbids.ForEach(dbidsObjAction);
  dbids.Clear;
  dbids.Free;
  inherited;
end;

procedure TPagelogFileMgr.VlfMgrObjAction(AItem, AData: Pointer; out AContinue: Boolean);
begin
  TVlfMgr(AData).free;
end;

procedure TPagelogFileMgr.dbidsObjAction(AItem, AData: Pointer; out AContinue: Boolean);
begin
  TDbidCustomBucketList(AData).ForEach(VlfMgrObjAction);
  TDbidCustomBucketList(AData).Free;
end;

function TPagelogFileMgr.LogDataGetData(dbid: Word; lsn1, lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
var
  DB: TDbidCustomBucketList;
  ReqNo: TVlfMgr;
begin
  Result := false;
  try
    if (dbid > 0) and (lsn1 > 0) then
    begin
      DB := dbids[dbid];
      if DB = nil then
      begin
        DB := TDbidCustomBucketList.Create;
        dbids.Add(dbid, DB);
      end;
      ReqNo := DB[lsn1];
      if ReqNo = nil then
      begin
        ReqNo := TVlfMgr.Create(dbid, lsn1, f_path);
        DB.Add(lsn1, ReqNo)
      end;
      Result := ReqNo.Get(lsn2, lsn3, data);
    end;
  except
    on dd:Exception do
    begin
      Loger.Add('TPagelogFileMgr.LogDataGetData  >> '+ dd.Message);
    end;
  end;
end;

function TPagelogFileMgr.LogDataSaveToFile(dbid: Word; lsn1: DWORD; lsn2: DWORD; logs: TList; data: TMemoryStream): Boolean;
var
  DB: TDbidCustomBucketList;
  ReqNo: TVlfMgr;
begin
  if (dbid > 0) and (lsn1 > 0) then
  begin
    DB := dbids[dbid];
    if DB = nil then
    begin
      DB := TDbidCustomBucketList.Create;
      dbids.Add(dbid, DB);
    end;
    ReqNo := DB[lsn1];
    if ReqNo = nil then
    begin
      ReqNo := TVlfMgr.Create(dbid, lsn1, f_path);
      DB.Add(lsn1, ReqNo)
    end;
    Result := ReqNo.Save(lsn2, logs, data);
  end else begin
    Result := false;
  end;
end;

{ TDbidCustomBucketList }

function TDbidCustomBucketList.Add(AItem:NativeInt; AData: Pointer): NativeInt;
begin
  Result := IntPtr(inherited Add(Pointer(AItem), AData));
end;

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
  Fdbid := dbid;
  ReqNo := lsn1;
  IdxFile := 0;
  DataFile := 0;

  IdxFileCS := TCriticalSection.Create;
  DataFileCS := TCriticalSection.Create;

  tmpFilePath := slogPath + IntToStr(dbid) + '\' + IntToStr(lsn1) + '\';

  ForceDirectories(tmpFilePath);

  IdxFile := CreateFile(PChar(tmpFilePath+'1.idx'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if IdxFile = INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！'+syserrormessage(GetLastError)+':'+tmpFilePath+'1.idx',LOG_ERROR);
    loger.Add('之后采集数据将输出到本日志文件！');
  end;

  DataFile := CreateFile(PChar(tmpFilePath+'1.data'), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ,
          nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if DataFile = INVALID_HANDLE_VALUE then
  begin
    loger.Add('创建文件失败！'+syserrormessage(GetLastError)+':'+tmpFilePath+'1.data');
    loger.Add('之后采集数据将输出到本日志文件！');
  end;

  idxObj := TLidxMgr.Create(IdxFile);
  idxObj.initCheck;
end;

destructor TVlfMgr.Destroy;
begin
  idxObj.Free;

  CloseHandle(IdxFile);
  CloseHandle(DataFile);

  IdxFileCS.Free;
  DataFileCS.Free;
  inherited;
end;

function TVlfMgr.Get(lsn2: DWORD; lsn3: WORD; var data: TMemoryStream): Boolean;
var
  dOffset:UInt64;
  buf:Pointer;
  DataSize,Rsize:Cardinal;
begin
  Result := false;
  if idxObj.findRow(lsn2,lsn3,dOffset) then
  begin
    buf := GetMemory($2000);
    try
      SetFilePointerEx(DataFile, dOffset, nil, soFromBeginning);
      if ReadFile(DataFile, buf^, $2000, Rsize, nil) and (Rsize >0) then
      begin
        DataSize := PDWORD(buf)^;
        if DataSize>$2000 then
        begin
          Loger.Add('TVlfMgr.Get 日志错误,行数据过大。', LOG_ERROR);
          exit;
        end else begin
          data.Write(PDWORD(UIntPtr(buf)+4)^, DataSize);
          data.Seek(0, 0);
          Result := True;
        end;
      end else begin
        Loger.Add('TVlfMgr.Get：%d,%d 读取数据失败',[lsn2,lsn3], LOG_ERROR);
      end;
    finally
      FreeMemory(buf);
    end;
  end else begin
    Loger.Add('TVlfMgr.Get：%d,%d 查找行数据失败',[lsn2,lsn3], LOG_ERROR);
  end;
end;

function TVlfMgr.Save(lsn2: DWORD; logs: TList; data: TMemoryStream): Boolean;
var
  J: Integer;
  tmpLsn: ^TLSNBuffer;
  lsize:LARGE_INTEGER;
  Rsize:DWORD;
  OutPutStr:string;
  TmpDataStr:string;
begin
  if logs.Count > 0 then
  begin
    if ((IdxFile + 1) = 0) or ((DataFile + 1) = 0) then
    begin
      //如果日志输出文件打开失败，将数据直接输出到日志，
      OutPutStr := '<Root>';
      OutPutStr := OutPutStr + Format('<dbid>%d</dbid>', [fdbid]);
      OutPutStr := OutPutStr + Format('<lsn1>%d</lsn1>', [ReqNo]);
      OutPutStr := OutPutStr + Format('<lsn2>%d</lsn2>', [lsn2]);
      OutPutStr := OutPutStr+'<idx>';
      for J := 0 to logs.Count - 1 do
      begin
        tmpLsn := logs[J];
        OutPutStr := OutPutStr + '<row>';
        OutPutStr := OutPutStr + Format('<lsn3>%d</lsn3>', [tmpLsn.lsn_3]);
        OutPutStr := OutPutStr + Format('<Offset>%d</Offset>', [tmpLsn.Offset]);
        OutPutStr := OutPutStr + '</row>';
      end;
      OutPutStr := OutPutStr + '</idx><data>';
      TmpDataStr := bytestostr(data.Memory, data.Size, $FFFFFFFF, False, False);
      TmpDataStr := StringReplace(TmpDataStr, ' ', '', [rfReplaceAll]);
      OutPutStr := OutPutStr + TmpDataStr + '</data></root>';
      //TODO:输出到日志的数据是否需要加密？
      Loger.Add(OutPutStr, LOG_DATA or LOG_IMPORTANT);
      Result := False;
      Exit;
    end;

    //先直接写入log到文件
    DataFileCS.Enter;
    try
      lsize.QuadPart := 0;
      SetFilePointerEx(DataFile, 0, @lsize, soFromEnd);
      WriteFile(DataFile, data.Memory^, data.Size, Rsize, nil);
    finally
      DataFileCS.Leave;
    end;

    IdxFileCS.Enter;
    try
      idxObj.writeRow(lsn2, logs, lsize)
    finally
      IdxFileCS.Leave;
    end;
  end;
  Result := True;
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
      savePageLog2;
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

