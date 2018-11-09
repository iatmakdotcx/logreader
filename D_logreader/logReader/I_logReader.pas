unit I_logReader;

interface

uses
  I_LogProvider, p_structDefine, Types, databaseConnection, Classes;

type
   TlogReader = class
      function GetRawLogByLSN(LSN:Tlog_LSN; vlfs:PVLF_Info ;var OutBuffer:TMemory_data):Boolean;virtual;abstract;
      procedure listVlfs(fid:Byte);virtual;abstract;
      procedure listLogBlock(vlfs:PVLF_Info);virtual;abstract;
      procedure custRead(fileId:byte;posi,size:Int64;var OutBuffer:TMemory_data);virtual;abstract;
   end;





implementation

{ TlogReader }

(*
LDF
  head(size:2000)
    +4  Flag ( C00:日志已加密

  +2000 VLFs
    +0  Head(size:1)（固定值 AB）
    +1  Paritybits(size:1)
    +2  类型(size:1)  （1-5）
    +4  SeqNo(size:4)
    +8  (size:4)
    +c  (size:4)
    +18 Vlf的物理偏移(size:8)

    +200 RawLog
      +0 head(S:4)   ($90或$98或[0x1010101 bt (x-0x40)])
      +18 CheckSum


*)
end.
