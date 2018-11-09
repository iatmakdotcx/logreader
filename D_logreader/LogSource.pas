unit LogSource;

interface

uses
  I_LogProvider, databaseConnection, p_structDefine, Types,
  System.Classes, System.SyncObjs, System.Contnrs, loglog, I_LogSource;

type
   TLogPicker = class(TThread)

   public
     function GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;virtual;abstract;
   end;

type
  LS_STATUE = (tLS_unknown, tLS_NotConfig, tLS_NotConnectDB, tLs_noLogReader, tLS_running, tLS_stopped, tLS_suspension);

type
  TLogSource = class(TLogSourceBase)
  private
    FCfgFilePath:string;
    FRunCs: TCriticalSection;
    FmsgCs:TCriticalSection;
    procedure ClrLogSource;
    procedure ReSetLoger;
  public
    FFmsg: TStringList;
    FProcCurLSN: Tlog_LSN;  //当前处理的位置

    Fdbc: TdatabaseConnection;
    FLogPicker:TLogPicker;
    FisLocal:Boolean;
    FFFFIsDebug:Boolean;
    pageDatalist:TObjectList;
    MainMSGDISPLAY:TMsgCallBack;
    constructor Create;
    destructor Destroy; override;
    function GetVlf_SeqNo(SeqNo:DWORD): PVLF_Info;
    function GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
    function Create_picker:Boolean;
    procedure Stop_picker;
    function status:LS_STATUE;

    function loadFromFile(aPath: string):Boolean;
    function saveToFile(aPath: string = ''):Boolean;

    /// <summary>
    ///
    /// </summary>
    /// <param name="ExistsRenew">如果已存在，释放。重新创建</param>
    /// <returns></returns>
    function CreateLogReader(ExistsRenew:Boolean = False):Boolean;
    /// <summary>
    /// 从数据库对比字典差异
    /// </summary>
    /// <returns></returns>
    function CompareDict:string;
    procedure AddFmsg(aMsg: string; level: Integer);

    /// <summary>
    /// 监测数据库状态，如果在线则连接，如果不在线，等待上线后连接。
    /// </summary>
    procedure CreateAutoStartTimer;
  end;

  TLogSourceList = class(TObject)
  private
    ObjList:TList;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Item: TLogSource): Integer;
    function Get(Index: Integer): TLogSource;
    function Count: Integer;
    procedure Delete(Index: Integer);
    function Exists(Item: TLogSource):Boolean;
  end;


var
  LogSourceList:TLogSourceList;

implementation

uses
  LocalDbLogProvider, MakCommonfuncs,
  Windows, SysUtils;

{ TLogSource }

procedure TLogSource.AddFmsg(aMsg: string; level: Integer);
begin
  FmsgCs.Enter;
  try
    FFmsg.Add(FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Now) + IntToStr(level) + ' >> ' + aMsg);
    if FFmsg.Count >= 100 then
    begin
      FFmsg.Delete(0);
    end;
  finally
    FmsgCs.Leave
  end;
  if Assigned(MainMSGDISPLAY) then
    MainMSGDISPLAY(aMsg, level);
end;

procedure TLogSource.ClrLogSource;
begin
  Stop_picker;
  if Fdbc <> nil then
    FreeAndNil(Fdbc);
end;

function TLogSource.CompareDict: string;
begin
  Result := Fdbc.CompareDict;
end;

constructor TLogSource.Create;
begin
  FmsgCs:=TCriticalSection.Create;
  MainMSGDISPLAY := nil;
  inherited;
  FLoger := DefLoger;
  FProcCurLSN.LSN_1 := 0;
  FProcCurLSN.LSN_2 := 0;
  FProcCurLSN.LSN_3 := 0;
  FisLocal := True;
  Fdbc := nil;
  FLogPicker := nil;
  FRunCs:=TCriticalSection.Create;
  FFFFIsDebug := False;
  pageDatalist := nil;

  FFmsg := TStringList.Create;
end;

procedure TLogSource.CreateAutoStartTimer;
begin
  //TODO:测试数据库连接状态。启动前，应该先监测数据库状态。
  if Fdbc<>nil then
  begin


  end;
