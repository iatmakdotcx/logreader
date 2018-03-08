library LrExtutils;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

{$IF CompilerVersion >= 21.0}
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}

uses
  {$IFDEF DEBUG}
  FastMM4 in 'H:\Delphi\FastMMnew\FastMM4.pas',
  FastMM4Messages in 'H:\Delphi\FastMMnew\FastMM4Messages.pas',
  {$ENDIF }
  SysUtils,
  Classes,
  HashHelper in 'HashHelper.pas',
  MsOdsApi in 'MsOdsApi.pas',
  Winapi.Windows,
  SqlSvrHelper in 'SqlSvrHelper.pas',
  dbhelper in 'dbhelper.pas',
  pageCaptureDllHandler in 'pageCaptureDllHandler.pas',
  Memory_Common in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Memory_Common.pas',
  pluginlog in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\pluginlog.pas',
  logRecdItemSave in 'logRecdItemSave.pas',
  MakCommonfuncs in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\MakCommonfuncs.pas',
  logRecdItemReader in 'logRecdItemReader.pas';

{$R *.res}

/// <summary>
/// �Ƿ��е�ǰ�ļ��е�д��Ȩ��
/// </summary>
/// <returns></returns>
function checkCurDirPermission: Boolean;
var
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  path: string;
  LFileHandle: THandle;
  LBytesWritten: Cardinal;
begin
  Result := False;
  LFileHandle := 0;
  try
    try
      GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
      path := ExtractFilePath(string(Pathbuf)) + 'log\';
      ForceDirectories(path);
      path := path + '1.bin';

      LFileHandle := CreateFile(PChar(path), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
      if LFileHandle <> INVALID_HANDLE_VALUE then
      begin
        LBytesWritten := $FE;
        WriteFile(LFileHandle, LFileHandle, 1, LBytesWritten, nil);
        SetFilePointer(LFileHandle, 0, nil, 0);
        ReadFile(LFileHandle, LBytesWritten, 1, LBytesWritten, nil);
        if LBytesWritten = $FE then
        begin
          Result := True;
        end;
      end;
    except
    end;
  finally
    if LFileHandle > 0 then
      CloseHandle(LFileHandle);
    DeleteFile(PChar(path));
  end;
end;

function HookFailMsg(ErrCode: Integer): string;
begin
  case ErrCode of
    0:
      Result := '�ɹ�';
    1:
      Result := '���ݲ�������Ѱ�װ';
    2:
      Result := 'sqlmin����ʧ��';
    3:
      Result := '���ݲ���㲻��ȷ(λ�ò��ɶ�)';
    4:
      Result := '���ݲ���㲻��ȷ(����Ч��ʧ��)';
    5:
      Result := '���ݲ��������Ч��ʧ��';
    6:
      Result := '';
    7:
      Result := '';
  else
    Result := 'δ����Ĵ���';
  end;
end;

function d_example(pSrvProc: SRV_PROC): Integer; cdecl;
var
  ResMsg: PAnsiChar;
  bNull: BOOL;
  bType: BYTE;
  uLen: ULONG;
  uMaxLen: ULONG;
  DataBuf: array of Byte;
  numRows: LongInt;
  I: Integer;
begin
  Result := SUCCEED;
  try
    try
      if srv_rpcparams(pSrvProc) <> 1 then
      begin
        srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:���봫��һ������', SRV_NULLTERM);
      end
      else
      begin
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, nil, @bNull);
        SetLength(DataBuf, uLen);
        ZeroMemory(@DataBuf[0], uLen);
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, @DataBuf[0], @bNull);

        numRows := PLongInt(@DataBuf[0])^;
        if numRows > 1000 then
          raise Exception.Create('Error: �������࣡����Ӧ��С��1000');

      // Define column 1
        srv_describe(pSrvProc, 1, 'ID', SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), nil);

      /// Define column 2
        srv_describe(pSrvProc, 2, 'Hello World', SRV_NULLTERM, SRVCHAR, 255, SRVCHAR, 0, nil);

        for I := 1 to numRows do
        begin
          srv_setcoldata(pSrvProc, 1, @I);
          ResMsg := PAnsiChar(AnsiString(Format('Hello:%d', [I])));
          srv_setcoldata(pSrvProc, 2, ResMsg);
          srv_setcollen(pSrvProc, 2, Length(ResMsg));
          srv_sendrow(pSrvProc);
        end;
      end;
    except
      on e: Exception do
      begin
        srv_sendmsg(pSrvProc, SRV_MSG_ERROR, 0, 0, 0, nil, 0, 0, PAnsiChar(AnsiString(e.Message)), SRV_NULLTERM);
      end;
    end;
  finally
    if Length(DataBuf) > 0 then
      SetLength(DataBuf, 0);
    srv_senddone(pSrvProc, SRV_DONE_FINAL or SRV_DONE_COUNT, 0, 0);
  end;
