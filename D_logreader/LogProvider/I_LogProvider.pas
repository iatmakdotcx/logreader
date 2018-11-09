unit I_LogProvider;

interface

uses
  Classes;

  
type
  TLogProvider = class
    function init(fileHandle: THandle): Boolean;virtual;abstract;
    function Read(var Buffer; posiOfBegin: Int64; Count: Longint): Integer;virtual;abstract;
    function Read_Byte(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Word(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Dword(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Qword(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    procedure flush; virtual;abstract;
  end;

implementation

end.