end;

function TLogSource.CreateLogReader(ExistsRenew:Boolean = False):Boolean;
begin
  ReSetLoger;
  Result := False;
  Fdbc.getDb_allLogFiles;
  if (Fdbc.dbVer_Major > 10) and (Fdbc.dbVer_Major <= 12) then
  begin
    //2008之后的版本都用这个读取方式
//    FLogReader := TSql2014LogReader.Create(Self);
    Result := True;
  end;
end;

function TLogSource.Create_picker: Boolean;
begin
  Result := False;
  if FProcCurLSN.LSN_1 = 0 then
  begin
    Loger.Add(' FProcCurLSN 为空启动logpicker失败');
    Exit;
  end
  else
  begin
    FRunCs.Enter;
    try
      if FLogPicker = nil then
      begin
//        FLogPicker := TSql2014LogPicker.Create(Self, FProcCurLSN);
        Result := True;
      end;
    finally
      FRunCs.Leave;
    end;
  end;
end;

destructor TLogSource.Destroy;
begin
  ClrLogSource;
  FRunCs.Free;
  pageDatalist.Free;
  if FLoger = DefLoger then
  begin
    Loger.removeCallBack(Self, AddFmsg);
  end else begin
    FLoger.Free;
  end;
  FFmsg.Free;
  FmsgCs.Free;
  inherited;
end;

function TLogSource.GetVlf_SeqNo(SeqNo:DWORD): PVLF_Info;
var
  I: Integer;
begin
  if Length(Fdbc.FVLF_List)=0 then
    Fdbc.getDb_VLFs;

  Result := nil;
  for I := 0 to Length(Fdbc.FVLF_List) - 1 do
  begin
    if Fdbc.FVLF_List[I].SeqNo = SeqNo then
    begin
      new(Result);
      Result^ := Fdbc.FVLF_List[I];
      Break;
    end;
  end;
end;

function TLogSource.GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
begin
  Result := FLogPicker.GetRawLogByLSN(LSN, OutBuffer);
end;

function TLogSource.status: LS_STATUE;
begin
  if Fdbc = nil then
  begin
    Result := tLS_NotConfig;
  end else if FLogPicker = nil then
  begin
    Result := tLS_stopped;
  end else
  begin
    Result := tLS_running;
  end;
end;

procedure TLogSource.ReSetLoger;
var
  newLog:String;
begin
  if Fdbc <> nil then
  begin
    if FLoger = DefLoger then
    begin
      Loger.removeCallBack(Self, AddFmsg);
    end else begin
      FLoger.Free;
    end;
    newLog := Fdbc.dbName + '_' + Fdbc.getCfgUid;
    Loger.Add('Log redirect ==> ' + newLog);
    FLoger := TeventRecorder.Create(newLog);
    Loger.registerCallBack(Self, AddFmsg);
  end;
end;

procedure TLogSource.Stop_picker;
begin
  if FLogPicker <> nil then
  begin
    FLogPicker.Terminate;
    FLogPicker.WaitFor;
    FLogPicker.Free;
    FLogPicker := nil;
  end;
end;

function TLogSource.loadFromFile(aPath: string):Boolean;
var
  mmo: TMemoryStream;
  Rter: TReader;
  tmpStr: string;