end;

function d_checkSqlSvr(pSrvProc: SRV_PROC): Integer;
var
  hdl: tHandle;
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  sqlminMD5: string;
begin
  Result := 0;
  hdl := GetModuleHandle('sqlmin.dll');
  if hdl = 0 then
  begin
    SqlSvr_SendMsg(pSrvProc, 'Error:sqlmin.dll����ʧ��');
  end
  else
  begin
    ZeroMemory(@Pathbuf[0], MAX_PATH + 2);
    GetModuleFileName(hdl, Pathbuf, MAX_PATH);
    sqlminMD5 := GetFileHashMD5(Pathbuf);

    //SqlSvr_SendMsg(pSrvProc, string(Pathbuf));
    //SqlSvr_SendMsg(pSrvProc, 'sqlmin:'+sqlminMD5);

    //GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
    //SqlSvr_SendMsg(pSrvProc, string(Pathbuf));

    try
      if DBH = nil then
        dbhelper.init;

      if DBH.checkMd5(sqlminMD5) then
      begin
        Result := 1;
      end
      else
      begin
        Result := 2;
      end;
    except
      on e: Exception do
      begin
        SqlSvr_SendMsg(pSrvProc, e.Message);
      end;
    end;
  end;

end;

function d_hook(pSrvProc: SRV_PROC): Integer;
var
  hdl: tHandle;
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  sqlminMD5: string;
  hookPnt: Integer;
  dllPath: string;
begin
  Result := SUCCEED;
  hdl := GetModuleHandle('sqlmin.dll');
  if hdl = 0 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:sqlmin.dll����ʧ��', SRV_NULLTERM);
  end
  else
  begin
    ZeroMemory(@Pathbuf[0], MAX_PATH + 2);
    GetModuleFileName(hdl, Pathbuf, MAX_PATH);
    sqlminMD5 := GetFileHashMD5(Pathbuf);

    SqlSvr_SendMsg(pSrvProc, string(Pathbuf));
    SqlSvr_SendMsg(pSrvProc, sqlminMD5);

    GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
    SqlSvr_SendMsg(pSrvProc, string(Pathbuf));

    if checkCurDirPermission then
    begin
      SqlSvr_SendMsg(pSrvProc, ' dllĿ¼������д��Ȩ�ޣ�');
      Exit;
    end;

    try
      if DBH = nil then
        dbhelper.init;

      if DBH.checkMd5(sqlminMD5) then
      begin
        SqlSvr_SendMsg(pSrvProc, '׼��������֪����');
        if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
        begin
          pageCapture_init(dllPath);
          hookPnt := _Lc_doHook(hookPnt);
          //hook fail
          if hookPnt=0 then
          begin
            SqlSvr_SendMsg(pSrvProc, '�ɹ�');
          end else begin
            SqlSvr_SendMsg(pSrvProc, 'ERROR:' + HookFailMsg(hookPnt));
          end;
        end;
      end
      else
      begin
        //TODO:����Ǻ�
        SqlSvr_SendMsg(pSrvProc, 'ERROR:δȷ�ϵ����ݲɼ�����');
      end;
    except
      on e: Exception do
      begin
        SqlSvr_SendMsg(pSrvProc, e.Message);
      end;
    end;
  end;
end;

procedure d_unhook(pSrvProc: SRV_PROC);
begin
  if not Assigned(_Lc_unHook) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����');
  end
  else
  begin
    _Lc_unHook;
  end;
end;

procedure d_Set_Databases(pSrvProc: SRV_PROC);
type
  PUInt64 = ^UInt64;
