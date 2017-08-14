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
    state:Byte;  //0δʹ�ã�2��ʹ��
  end;

  TVLF_List = array of TVLF_Info;

  PlogBlock = ^TlogBlock;
  TlogBlock = packed record
    flag:Word;
    OperationCount :Word;
    endOfBlock:Word;
    Size:Word;
    UN_1:DWORD;
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
    Srchandle:THandle;   //Դ���̾��
    filehandle:THandle;  //���ؾ��
    fileName:string;     //��־�ļ���
    fileFullPath:String; //��־�ļ�·��
  end;
  TlogFile_List = array of TlogFile_info;



function LSN2Str(lsn:Tlog_LSN):string;

  
implementation

uses
  SysUtils;


function LSN2Str(lsn:Tlog_LSN):string;
begin
  Result := format('0x%.8X:%.8X:%.4X',[lsn.LSN_1,lsn.LSN_2,lsn.LSN_3])
end;

end.

