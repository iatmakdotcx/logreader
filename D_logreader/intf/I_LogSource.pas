unit I_LogSource;

interface

uses
  loglog;

type
  TLogSourceBase = class(TObject)
  protected
    FLoger: TeventRecorder;
  public
    function Loger: TeventRecorder;
  end;

implementation

{ TLogSourceBase }

function TLogSourceBase.Loger: TeventRecorder;
begin
  Result := FLoger;
end;

end.

