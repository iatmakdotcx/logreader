unit I_LogSource;

interface

uses
  loglog, p_structDefine;

type
  TLogSourceBase = class(TObject)
  protected
    FLoger: TeventRecorder;
    /// <summary>
    /// Variant类型生成Sql包含实际类型
    /// </summary>
    FVariantWithRealType:Boolean;
  public
    constructor Create;
    function Loger: TeventRecorder;
    function getCollationById(id:Integer):TSQLCollationItem;virtual;abstract;
    function getCollationByName(Name:string):TSQLCollationItem;virtual;abstract;
    function getCollationByCodePage(codepage:Integer):TSQLCollationItem;virtual;abstract;
    function getDefCollation:TSQLCollationItem;virtual;abstract;
    property VariantWithRealType:Boolean read FVariantWithRealType;
  end;

implementation

{ TLogSourceBase }

constructor TLogSourceBase.Create;
begin
  FVariantWithRealType := False;
end;

function TLogSourceBase.Loger: TeventRecorder;
begin
  Result := FLoger;
end;

end.

