unit I_LogSource;

interface

uses
  loglog, p_structDefine;

type
  TLogSourceBase = class(TObject)
  protected
    FLoger: TeventRecorder;
  public
    function Loger: TeventRecorder;
    function getCollationById(id:Integer):TSQLCollationItem;virtual;abstract;
    function getCollationByName(Name:string):TSQLCollationItem;virtual;abstract;
    function getCollationByCodePage(codepage:Integer):TSQLCollationItem;virtual;abstract;
    function getDefCollation:TSQLCollationItem;virtual;abstract;
  end;

implementation

{ TLogSourceBase }

function TLogSourceBase.Loger: TeventRecorder;
begin
  Result := FLoger;
end;

end.

