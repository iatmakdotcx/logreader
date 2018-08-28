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
{$ENDIF}

uses
  EMemLeaks,
  EResLeaks,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EDebugExports,
  EFixSafeCallException,
  EMapWin32,
  ExceptionLog7,
  {$IFDEF DEBUG}
  {$ENDIF }
  SysUtils,
  Classes,
  Winapi.Windows,
  MsOdsApi in 'MsOdsApi.pas',
  SqlSvrHelper in 'SqlSvrHelper.pas',
  dbhelper in 'dbhelper.pas',
  pageCaptureDllHandler in 'pageCaptureDllHandler.pas',
  Memory_Common in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Memory_Common.pas',
  MakCommonfuncs in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\MakCommonfuncs.pas',
  cfg in 'cfg.pas',
  loglog in '..\Common\loglog.pas',
  Log4D in '..\Common\Log4D.pas',
  HashHelper in '..\Common\HashHelper.pas',
  p_RawMgr_2 in 'p_RawMgr_2.pas';

{$R *.res}

const
  ModuleVersion = $00000001;

var
  SVR_hookPnt_Row:Integer = 0;

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
      Result := '�����ȹ���';
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
  hookPnt: Integer;
  dllPath: string;
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
         DBH := TDBH.Create;

      if DBH.checkMd5(sqlminMD5) then
      begin
        if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
        begin
          SVR_hookPnt_Row := hookPnt;
          pageCapture_init(dllPath);
          SqlSvr_SendMsg(pSrvProc, 'init:�ɹ�');
          Result := 1;
        end else begin
          SqlSvr_SendMsg(pSrvProc, '��ȡ����ʧ��');
        end;
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

function d_hook_init(pSrvProc: SRV_PROC): Integer;
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
         DBH := TDBH.Create;

      if DBH.checkMd5(sqlminMD5) then
      begin
        SqlSvr_SendMsg(pSrvProc, '׼��������֪����');
        if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
        begin
          SVR_hookPnt_Row := hookPnt;
          pageCapture_init(dllPath);
          SqlSvr_SendMsg(pSrvProc, '�ɹ�');
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

function d_hook(pSrvProc: SRV_PROC): Integer;
var
  hookPnt:UInt64;
begin
  Result := SUCCEED;
  if not Assigned(_Lc_doHook) then
    d_hook_init(pSrvProc);

  d_checkSqlSvr(pSrvProc);

  if Assigned(_Lc_doHook) and (SVR_hookPnt_Row > 0) then
  begin
//    if loopSaveMgr = nil then
//      loopSaveMgr := TloopSaveMgr.Create;
    hookPnt := _Lc_doHook(SVR_hookPnt_Row);
    if hookPnt = 99 then
    begin
      _Lc_Set_Databases(cfg.DBids);
      SqlSvr_SendMsg(pSrvProc, '�ɹ�');
    end else begin
      //hook fail
      SqlSvr_SendMsg(pSrvProc, 'ERROR:' + HookFailMsg(hookPnt));
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

//  if loopSaveMgr <> nil then
//  begin
//    loopSaveMgr.Free;
//    loopSaveMgr := nil;
//  end;
end;

procedure d_Set_Databases_0(pSrvProc: SRV_PROC);
type
  PUInt64 = ^UInt64;
var
  DBids: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:�˷�����Ҫ��2����������', SRV_NULLTERM);
  end
  else
  begin
    DBids := getParam_int(pSrvProc, 2);
    if DBids > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '���ݿ�id������1..63֮���ֵ' + UIntToStr(DBids));
      Exit;
    end;

    cfg.DBids := cfg.DBids and ((Uint64(1) shl (DBids-1)) xor $FFFFFFFFFFFFFFFF);
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(DBids));
    if not Assigned(_Lc_Set_Databases) then
    begin
      SqlSvr_SendMsg(pSrvProc, 'ERROR:δ��ʼ�����ݲɼ�����:' + UIntToStr(DBids));
    end
    else
    begin
      _Lc_Set_Databases(cfg.DBids);
      SqlSvr_SendMsg(pSrvProc, '���');
    end;
  end;
end;

procedure d_Set_Databases_1(pSrvProc: SRV_PROC);
type
  PUInt64 = ^UInt64;
var
  DBids: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:�˷�����Ҫ��2����������', SRV_NULLTERM);
  end
  else
  begin
    DBids := getParam_int(pSrvProc, 2);
    if DBids > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '���ݿ�id������1..63֮���ֵ' + UIntToStr(DBids));
      Exit;
    end;
    SqlSvr_SendMsg(pSrvProc, 'ipt:' + UIntToStr(DBids));

    cfg.DBids := cfg.DBids or (Uint64(1) shl (DBids-1));
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(cfg.DBids));
    if Assigned(_Lc_Set_Databases) then
    begin
      _Lc_Set_Databases(cfg.DBids);
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
        Result := 'ok';
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
    SqlSvr_SendMsg(pSrvProc, 'HookState:' + inttostr(_Lc_HasBeenHooked));
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

