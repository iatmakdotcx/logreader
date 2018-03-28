unit LogSource;

interface

uses
  I_LogProvider, I_logReader, databaseConnection, p_structDefine, Types,
  System.Classes;

type
  LS_STATUE = (tLS_unknown, tLS_NotConfig, tLs_notInit, tLS_running, tLS_stopped, tLS_suspension);

type
  TLogSource = class(TObject)
  private
    Fstatus:LS_STATUE;
    procedure ClrLogSource;
    function init: Boolean;
  public
    FLogReader: TlogReader;
    Fdbc: TdatabaseConnection;
    FLogPicker:TLogPicker;
    constructor Create;
    destructor Destroy; override;
    function SetConnection(dbc: TdatabaseConnection): Boolean;
    function GetVlf_LSN(LSN: Tlog_LSN): PVLF_Info;
    function GetVlf_SeqNo(SeqNo:DWORD): PVLF_Info;
    function GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
    function Create_picker(LSN: Tlog_LSN):Boolean;
    procedure Stop_picker;
    function status:LS_STATUE;
    //test func
    procedure listVlfs;
    procedure listLogBlock(SeqNo:DWORD);
    procedure cpyFile(fileid:Byte;var OutBuffer: TMemory_data);
    function init_Process(Pid, hdl: Cardinal): Boolean;
    procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);

    function loadFromFile(aPath: string):Boolean;
    function saveToFile(aPath: string):Boolean;
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
  end;


var
  LogSourceList:TLogSourceList;

implementation

uses
  LdfLogProvider, Sql2014LogReader, LocalDbLogProvider, MakCommonfuncs,
  Windows, pluginlog, SysUtils;

{ TLogSource }

procedure TLogSource.ClrLogSource;
begin
  Stop_picker;
  if Fdbc <> nil then
    FreeAndNil(Fdbc);
  if FLogReader <> nil then
    FreeAndNil(FLogReader);
end;

procedure TLogSource.cpyFile(fileid:Byte;var OutBuffer: TMemory_data);
begin
  FLogReader.custRead(fileid,0,-1,OutBuffer);
end;

constructor TLogSource.Create;
begin
  inherited;
  Fstatus := tLS_NotConfig;
end;

function TLogSource.Create_picker(LSN: Tlog_LSN): Boolean;
begin
  FLogPicker := TSql2014LogPicker.Create(Self, LSN);
  Result := True;
end;

destructor TLogSource.Destroy;
begin
  ClrLogSource;
  inherited;
end;

function TLogSource.GetVlf_LSN(LSN: Tlog_LSN): PVLF_Info;
begin
  Result := GetVlf_SeqNo(LSN.LSN_1);
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
      Result := @Fdbc.FVLF_List[I];
      Break;
    end;
  end;
end;

function TLogSource.GetRawLogByLSN(LSN: Tlog_LSN;var OutBuffer: TMemory_data): Boolean;
var
  vlf:PVLF_Info;
begin
  vlf := GetVlf_LSN(LSN);
  Result := FLogReader.GetRawLogByLSN(LSN, vlf, OutBuffer);
end;

function TLogSource.SetConnection(dbc: TdatabaseConnection): Boolean;
begin
  ClrLogSource;
  Fdbc := dbc;
  result := init;
  Fdbc.refreshDict;
end;

function TLogSource.status: LS_STATUE;
begin
  Result := Fstatus;
end;

function TLogSource.init: Boolean;
begin
  Fdbc.refreshConnection;
  Fdbc.getDb_dbInfo;
  Fdbc.getDb_allLogFiles;

  if Fdbc.dbVer_Major > 10 then
  begin
    FLogReader := TSql2014LogReader.Create(Self);
    Fstatus := tLS_stopped;
    Result := True;
  end else begin
    Loger.Add('不支持的数据库版本！');
    Result := False;
  end;
end;

function TLogSource.init_Process(Pid, hdl: Cardinal): Boolean;
var
  localHandle: THandle;
begin
  localHandle := DuplicateHandleToCurrentProcesses(Pid, hdl);
  if localHandle <> 0 then
  begin
    FLogReader := TSql2014LogReader.Create(Self);
    Result := True;
  end
  else
  begin
    Result := False;
  end;
end;

procedure TLogSource.listLogBlock(SeqNo: DWORD);
begin
  if FLogReader <> nil then
  begin
    FLogReader.listLogBlock(GetVlf_SeqNo(SeqNo));
  end;
end;

procedure TLogSource.listVlfs;
begin
  if FLogReader <> nil then
    FLogReader.listVlfs(2);
end;

procedure TLogSource.NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
var
  rl : PRawLog;
begin
  if Raw.dataSize>0 then
  begin
    rl := Raw.data;
    loger.add(LSN2Str(lsn)+'==>'+inttostr(rl.fixedLen)+'==>'+inttostr(rl.OpCode));
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
            Fdbc := TdatabaseConnection.create;
            try
              Fdbc.Host := Rter.ReadString;
              Fdbc.user := Rter.ReadString;
              Fdbc.PassWd := Rter.ReadString;
              Fdbc.dbName := Rter.ReadString;
              Fdbc.dbID :=  Rter.ReadInteger;
              Fdbc.dbVer_Major :=  Rter.ReadInteger;
              Fdbc.dbVer_Minor :=  Rter.ReadInteger;
              Fdbc.dbVer_BuildNumber :=  Rter.ReadInteger;
              Fdbc.dict.Deserialize(mmo);
              //init;
              Fstatus := tLs_notInit;
              Result := True;
            except
              Fdbc.Free
            end;
          end;
        end;
      finally
        Rter.Free;
      end;
    except
      on EE:Exception do
      begin


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


{ TLogSourceList }

function TLogSourceList.Add(Item: TLogSource): Integer;
begin
  Result := ObjList.Add(Item);
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

