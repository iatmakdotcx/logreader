unit I_LogProvider;

interface

uses
  Classes;

  
type
  TLogProvider = class
    function Read(var Buffer; Count: Longint): Longint;virtual;abstract;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; virtual;abstract; 
  end;

implementation

end.