var
  bNull: BOOL;
  bType: BYTE;
  uLen: ULONG;
  uMaxLen: ULONG;
  DataBuf: array of Byte;
  DBids: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:�˷�����Ҫ��2����������', SRV_NULLTERM);
  end
  else
  begin
    srv_paraminfo(pSrvProc, 2, @bType, @uMaxLen, @uLen, nil, @bNull);
    SetLength(DataBuf, uLen + 2);
    ZeroMemory(@DataBuf[0], uLen + 2);
    srv_paraminfo(pSrvProc, 2, @bType, @uMaxLen, @uLen, @DataBuf[0], @bNull);

    if uLen = 1 then
    begin
      DBids := PByte(@DataBuf[0])^;
    end
    else if uLen = 2 then
    begin
      DBids := PWORD(@DataBuf[0])^;
    end
    else if (uLen = 3) or (uLen = 4) then
    begin
      DBids := PDWORD(@DataBuf[0])^;
    end
    else
    begin
      DBids := PUInt64(@DataBuf[3])^;
    end;

    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(DBids));
    if not Assigned(_Lc_Set_Databases) then
    begin
      SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����:' + UIntToStr(DBids));
    end
    else
    begin
      _Lc_Set_Databases(DBids);
      SqlSvr_SendMsg(pSrvProc, '���');
    end;
  end;
end;

procedure d_Get_PaddingDataCnt(pSrvProc: SRV_PROC);
var
  DataCnt: UInt64;
begin
  if not Assigned(_Lc_Get_PaddingDataCnt) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����');
  end
  else
  begin
    DataCnt := _Lc_Get_PaddingDataCnt;
    SqlSvr_SendMsg(pSrvProc, UIntToStr(DataCnt));
  end;
end;

procedure d_Get_HasBeenHooked(pSrvProc: SRV_PROC);
var
  DataCnt: UInt64;
begin
  if not Assigned(_Lc_HasBeenHooked) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����');
  end
  else
  begin
    DataCnt := _Lc_HasBeenHooked;
    SqlSvr_SendMsg(pSrvProc, UIntToStr(DataCnt));
  end;
end;

procedure d_do_SavePagelog(pSrvProc: SRV_PROC);
begin
  if not Assigned(_Lc_HasBeenHooked) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����');
  end
  else
  begin
    savePageLog2;
    SqlSvr_SendMsg(pSrvProc, 'ok');
  end;
end;

/// <summary>
/// ��ӡ��ǰϵͳ״̬
/// </summary>
/// <param name="pSrvProc"></param>
procedure PrintState(pSrvProc: SRV_PROC);

  function validCfgNam(Cfgval: Integer): string;
  begin
    case Cfgval of
      0:
        Result := 'ִ�г���';
      1:
        Result := '���÷�����ȷ��';
      2:
        Result := 'δ֪����';
    else
      Result := 'UNKNOWN';
    end;
  end;

var
  validCfg: Integer;
  dbids: UInt64;
  I: Integer;
  TmpStr: string;
begin
  SqlSvr_SendMsg(pSrvProc, 'checking.....');
  if Assigned(_Lc_HasBeenHooked) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'HookState:1(����)');
    if Assigned(_Lc_Get_Databases) then
    begin
      dbids := _Lc_Get_Databases;
      TmpStr := '';
      for I := 1 to 64 do
      begin
        if ((Uint64(1) shl Uint64(I - 1)) and dbids) > 0 then
        begin
          TmpStr := TmpStr + ',' + IntToStr(I);
        end;
      end;
      SqlSvr_SendMsg(pSrvProc, Format('DBs(%d):%s',[dbids, TmpStr]));
    end;

    if Assigned(_Lc_Get_PaddingDataCnt) then
    begin
      SqlSvr_SendMsg(pSrvProc, 'PaddingDataCnt:' + inttostr(_Lc_Get_PaddingDataCnt));
    end;

  end
  else
  begin
    SqlSvr_SendMsg(pSrvProc, 'HookState:0(δ����)');
    validCfg := d_checkSqlSvr(pSrvProc);
    SqlSvr_SendMsg(pSrvProc, Format('validCfg:%d(%s)', [validCfg, validCfgNam(validCfg)]));
  end;

  SqlSvr_SendMsg(pSrvProc, 'check end.....');
end;

/// <summary>
/// ����������
/// </summary>
/// <param name="pSrvProc"></param>
/// <returns></returns>
function Lr_doo(pSrvProc: SRV_PROC): Integer;
var
  bNull: BOOL;
  bType: BYTE;
  uLen: ULONG;
  uMaxLen: ULONG;
  DataBuf: array of Byte;
  action: string;
