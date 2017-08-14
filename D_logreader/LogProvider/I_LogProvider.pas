unit I_LogProvider;

interface

uses
  Classes;

  
type
  TLogProvider = class
    function Read(var Buffer; Count: Longint): Longint;virtual;abstract;
    function Read_Byte(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Word(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Dword(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Read_Qword(var Buffer; posiOfBegin: Int64): Boolean;virtual;abstract;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; virtual;abstract;

    function getFileSize:Int64; virtual;abstract;
  end;

implementation

end.