begin
  Result := False;
  ClrLogSource;

  mmo := TMemoryStream.Create;
  try
    try
      mmo.LoadFromFile(aPath);
      Rter := TReader.Create(mmo, 1);
      try
        if Rter.ReadInteger = $FB then
        begin
          tmpStr := Rter.ReadStr;
          if tmpStr = 'TDbDict v 1.0' then
          begin
            Fdbc := TdatabaseConnection.create(Self);
            Fdbc.Host := Rter.ReadString;
            Fdbc.user := Rter.ReadString;
            Fdbc.PassWd := Rter.ReadString;
            Fdbc.dbName := Rter.ReadString;
            Fdbc.dbID :=  Rter.ReadInteger;
            Fdbc.dbVer_Major :=  Rter.ReadInteger;
            Fdbc.dbVer_Minor :=  Rter.ReadInteger;
            Fdbc.dbVer_BuildNumber :=  Rter.ReadInteger;
            FProcCurLSN.LSN_1 := Rter.ReadInteger;
            FProcCurLSN.LSN_2 := Rter.ReadInteger;
            FProcCurLSN.LSN_3 := Rter.ReadInteger;
            Fdbc.dict.Deserialize(mmo);
            //init;
            Result := True;

            FCfgFilePath := aPath;
          end;
        end;
      finally
        Rter.Free;
      end;
    except
      on EE:Exception do
      begin
        Loger.Add('配置文件读取失败:'+aPath);
      end;
    end;
  finally
    mmo.Free;
  end;
end;

function TLogSource.saveToFile(aPath: string):Boolean;
var
  wter: TWriter;
  mmo: TMemoryStream;
  dictBin: TMemoryStream;
  pathName:string;
begin
  Result := False;
  if aPath = '' then
    aPath := FCfgFilePath;

  if aPath <> '' then
  begin
    FCfgFilePath := aPath;

    Result := False;
    mmo := TMemoryStream.Create;
    try
      wter := TWriter.Create(mmo, 1);
      wter.WriteInteger($FB);
      wter.WriteStr('TDbDict v 1.0');
      //连接信息
      wter.WriteString(Fdbc.Host);
      wter.WriteString(Fdbc.user);
      wter.WriteString(Fdbc.PassWd);
      wter.WriteString(Fdbc.dbName);
      wter.WriteInteger(Fdbc.dbID);
      wter.WriteInteger(Fdbc.dbVer_Major);
      wter.WriteInteger(Fdbc.dbVer_Minor);
      wter.WriteInteger(Fdbc.dbVer_BuildNumber);
      wter.WriteInteger(FProcCurLSN.LSN_1);
      wter.WriteInteger(FProcCurLSN.LSN_2);
      wter.WriteInteger(FProcCurLSN.LSN_3);
      //表结构
      dictBin := Fdbc.dict.Serialize;
      dictBin.seek(0, 0);
      wter.Write(dictBin.Memory^, dictBin.Size);
      dictBin.Free;
      //
      wter.FlushBuffer;
      wter.Free;

      pathName := ExtractFilePath(aPath);
      if not DirectoryExists(pathName) then
      begin
        Loger.Add('目录创建:' + BoolToStr(ForceDirectories(pathName), true) + ':' + pathName);
      end;

      try
        mmo.SaveToFile(aPath);
        Result := True;
      except
        on ee:Exception do
        begin
          Loger.Add('LogSource.saveToFile 配置保存失败！' + ee.message);
        end;
      end;
    finally
      mmo.Free;
    end;
  end;
end;

{ TLogSourceList }

function TLogSourceList.Exists(Item: TLogSource): Boolean;
var
  I:Integer;
begin
  for I := 0 to ObjList.Count - 1 do
  begin
    if (Get(I).Fdbc.Host = Item.Fdbc.Host) and
       (Get(I).Fdbc.dbName = Item.Fdbc.dbName) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TLogSourceList.Add(Item: TLogSource): Integer;
begin
  if not Exists(Item) then
  begin
    Result := ObjList.Add(Item);
  end else
    Result := -1;
end;

function TLogSourceList.Count: Integer;
begin
  Result := ObjList.Count;
end;

constructor TLogSourceList.Create;
begin
  ObjList := TList.Create;
end;

procedure TLogSourceList.Delete(Index: Integer);
begin
  ObjList.Delete(Index);
end;

destructor TLogSourceList.Destroy;
var
  I: Integer;
begin
  for I := 0 to ObjList.Count - 1 do
  begin
    TLogSource(ObjList[i]).free;
  end;
  ObjList.Free;
  inherited;
end;


function TLogSourceList.Get(Index: Integer): TLogSource;
begin
  Result := ObjList[Index];
end;

initialization
  LogSourceList := TLogSourceList.Create;

finalization
  LogSourceList.Free;

end.

