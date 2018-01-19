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
    lsn3: array[0..0] of WORD;
    offse: array[0..0] of DWORD;
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
    dbid: Word;
    ReqNo: DWORD;

    cachelst: TList;
    IdxFile:THandle;
    DataFile:THandle;
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
  ReqNo.save(lsn2, logs, data);
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
  dbid := dbid;
  ReqNo := lsn1;
  IdxFile := 0;
  DataFile := 0;

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
  inherited;
end;

function TVlfMgr.Save(lsn2: WORD; logs: TList; data: TMemoryStream): Boolean;
var
  I, J: Integer;
  tmp: PIdxData;
  tmpLsn: ^TLSNBuffer;
begin
  if logs.Count > 0 then
  begin
    //先直接写入log到文件


    //先在cache里面找，如果没有找到，
    //小于cache里最小的，就到已保存的文件中找，
    //大于cache里最小的，新增cache内容，并保存最小的到文件
    for I := 0 to cachelst.Count - 1 do
    begin
      tmp := cachelst[I];
      if tmp.lsn2 = lsn2 then
      begin

        for J := 0 to logs.Count - 1 do
        begin
//          tmp.Size := tmp.Size + 1;
//          SetLength(tmp.offse, tmp.Size);
//          tmp.lsn3[tmp.Size - 1] := tmpLsn.lsn_3;

        end;

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

