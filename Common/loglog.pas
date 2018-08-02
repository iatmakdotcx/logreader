unit loglog;

interface

uses
  Windows, Classes, SysUtils, SyncObjs, Log4D;

const
  LOG_ERROR = 1;
  LOG_WARNING = 2;
  LOG_INFORMATION = 4;
  LOG_DEBUG = 8;
  LOG_DATA = $4000;
  LOG_IMPORTANT = $8000;
  WIN_EOL = #$D#$A;

type
  TMsgCallBack = procedure(aMsg: string; level: Integer);

type
  TeventRecorder = class(TObject)
  private
    FcallBackLst: TList;
    lo4dLoger: TLogLogger;
    lo4dData: TLogLogger;
    lo4dImportant: TLogLogger;
  public
    procedure Add(aMsg: string; level: Integer = LOG_INFORMATION); overload;
    procedure Add(aMsg: string; const Args: array of const; level: Integer = LOG_INFORMATION); overload;
    procedure AddException(aMsg: string; level: Integer = LOG_INFORMATION); overload;
    procedure AddException(aMsg: string; const Args: array of const; level: Integer = LOG_INFORMATION); overload;
    constructor Create;
    destructor Destroy; override;
    procedure registerCallBack(afunc: TMsgCallBack);
    procedure removeCallBack(afunc: TMsgCallBack);
  end;

procedure finalLoger;

var
  Loger: TeventRecorder;

implementation
uses
  System.Types;

procedure TeventRecorder.Add(aMsg: string; level: Integer = LOG_INFORMATION);
var
  I: Integer;
  ff: TMsgCallBack;
begin
  if (level and LOG_DEBUG) > 0 then
  begin
    lo4dLoger.Debug(aMsg);
  end
  ELSE if (level and LOG_ERROR) > 0 then
  begin
    lo4dLoger.Error(aMsg);
  end
  else if (level and LOG_WARNING) > 0 then
  begin
    lo4dLoger.Warn(aMsg);
  end
  else if (level and LOG_INFORMATION) > 0 then
  begin
    lo4dLoger.Info(aMsg);
  end;
  if (level and LOG_DATA) > 0 then
  begin
    if (level and LOG_DEBUG) > 0 then
    begin
      lo4dData.Debug(aMsg);
    end
    ELSE if (level and LOG_ERROR) > 0 then
    begin
      lo4dData.Error(aMsg);
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dData.Warn(aMsg);
    end
    else if (level and LOG_INFORMATION) > 0 then
    begin
      lo4dData.Info(aMsg);
    end;
  end;
  if (level and LOG_IMPORTANT) > 0 then
  begin
    if (level and LOG_DEBUG) > 0 then
    begin
      lo4dImportant.Debug(aMsg);
    end
    ELSE if (level and LOG_ERROR) > 0 then
    begin
      lo4dImportant.Error(aMsg);
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dImportant.Warn(aMsg);
    end
    else if (level and LOG_INFORMATION) > 0 then
    begin
      lo4dImportant.Info(aMsg);
    end;
  end;
  for I := 0 to FcallBackLst.Count - 1 do
  begin
    try
      @ff := FcallBackLst[I];
      ff(aMsg, level);
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

constructor TeventRecorder.Create;
var
  projName: string;
begin
  inherited Create;
  FcallBackLst := TList.Create;
  projName := GetModuleName(HInstance);
  projName := Copy(projName, 1, length(projName) - 3) + 'ini';
  TLogPropertyConfigurator.Configure(projName);
  lo4dLoger := TLogLogger.GetLogger('main');
  lo4dData := TLogLogger.GetLogger('data');
  lo4dImportant := TLogLogger.GetLogger('important');
  Add('eventRecorder init...');
end;

destructor TeventRecorder.Destroy;
begin
  FcallBackLst.Free;
  inherited Destroy;
end;

procedure TeventRecorder.registerCallBack(afunc: TMsgCallBack);
begin
  if FcallBackLst.IndexOfItem(addr(afunc), TList.TDirection.FromBeginning) = -1 then
    FcallBackLst.Add(addr(afunc));
end;

procedure TeventRecorder.removeCallBack(afunc: TMsgCallBack);
begin
  FcallBackLst.Remove(addr(afunc));
end;

procedure InitLoger;
begin
  Loger := TeventRecorder.Create;
end;

procedure finalLoger;
begin
  Loger.Free;
end;

initialization
  InitLoger;

finalization
  finalLoger;

end.

