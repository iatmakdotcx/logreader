unit p_structDefine;

interface

uses
  Windows;

type
  LS_STATUE = (tLS_unknown, tLS_NotConfig, tLS_NotConnectDB, tLs_noLogReader, tLS_running, tLS_stopped, tLS_suspension);

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
    CheckSum: DWORD;
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

  PMIX_Page_DATA =^TMIX_Page_DATA;
  TMIX_Page_DATA =packed record
    flag:Word;
    Recordlen:Word;
    MixKey: QWORD;
    MixType:Word;
  end;

  PMIX_Page_DATA_0 =^TMIX_Page_DATA_0;
  TMIX_Page_DATA_0 =packed record
    a:TMIX_Page_DATA;
    dataLen:Word;
    dataVersion:DWORD;
    data:array[0..0] of Byte;
  end;
  PMIX_Page_DATA_2 =^TMIX_Page_DATA_2;
  TMIX_Page_DATA_2 =packed record
    a:TMIX_Page_DATA;
    UNKNOWN:Word;
    pageCount:DWORD;
    pageDataLength:DWORD;
    UNKNOWN_2:DWord;
    Pageid:TPage_Id;
  end;

  PMIX_Page_DATA_3 =^TMIX_Page_DATA_3;
  TMIX_Page_DATA_3 =packed record
    a:TMIX_Page_DATA;
    data:array[0..0] of Byte;
  end;

  PMIX_Page_DATA_5 =^TMIX_Page_DATA_5;
  TMIX_Page_DATA_5 =packed record
    a:TMIX_Page_DATA;
    UNKNOWN_1:Word;
    UNKNOWN_2:Word;
    UNKNOWN_3:Word;
    dataVersion:DWORD;
    datasize:DWORD;
    Pageid:TPage_Id;
  end;

function LSN2Str(lsn: Tlog_LSN): string;

function TranId2Str(trans: TTrans_Id): string;

function PageRowCalcLength(rawData: Pointer): Integer;

function Str2TranId(transtr: string): TTrans_Id;
function Str2LSN(lsnStr:string): Tlog_LSN;

implementation

uses
  SysUtils;

function LSN2Str(lsn: Tlog_LSN): string;
begin
  Result := format('0x%.8X:%.8X:%.4X', [lsn.LSN_1, lsn.LSN_2, lsn.LSN_3])
end;

function Str2LSN(lsnStr:string): Tlog_LSN;
var
  s1,s2,s3:string;
  i1,i2,i3:Integer;
begin
  if lsnStr.StartsWith('0x') then
  begin
    Delete(lsnStr,1,2);
  end;
  s1 := lsnStr.Substring(0,8);
  s2 := lsnStr.Substring(9,8);
  s3 := lsnStr.Substring(18,4);
  if TryStrToInt('$'+s1, i1) and TryStrToInt('$'+s2, i2) and TryStrToInt('$'+s3, i3) then
  begin
    Result.LSN_1 := i1;
    Result.LSN_2 := i2;
    Result.LSN_3 := i3;
  end
  else
  begin
    Result.LSN_1 := 0;
    Result.LSN_2 := 0;
    Result.LSN_3 := 0;
  end;
end;

function TranId2Str(trans: TTrans_Id): string;
begin
  Result := format('0x%.4X:%.8X', [trans.Id2, trans.Id1])
end;

function Str2TranId(transtr: string): TTrans_Id;
var
  id1,id2:string;
  i1,i2:Integer;
begin
  if transtr.StartsWith('0x') then
  begin
    id1 := transtr.Substring(2,4);
    id2 := transtr.Substring(7,8);
  end else begin
    id1 := transtr.Substring(0,4);
    id2 := transtr.Substring(5,8);
  end;
  if TryStrToInt('$'+id1, i1) and TryStrToInt('$'+id2, i2) then
  begin
    Result.Id2 := i1;
    Result.Id1 := i2;
  end
  else
  begin
    Result.Id1 := 0;
    Result.Id2 := 0;
  end;
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

