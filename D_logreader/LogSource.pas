unit LogSource;

interface

uses
  I_LogProvider, I_logReader;


type
  TLogSource = class(TObject)
  private
    FlogProvider:TlogProvider;
    FLogReader :TlogReader;
  public
    function init_LDF(fileName:string):Boolean;
    function init:Boolean;
    constructor Create;
    destructor Destroy; override;
    //test func

    procedure listBigLogBlock;
  end;

implementation

uses
  LdfLogProvider, Classes, Sql2014LogReader;

{ TLogSource }

constructor TLogSource.Create;
begin
  inherited;

end;

destructor TLogSource.Destroy;
begin

  inherited;
end;

function TLogSource.init: Boolean;
begin

end;

function TLogSource.init_LDF(fileName: string): Boolean;
var
  ldf:TLdfLogProvider;
begin
  ldf := TLdfLogProvider.Create;
  ldf.init(fileName);
  FlogProvider := ldf;

  FLogReader := TSql2014LogReader.Create(FlogProvider);
end;

procedure TLogSource.listBigLogBlock;
begin
 FLogReader.listBigLogBlock;
end;

end.

