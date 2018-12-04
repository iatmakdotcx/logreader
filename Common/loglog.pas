unit loglog;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, LoggerPro;

const
  LOG_ERROR = 1;
  LOG_WARNING = 2;
  LOG_INFORMATION = 4;
  LOG_DEBUG = 8;
  LOG_DATA = $4000;
  LOG_IMPORTANT = $8000;
  WIN_EOL = #$D#$A;

type
  TMsgCallBack = procedure(aMsg: string; level: Integer)of object;

type
  TeventRecorder = class(TObject)
  private
    FcallBackLst: TList;
    lo4dLoger: ILogWriter;
    FEnableCallback: Boolean;
  public
    procedure Add(aMsg: string; level: Integer = LOG_INFORMATION); overload;
    procedure Add(aMsg: string; const Args: array of const; level: Integer = LOG_INFORMATION); overload;
    procedure AddException(aMsg: string; level: Integer = LOG_INFORMATION); overload;
    procedure AddException(aMsg: string; const Args: array of const; level: Integer = LOG_INFORMATION); overload;
    constructor Create(logName:string='');
    destructor Destroy; override;
    procedure registerCallBack(Obj:Tobject;afunc: TMsgCallBack);
    procedure removeCallBack(Obj:Tobject;afunc: TMsgCallBack);
    property EnableCallback: Boolean read FEnableCallback write FEnableCallback;
    procedure ClearLogEngine;
  end;

procedure finalLoger;

var
  DefLoger: TeventRecorder;

implementation

uses
  LoggerPro.FileAppender;

procedure TeventRecorder.Add(aMsg: string; level: Integer = LOG_INFORMATION);
var
  I: Integer;
  pm:PMethod;
begin
  if lo4dLoger=nil then
    Exit;

  if (level and LOG_DEBUG) > 0 then
  begin
    lo4dLoger.Debug(aMsg,'');
  end
  else if (level and LOG_ERROR) > 0 then
  begin
    lo4dLoger.Error(aMsg,'');
    level := level or LOG_IMPORTANT;
  end
  else if (level and LOG_WARNING) > 0 then
  begin
    lo4dLoger.Warn(aMsg,'');
  end
  else
  begin
    lo4dLoger.Info(aMsg,'');
  end;
  if (level and LOG_DATA) > 0 then
  begin
    if (level and LOG_DEBUG) > 0 then
    begin
      lo4dLoger.Debug(aMsg,'Data');
    end
    else if (level and LOG_ERROR) > 0 then
    begin
      lo4dLoger.Error(aMsg,'Data');
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dLoger.Warn(aMsg,'Data');
    end
    else
    begin
      lo4dLoger.Info(aMsg,'Data');
    end;
  end;
  if (level and LOG_IMPORTANT) > 0 then
  begin
    if (level and LOG_DEBUG) > 0 then
    begin
      lo4dLoger.Debug(aMsg,'Important');
    end
    else if (level and LOG_ERROR) > 0 then
    begin
      lo4dLoger.Error(aMsg,'Important');
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dLoger.Warn(aMsg,'Important');
    end
    else
    begin
      lo4dLoger.Info(aMsg,'Important');
    end;
  end;
  for I := 0 to FcallBackLst.Count - 1 do
  begin
    try
      pm := FcallBackLst[I];
      TMsgCallBack(pm^)(aMsg, level);
    except
    end;
  end;
end;

procedure TeventRecorder.Add(aMsg: string; const Args: array of const; level: Integer = LOG_INFORMATION);
begin
  Add(Format(aMsg, Args), level);
end;

procedure TeventRecorder.AddException(aMsg: string; level: Integer);
begin
  Add(aMsg, level);
  raise Exception.Create(aMsg);
end;

procedure TeventRecorder.AddException(aMsg: string; const Args: array of const; level: Integer);
begin
  AddException(Format(aMsg, Args), level)
end;

procedure TeventRecorder.ClearLogEngine;
begin
  lo4dLoger := nil;
end;

constructor TeventRecorder.Create(logName:string='');
var
  tmpLogPath:string;
  ModuleName:string;
begin
  inherited Create;
  FcallBackLst := TList.Create;
  ModuleName := GetModuleName(HInstance);
  tmpLogPath := ExtractFilePath(ModuleName) + 'logs\' + StringReplace(ExtractFileName(ModuleName), '.', '_', []);
  if logName <> '' then
    tmpLogPath := tmpLogPath + '\' + logName;
  lo4dLoger := BuildLogWriter([TLoggerProFileAppender.Create(10, Integer.MaxValue, tmpLogPath, [TFileAppenderOption.DateAsFileName, TFileAppenderOption.NoRotate])]);

  Add('eventRecorder init...');
end;

destructor TeventRecorder.Destroy;
var
  I: Integer;
begin
  for I := 0 to FcallBackLst.Count - 1 do
    Dispose(FcallBackLst[I]);
  FcallBackLst.Free;
  inherited Destroy;
  lo4dLoger := nil;
end;

procedure TeventRecorder.registerCallBack(Obj:Tobject; afunc: TMsgCallBack);
var
  pm:PMethod;
  I: Integer;
begin
  for I := 0 to FcallBackLst.Count - 1 do
  begin
    pm := PMethod(FcallBackLst[i]);
    if (pm.Code = Addr(afunc)) and (pm.Data = Obj) then
    begin
      Exit;
    end;
  end;
  New(pm);
  pm.Data := Obj;
  pm.Code := Addr(afunc);
  FcallBackLst.Add(pm);
end;

procedure TeventRecorder.removeCallBack(Obj:Tobject; afunc: TMsgCallBack);
var
  pm:PMethod;
  I: Integer;
begin
  for I := 0 to FcallBackLst.Count - 1 do
  begin
    pm := PMethod(FcallBackLst[i]);
    if (pm.Code = Addr(afunc)) and (pm.Data = Obj) then
    begin
      FcallBackLst.Delete(i);
    end;
  end;
end;

procedure InitLoger;
begin
  DefLoger := TeventRecorder.Create;
end;

procedure finalLoger;
begin
  DefLoger.Free;
end;

initialization
  InitLoger;

finalization
  finalLoger;

end.

