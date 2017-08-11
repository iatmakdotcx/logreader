unit I_logReader;

interface

uses
  I_LogProvider;

type
   TlogReader = class
     function read(position:Integer;size:Integer;var data):Boolean;virtual;abstract; 
     procedure listBigLogBlock;virtual;abstract;
   end; 

implementation

{ TlogReader }


end.
