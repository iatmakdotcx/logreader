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
  TMsgCallBack = procedure(aMsg: string; level: Integer)of object;

type
  TeventRecorder = class(TObject)
  private
    FcallBackLst: TList;
    lo4dLoger: TLogLogger;
    lo4dData: TLogLogger;
    lo4dImportant: TLogLogger;
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
  end;

procedure finalLoger;

var
  DefLoger: TeventRecorder;

implementation

uses
  System.Types;

procedure TeventRecorder.Add(aMsg: string; level: Integer = LOG_INFORMATION);
var
  I: Integer;
  pm:PMethod;
begin
  if (level and LOG_DEBUG) > 0 then
  begin
    lo4dLoger.Debug(aMsg);
  end
  else if (level and LOG_ERROR) > 0 then
  begin
    lo4dLoger.Error(aMsg);
    level := level or LOG_IMPORTANT;
  end
  else if (level and LOG_WARNING) > 0 then
  begin
    lo4dLoger.Warn(aMsg);
  end
  else
  begin
    lo4dLoger.Info(aMsg);
  end;
  if (level and LOG_DATA) > 0 then
  begin
    if (level and LOG_DEBUG) > 0 then
    begin
      lo4dData.Debug(aMsg);
    end
    else if (level and LOG_ERROR) > 0 then
    begin
      lo4dData.Error(aMsg);
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dData.Warn(aMsg);
    end
    else
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
    else if (level and LOG_ERROR) > 0 then
    begin
      lo4dImportant.Error(aMsg);
    end
    else if (level and LOG_WARNING) > 0 then
    begin
      lo4dImportant.Warn(aMsg);
    end
    else
    begin
      lo4dImportant.Info(aMsg);
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

constructor TeventRecorder.Create(logName:string='');
var
  projName: string;
begin
  inherited Create;
  FcallBackLst := TList.Create;
  projName := GetModuleName(HInstance);
  projName := Copy(projName, 1, length(projName) - 3) + 'ini';
  TLogPropertyConfigurator.Configure(projName);
  if logName = '' then
  begin
    lo4dLoger := TLogLogger.GetLogger('main');
    lo4dData := TLogLogger.GetLogger('main.data');
    lo4dImportant := TLogLogger.GetLogger('main.important');
  end
  else
  begin
    lo4dLoger := TLogLogger.GetLogger('main.' + logName);
    lo4dData := TLogLogger.GetLogger('main.' + logName + '.data');
    lo4dImportant := TLogLogger.GetLogger('main.' + logName + '.important');
  end;
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