//    if loopSaveMgr = nil then
//    begin
//      SqlSvr_SendMsg(pSrvProc, 'loopSaveMgr:0');
//    end else begin
//      SqlSvr_SendMsg(pSrvProc, 'loopSaveMgr:1');
//    end;
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

  tmpint:Integer;
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
        else if action = 'B+' then
        begin
          d_Set_Databases_1(pSrvProc);
        end
        else if action = 'B-' then
        begin
          d_Set_Databases_0(pSrvProc);
        end
        else if action = 'D' then
        begin
//          savePageLog2;
        end
        else if action = 'E' then
        begin
          SqlSvr_SendMsg(pSrvProc, 'dbid:' + inttostr(cfg.DBids));
        end
        else if action = 'F' then
        begin
          d_unhook(pSrvProc);
        end
        else if action = 'G' then
        begin
          srv_describe(pSrvProc, 1, 'status', SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), nil);
          tmpint := d_checkSqlSvr(pSrvProc);
          srv_setcoldata(pSrvProc, 1, @tmpint);
          srv_sendrow(pSrvProc);
        end
        else if action = 'V' then
        begin
          srv_describe(pSrvProc, 1, 'version', SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), nil);
          tmpint := ModuleVersion;
          srv_setcoldata(pSrvProc, 1, @tmpint);
          srv_sendrow(pSrvProc);
        end else if action = 'TEST' then
        begin

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
  dbid :Byte;
  lsn1,lsn2: Dword;
  lsn3:Word;
  parCnt:Integer;
  memory:TMemoryStream;
  lsnVal: PAnsiChar;
begin
  Result := SUCCEED;
  srv_describe(pSrvProc, 1, 'LSN', SRV_NULLTERM, SRVCHAR, 22, SRVCHAR, 22, nil);
  srv_describe(pSrvProc, 2, 'data', SRV_NULLTERM, SRV_TDS_IMAGE, 0, SRVBIGVARCHAR, 0, nil);
  parCnt := srv_rpcparams(pSrvProc);
  if parCnt = 4 then
  begin
    dbid := getParam_int(pSrvProc, 1);
    lsn1 := getParam_int(pSrvProc, 2);
    lsn2 := getParam_int(pSrvProc, 3);
    lsn3 := getParam_int(pSrvProc, 4);

    SqlSvr_SendMsg(pSrvProc, Format('dbid:%d, lsn:%.8x:%.8x:%.4x',[dbid,lsn1,lsn2,lsn3]));
    memory:=TMemoryStream.Create;
//    if PagelogFileMgr.LogDataGetData(dbid, Lsn1, lsn2, lsn3, memory) then
//    begin
//      lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
//      srv_setcoldata(pSrvProc, 1, lsnVal);
//      srv_setcoldata(pSrvProc, 2, memory.Memory);
//      srv_setcollen(pSrvProc, 2, memory.Size);
//      srv_sendrow(pSrvProc);
//    end else begin
//      Sleep(2000);  //�״�ʧ����Ϣ�������ԣ��������ݻ�δ����
//      SqlSvr_SendMsg(pSrvProc, 'Retry...');
//      if PagelogFileMgr.LogDataGetData(dbid, Lsn1, lsn2, lsn3, memory) then
//      begin
//        lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
//        srv_setcoldata(pSrvProc, 1, lsnVal);
//        srv_setcoldata(pSrvProc, 2, memory.Memory);
//        srv_setcollen(pSrvProc, 2, memory.Size);
//        srv_sendrow(pSrvProc);
//      end;
//    end;
    memory.Free;
  end else begin
    SqlSvr_SendMsg(pSrvProc, '��������ȷ��');
  end;
  srv_senddone(pSrvProc, SRV_DONE_FINAL or SRV_DONE_COUNT, 0, 0);
end;

procedure DLLMainHandler(Reason: Integer);
begin
  case Reason of
    DLL_PROCESS_ATTACH:
      begin

      end;
    DLL_PROCESS_DETACH:
      begin
//        if loopSaveMgr <> nil then
//          loopSaveMgr.Free;
      end;
  end;
end;

procedure Lr_doo_test;
var
   mmO:TMemoryStream;
begin
  mmO:=TMemoryStream.Create;
  try
    PageLog_load(5, 161, $A3, 2, mmO);
    Loger.Add(DumpMemory2Str(mmO.Memory, mmo.Size));
  finally
    mmo.Free;
  end;
end;


exports
  {$IFDEF DEBUG}
  PageLog_save name 'savePageLog2',
  Lr_doo_test,
  {$ENDIF}
  Lr_doo,
  Lr_roo;

begin
  DLLProc := @DLLMainHandler; //��̬���ַ����ϵͳ��������ʱ��ִ��ж��
  DLLMainHandler(DLL_PROCESS_ATTACH);

  DBH := TDBH.Create;
  {$IFDEF DEBUG}
  //test code
  pageCapture_init('project1.exe');
  {$ENDIF}
end.


//����Ŀ¼����sqlserver����
//cacls "c:\data" /T /e /g MSSQLSERVER:f
