unit p_structDefine;

interface

uses
  Types;

type
  QWORD = UInt64;

  PQWORD = ^QWORD;

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

  TPage_Id = packed record
    PID: DWORD;
    FID: WORD;
    solt: WORD;
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
    fileId: byte;
    SeqNo: Dword;
    VLFSize: QWORD;
    VLFOffset: QWORD;
    state: Byte;  //0未使用，2已使用
  end;

  TVLF_List = array of TVLF_Info;

  PlogBlock = ^TlogBlock;

  TlogBlock = packed record
    flag: Word;
    OperationCount: Word;
    endOfBlock: Word;
    Size: Word;    //实际大小
    UN_1: Word;
    Size_Def: Word;   //块默认大小
    BeginLSN: Tlog_LSN;
    UN_2: Word;
    UN_3: DWORD;   //?? time? 暂不符合所有数据库日期类型
  end;

  PMemory_data = ^TMemory_data;

  TMemory_data = packed record
    data: Pointer;
    dataSize: Int64;
  end;

  TlogFile_info = record
    fileId: Integer;
    Srchandle: THandle;   //源进程句柄
    filehandle: THandle;  //本地句柄
    fileName: string;     //日志文件名
    fileFullPath: string; //日志文件路径
  end;

  TlogFile_List = array of TlogFile_info;

  PRawLog = ^TRawLog;

  TRawLog = packed record
    UN_1: Word;
    fixedLen: Word;
    PreviousLSN: Tlog_LSN;
    FlagBits: Word;
    TransID: TTrans_Id;
    OpCode: Byte;
    ContextCode: Byte;
  end;

  PRawLog_BEGIN_XACT = ^TRawLog_BEGIN_XACT;

  TRawLog_BEGIN_XACT = packed record
    normalData: TRawLog;
    SPID: DWORD;
    BeginlogStatus: DWORD;
    XactType: DWORD;
    UN_1: DWORD;
    Time: QWORD;
    XactID: DWORD;
  end;

  PRawLog_COMMIT_XACT = ^TRawLog_COMMIT_XACT;

  TRawLog_COMMIT_XACT = packed record
    normalData: TRawLog;
    Time: QWORD;
    BeginLsn: Tlog_LSN;
  end;

  PRawLog_DataOpt = ^TRawLog_DataOpt;

  TRawLog_DataOpt = packed record
    normalData: TRawLog;
    pageId: TPage_Id;
    AllocUnitId: DWORD;
    previousPageLsn: Tlog_LSN;
    UN_1: Word;
    PartitionId: QWORD;
    OffsetInRow: Word;
    ModifySize: Word;
    RowFlag: Word;
    NumElements: Word;
  end;

  PLogMIXDATAPkg = ^TLogMIXDATAPkg;

  TLogMIXDATAPkg = packed record
    key: QWORD;
    Page: TPage_Id;
  end;

type
  T_Lr_PluginInfo = function(var shortname: PChar): integer; stdcall;

  T_Lr_PluginInit = function(engineVersion: Integer): integer; stdcall;

  T_Lr_PluginUnInit = function(): integer; stdcall;

  T_Lr_PluginGetErrMsg = function(StatusCode: Cardinal): PChar; stdcall;

  T_Lr_PluginRegLogRowRead = function(lsn: Plog_LSN; Raw: PMemory_data): integer; stdcall;

  T_Lr_PluginRegTransPkg = function(TransPkg: PMemory_data): integer; stdcall;

  T_Lr_PluginRegSQL = function(Sql: PChar): integer; stdcall;

  T_Lr_PluginRegXML = function(Xml: PChar): integer; stdcall;

  T_Lr_PluginMenu = function(var Xml: PChar): integer; stdcall;
  T_Lr_PluginMenuAction = procedure(actionId: PChar); stdcall;

function LSN2Str(lsn: Tlog_LSN): string;

function TranId2Str(trans: TTrans_Id): string;

function PageRowCalcLength(rawData: Pointer): Integer;

implementation

uses
  SysUtils, Winapi.Windows;

function LSN2Str(lsn: Tlog_LSN): string;
begin
  Result := format('0x%.8X:%.8X:%.4X', [lsn.LSN_1, lsn.LSN_2, lsn.LSN_3])
end;

function TranId2Str(trans: TTrans_Id): string;
begin
  Result := format('0x%.4X:%.8X', [trans.Id2, trans.Id1])
end;

function PageRowCalcLength(rawData: Pointer): Integer;
var
  RowFlag: Word;
  Endoffset: UINT_PTR;
  tmpWord: Word;
begin
  Result := 0;
  try
    RowFlag := PWORD(rawData)^;
    Endoffset := UINT_PTR(rawData) + PWORD(UINT_PTR(rawData) + 2)^;
    tmpWord := PWORD(Endoffset)^;
    Endoffset := Endoffset + 2;
    if (RowFlag and $10) > 0 then
    begin
      //null map
      Endoffset := Endoffset + (tmpWord + 7) shr 3;
    end;
    if (RowFlag and $20) > 0 then
    begin
      //variants fields
      tmpWord := PWORD(Endoffset)^;
      Endoffset := Endoffset + tmpWord * 2;
      Endoffset := UINT_PTR(rawData) + (PWORD(Endoffset)^ and $7FFF);
    end;
    if (RowFlag and $40) > 0 then
    begin
      //versioning tag  (only 2005?
      Endoffset := Endoffset + $E;
    end;
    Result := Endoffset - UINT_PTR(rawData);
    if Result>$2000 then
      Result := 0;
  except
  end;
end;

end.

