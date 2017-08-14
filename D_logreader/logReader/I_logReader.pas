unit I_logReader;

interface

uses
  I_LogProvider, p_structDefine, Types, databaseConnection;

type
   TlogReader = class
      function GetRawLogByLSN(LSN:Tlog_LSN; vlfs:PVLF_Info ;var OutBuffer:TMemory_data):Boolean;virtual;abstract;

      function init(dbc: TdatabaseConnection): Boolean;virtual;abstract;
      procedure listVlfs(fid:Byte);virtual;abstract;
      procedure listLogBlock(vlfs:PVLF_Info);virtual;abstract;

      procedure custRead(fileId:byte;posi,size:Int64;var OutBuffer:TMemory_data);virtual;abstract;
   end; 

implementation

{ TlogReader }


end.
