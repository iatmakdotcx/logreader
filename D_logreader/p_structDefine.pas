unit p_structDefine;

interface

uses
  Types;

type
  QWORD = Int64;

type
  TLogProviderType = (LocalDB, RemoteDB, LDF);

  Plog_LSN = ^Tlog_LSN;

  Tlog_LSN = packed record
    LSN_1: DWORD;
    LSN_2: DWORD;
    LSN_3: WORD;
  end;

  PTrans_Id = ^TTrans_Id;

  TTrans_Id = packed record
    Id1: DWORD;
    Id2: WORD;
  end;

  PVLFHeader = ^TVLFHeader;

  TVLFHeader = packed record
    VLFHeadFlag: Byte;
    Paritybits: Byte;
    UN_1: Word;
    SeqNo: QWORD;
    UN_4: Word;
    UN_5: Word;
    CurrentBlockSize: QWORD;
    CurrentVLFOffset: QWord;
    CreateLSN: Tlog_LSN;
  end;

  PVLF_Info = ^TVLF_Info;

  TVLF_Info = packed record
    fileId:byte;
    SeqNo: Dword;
    VLFSize: QWORD;
    VLFOffset: QWORD;
    state:Byte;  //0未使用，2已使用
  end;

  TVLF_List = array of TVLF_Info;

  PlogBlock = ^TlogBlock;
  TlogBlock = packed record
    flag:Word;
    OperationCount :Word;
    endOfBlock:Word;
    Size:Word;    //这两个Size绝对一个是默认，一个是实际
    UN_1:Word;
    Size2:Word;   //这两个Size绝对一个是默认，一个是实际
    BeginLSN:Tlog_LSN;
    UN_2:Word;
    UN_3:DWORD;   //?? time?
  end;

  PMemory_data = ^TMemory_data;
  TMemory_data = packed record
    data:Pointer;
    dataSize:Int64;
  end;

  TlogFile_info = record
    fileId:Integer;
    Srchandle:THandle;   //源进程句柄
    filehandle:THandle;  //本地句柄
    fileName:string;     //日志文件名
    fileFullPath:String; //日志文件路径
  end;
  TlogFile_List = array of TlogFile_info;

  PRawLog = ^TRawLog;
  TRawLog = packed record
    UN_1:Word;
    fixedLen:Word;
    PreviousLSN:Tlog_LSN;
    FlagBits:Word;
    TransID:TTrans_Id;
    OpCode:Byte;
    ContextCode:Byte;
  end;

  PRawLog_BEGIN_XACT=^TRawLog_BEGIN_XACT;
  TRawLog_BEGIN_XACT = packed record
    normalData:TRawLog;
    SPID:DWORD;
    BeginlogStatus:DWORD;
    XactType:DWORD;
    UN_1:DWORD;
    Time:QWORD;
    XactID:DWORD;
  end;

  PRawLog_COMMIT_XACT=^TRawLog_COMMIT_XACT;
  TRawLog_COMMIT_XACT = packed record
    normalData:TRawLog;
    Time:QWORD;
    BeginLsn:Tlog_LSN;
  end;

  

type
  TPutLogNotify = procedure(lsn: Tlog_LSN; Raw: TMemory_data) of object;


function LSN2Str(lsn:Tlog_LSN):string;

  
implementation

uses
  SysUtils;


function LSN2Str(lsn:Tlog_LSN):string;
begin
  Result := format('0x%.8X:%.8X:%.4X',[lsn.LSN_1,lsn.LSN_2,lsn.LSN_3])
end;

end.