begin
  Result := SUCCEED;
  try
    try
      if srv_rpcparams(pSrvProc) < 1 then
      begin
        //srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:���봫��һ����������', SRV_NULLTERM);
        PrintState(pSrvProc);
      end
      else
      begin
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, nil, @bNull);
        SetLength(DataBuf, uLen + 2);
        ZeroMemory(@DataBuf[0], uLen + 2);
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, @DataBuf[0], @bNull);

        action := string(PAnsiChar(@DataBuf[0]));

        SqlSvr_SendMsg(pSrvProc, 'action:' + action);

        if action = 'A' then
        begin
          d_hook(pSrvProc);
        end
        else if action = 'B' then
        begin
          d_Set_Databases(pSrvProc);
        end
        else if action = 'C' then
        begin
          d_Get_PaddingDataCnt(pSrvProc);
        end
        else if action = 'D' then
        begin
          d_Get_HasBeenHooked(pSrvProc);
        end
        else if action = 'E' then
        begin
          d_do_SavePagelog(pSrvProc);
        end
        else if action = 'F' then
        begin
          d_unhook(pSrvProc);
        end
        else
        begin

        end;

      end;
    except
      on e: Exception do
      begin
        srv_sendmsg(pSrvProc, SRV_MSG_ERROR, 0, 0, 0, nil, 0, 0, PAnsiChar(AnsiString(e.Message)), SRV_NULLTERM);
      end;
    end;
  finally
    if Length(DataBuf) > 0 then
      SetLength(DataBuf, 0);
    srv_senddone(pSrvProc, SRV_DONE_FINAL or SRV_DONE_COUNT, 0, 0);
  end;
end;

/// <summary>
/// ��ȡ��־������
/// </summary>
/// <param name="pSrvProc"></param>
/// <returns></returns>
function Lr_roo(pSrvProc: SRV_PROC): Integer;
var
  //param
  dbid :Byte;
  lsn1,lsn2: Dword;
  lsn3:Word;
  parCnt:Integer;
  xmlResult:string;
begin
  Result := SUCCEED;
  parCnt := srv_rpcparams(pSrvProc);
  if parCnt = 2 then
  begin
    dbid := getParam_int(pSrvProc, 1);
    lsn1 := getParam_int(pSrvProc, 2);
    SqlSvr_SendMsg(pSrvProc, Format('dbid:%d, lsn1:%d',[dbid,lsn1]));
    xmlResult := Read_logAll(dbid, Lsn1);
    Read_logXmlToTableResults(pSrvProc, Lsn1, xmlResult);
  end else if parCnt = 4 then
  begin
    dbid := getParam_int(pSrvProc, 1);
    lsn1 := getParam_int(pSrvProc, 2);
    lsn2 := getParam_int(pSrvProc, 3);
    lsn3 := getParam_int(pSrvProc, 4);

    SqlSvr_SendMsg(pSrvProc, Format('dbid:%d, lsn:%.8x:%.8x:%.4x',[dbid,lsn1,lsn2,lsn3]));
    xmlResult := Read_log_One(dbid, Lsn1, lsn2, lsn3);
    Read_logXmlToTableResults(pSrvProc, Lsn1, xmlResult);

  end else begin
    SqlSvr_SendMsg(pSrvProc, '��������ȷ��');
  end;
  srv_senddone(pSrvProc, SRV_DONE_FINAL or SRV_DONE_COUNT, 0, 0);
end;


function Lr_clearCache(pSrvProc: SRV_PROC): Integer;
begin
  ClearSaveCache;
  Result := 0;
end;

procedure DLLMainHandler(Reason: Integer);
begin
  case Reason of
    DLL_PROCESS_ATTACH:
      begin

      end;
    DLL_PROCESS_DETACH:
      begin
        ClearSaveCache;
      end;
  end;
end;

exports
  Lr_clearCache,
  {$IFDEF DEBUG}
  d_do_SavePagelog,
  Read_log_One,
  {$ENDIF}
  d_example,
  Lr_doo,
  Lr_roo;

begin
  DLLProc := @DLLMainHandler; //��̬���ַ����ϵͳ��������ʱ��ִ��ж��
  DLLMainHandler(DLL_PROCESS_ATTACH);

  dbhelper.init;
  {$IFDEF DEBUG}
  //test code
  pageCapture_init('project1.exe');
  {$ENDIF}
end.

//����Ŀ¼����sqlserver����
//cacls "c:\data" /T /e /g MSSQLSERVER:f
