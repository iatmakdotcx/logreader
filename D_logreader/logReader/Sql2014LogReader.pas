unit Sql2014LogReader;

interface

uses
  I_LogProvider, I_logReader;

type
  TSql2014LogReader = class(TlogReader)
  private
    FdataProvider: TLogProvider;
  public
    constructor Create(logProvider: TLogProvider);
    function init(): Boolean;
    function read(position: Integer; size: Integer; var data): Boolean;

    //text
    procedure listBigLogBlock;
  end;

implementation

uses
  Classes, p_structDefine, Windows, SysUtils, Memory_Common;

{ TSql2014LogReader }

constructor TSql2014LogReader.Create(logProvider: TLogProvider);
begin
  FdataProvider := logProvider;
end;

function TSql2014LogReader.init: Boolean;
begin

end;

procedure TSql2014LogReader.listBigLogBlock;
var
  pbb: PVLFHeader;
  iiiii:integer;


  ssIze:Integer;
begin
iiiii:= 0;
  FdataProvider.Seek($2000, soBeginning);
  ssIze := SizeOf(TVLFHeader);
  New(pbb);
  repeat
    if (FdataProvider.Read(pbb^, ssIze)=0) then
    break;
    OutputDebugStringA(PChar(bytestostr(pbb, ssIze)));
    FdataProvider.Seek(pbb^.CurrentBlockSize-ssIze, soCurrent);

    iiiii := iiiii + 1;
    
  until (pbb^.CurrentBlockSize=0) or (iiiii>200);

  Dispose(pbb);
end;

function TSql2014LogReader.read(position, size: Integer; var data): Boolean;
begin

end;

end.

