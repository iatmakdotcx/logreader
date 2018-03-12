unit LogSource;

interface

uses
  I_LogProvider, I_logReader, databaseConnection, p_structDefine, Types;

type
  TLogSource = class(TObject)
  private
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
    //test func
    procedure listVlfs;
    procedure listLogBlock(SeqNo:DWORD);
    procedure cpyFile(fileid:Byte;var OutBuffer: TMemory_data);
    function init_Process(Pid, hdl: Cardinal): Boolean;
    procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);

    procedure loadFromFile(aPath: string);
    procedure saveToFile(aPath: string);
  end;

implementation

uses
  LdfLogProvider, Classes, Sql2014LogReader, LocalDbLogProvider, MakCommonfuncs,
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

function TLogSource.init: Boolean;
begin
  Fdbc.refreshConnection;
  Fdbc.getDb_dbInfo;
  Fdbc.getDb_allLogFiles;

  if Fdbc.dbVer_Major > 10 then
  begin
    FLogReader := TSql2014LogReader.Create(Self);
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
  if FLogPicker<>nil then
  begin
    FLogPicker.Terminate;
    FLogPicker.WaitFor;
    FLogPicker.Free;
    FLogPicker := nil;
  end;
end;

procedure TLogSource.loadFromFile(aPath: string);
var
  mmo: TMemoryStream;
  Rter: TReader;
  tmpStr: string;
begin
  ClrLogSource;

  mmo := TMemoryStream.Create;
  try
    mmo.LoadFromFile(aPath);
    Rter := TReader.Create(mmo, 1);
    if Rter.ReadInteger = $FB then
    begin
      tmpStr := Rter.ReadStr;
      if tmpStr = 'TDbDict v 1.0' then
      begin
        Fdbc := TdatabaseConnection.create;
        Fdbc.Host := Rter.ReadString;
        Fdbc.user := Rter.ReadString;
        Fdbc.PassWd := Rter.ReadString;
        Fdbc.dbName := Rter.ReadString;
        Fdbc.dict.Deserialize(mmo);
        init;
      end;
    end;
    Rter.Free;
  finally
    mmo.Free;
  end;
end;

procedure TLogSource.saveToFile(aPath: string);
var
  wter: TWriter;
  mmo: TMemoryStream;
  dictBin: TMemoryStream;
begin
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
    //表结构
    dictBin := Fdbc.dict.Serialize;
    dictBin.seek(0, 0);
    wter.Write(dictBin.Memory^, dictBin.Size);
    dictBin.Free;
    //
    wter.FlushBuffer;
    wter.Free;
    mmo.SaveToFile(aPath);
  finally
    mmo.Free;
  end;
end;


end.

