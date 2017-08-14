unit I_logReader;

interface

uses
  I_LogProvider, p_structDefine, Types, databaseConnection;

type
   TlogReader = class
      function GetRawLogByLSN(LSN:Tlog_LSN; vlfs:PVLF_Info ;OutBuffer:TMemory_data):Boolean;virtual;abstract;

      function init(dbc: TdatabaseConnection): Boolean;virtual;abstract;
      procedure listVlfs;virtual;abstract;
      procedure listLogBlock(vlfs:PVLF_Info);virtual;abstract;
   end; 

implementation

{ TlogReader }


end.
