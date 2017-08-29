unit LdfLogProvider;

interface

uses
  I_LogProvider, Classes, LocalDbLogProvider;

type
  TLdfLogProvider = class(TLocalDbLogProvider)
  public
    constructor Create;
    destructor Destroy; override;
    function init(fileName: string): Boolean;
  end;

implementation

uses
  Windows, SysUtils;

{ TLdfLogProvider }

constructor TLdfLogProvider.Create;
begin
  inherited;
end;

destructor TLdfLogProvider.Destroy;
begin
  inherited;
end;

function TLdfLogProvider.init(fileName: string): Boolean;
var
  fileHandle:THandle;
begin
  fileHandle := CreateFile(PChar(fileName), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if fileHandle = INVALID_HANDLE_VALUE then
  begin
    raise exception.Create('³¢ÊÔ´ò¿ª%sÊ§°Ü£¡' + #$D#$A + SysErrorMessage(getlastError));
  end;
  Result := inherited init(fileHandle);
end;

end.

