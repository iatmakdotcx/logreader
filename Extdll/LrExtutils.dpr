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
  {$IFDEF DEBUG}
  {$ENDIF }
  SysUtils,
  Classes,
  Winapi.Windows,
  MsOdsApi in 'MsOdsApi.pas',
  SqlSvrHelper in 'SqlSvrHelper.pas',
  dbhelper in 'dbhelper.pas',
  pageCaptureDllHandler in 'pageCaptureDllHandler.pas',
  Memory_Common in 'H:\Delphi\通用的自定义单元\Memory_Common.pas',
  logRecdItemSave in 'logRecdItemSave.pas',
  MakCommonfuncs in 'H:\Delphi\通用的自定义单元\MakCommonfuncs.pas',
  logRecdItemReader in 'logRecdItemReader.pas',
  cfg in 'cfg.pas',
  LidxMgr in 'LidxMgr.pas',
  loglog in '..\Common\loglog.pas',
  Log4D in '..\Common\Log4D.pas',
  HashHelper in '..\Common\HashHelper.pas';

{$R *.res}

const
  ModuleVersion = $00000001;

var
  SVR_hookPnt_Row:Integer = 0;

/// <summary>
/// 是否有当前文件夹的写入权限
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
      Result := '成功';
    1:
      Result := '数据捕获程序已安装';
    2:
      Result := 'sqlmin加载失败';
    3:
      Result := '数据捕获点不正确(位置不可读)';
    4:
      Result := '区域跨度过大';
  else
    Result := '未定义的错误';
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
        srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:必须传入一个参数', SRV_NULLTERM);
      end
      else
      begin
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, nil, @bNull);
        SetLength(DataBuf, uLen);
        ZeroMemory(@DataBuf[0], uLen);
        srv_paraminfo(pSrvProc, 1, @bType, @uMaxLen, @uLen, @DataBuf[0], @bNull);

        numRows := PLongInt(@DataBuf[0])^;
        if numRows > 1000 then
          raise Exception.Create('Error: 行数过多！参数应该小于1000');

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
    SqlSvr_SendMsg(pSrvProc, 'Error:sqlmin.dll加载失败');
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
          SqlSvr_SendMsg(pSrvProc, 'init:成功');
          Result := 1;
        end else begin
          SqlSvr_SendMsg(pSrvProc, '读取配置失败');
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
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:sqlmin.dll加载失败', SRV_NULLTERM);
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
      SqlSvr_SendMsg(pSrvProc, ' dll目录不包含写入权限！');
      Exit;
    end;

    try
      if DBH = nil then
         DBH := TDBH.Create;

      if DBH.checkMd5(sqlminMD5) then
      begin
        SqlSvr_SendMsg(pSrvProc, '准备加载已知方案');
        if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
        begin
          SVR_hookPnt_Row := hookPnt;
          pageCapture_init(dllPath);
          SqlSvr_SendMsg(pSrvProc, '成功');
        end;
      end
      else
      begin
        //TODO:如何是好
        SqlSvr_SendMsg(pSrvProc, 'ERROR:未确认的数据采集方案');
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
    if loopSaveMgr = nil then
      loopSaveMgr := TloopSaveMgr.Create;
    hookPnt := _Lc_doHook(SVR_hookPnt_Row);
    if hookPnt = 99 then
    begin
      _Lc_Set_Databases(cfg.DBids);
      SqlSvr_SendMsg(pSrvProc, '成功');
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
    SqlSvr_SendMsg(pSrvProc, 'ERROR:未初始化数据采集进程');
  end
  else
  begin
    _Lc_unHook;
  end;

  if loopSaveMgr <> nil then
  begin
    loopSaveMgr.Free;
    loopSaveMgr := nil;
  end;
end;

procedure d_Set_Databases_0(pSrvProc: SRV_PROC);
type
  PUInt64 = ^UInt64;
var
  DBids: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:此方法需要【2】个参数！', SRV_NULLTERM);
  end
  else
  begin
    DBids := getParam_int(pSrvProc, 2);
    if DBids > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '数据库id必须是1..63之间的值' + UIntToStr(DBids));
      Exit;
    end;

    cfg.DBids := cfg.DBids and ((Uint64(1) shl (DBids-1)) xor $FFFFFFFFFFFFFFFF);
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(DBids));
    if not Assigned(_Lc_Set_Databases) then
    begin
      SqlSvr_SendMsg(pSrvProc, 'ERROR:未初始化数据采集进程:' + UIntToStr(DBids));
    end
    else
    begin
      _Lc_Set_Databases(cfg.DBids);
      SqlSvr_SendMsg(pSrvProc, '完成');
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
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:此方法需要【2】个参数！', SRV_NULLTERM);
  end
  else
  begin
    DBids := getParam_int(pSrvProc, 2);
    if DBids > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '数据库id必须是1..63之间的值' + UIntToStr(DBids));
      Exit;
    end;
    SqlSvr_SendMsg(pSrvProc, 'ipt:' + UIntToStr(DBids));

    cfg.DBids := cfg.DBids or (Uint64(1) shl (DBids-1));
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(cfg.DBids));
    if Assigned(_Lc_Set_Databases) then
    begin
      _Lc_Set_Databases(cfg.DBids);
      SqlSvr_SendMsg(pSrvProc, '完成');
    end;
  end;
end;

procedure d_Get_PaddingDataCnt(pSrvProc: SRV_PROC);
var
  DataCnt: UInt64;
begin
  if not Assigned(_Lc_Get_PaddingDataCnt) then
  begin
    SqlSvr_SendMsg(pSrvProc, 'ERROR:未初始化数据采集进程');
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
    SqlSvr_SendMsg(pSrvProc, 'ERROR:未初始化数据采集进程');
  end
  else
  begin
    DataCnt := _Lc_HasBeenHooked;
    SqlSvr_SendMsg(pSrvProc, UIntToStr(DataCnt));
  end;
end;

/// <summary>
/// 打印当前系统状态
/// </summary>
/// <param name="pSrvProc"></param>
procedure PrintState(pSrvProc: SRV_PROC);

  function validCfgNam(Cfgval: Integer): string;
  begin
    case Cfgval of
      0:
        Result := '执行出错';
      1:
        Result := 'ok';
      2:
        Result := '未知方案';
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

    if loopSaveMgr = nil then
    begin
      SqlSvr_SendMsg(pSrvProc, 'loopSaveMgr:0');
    end else begin
      SqlSvr_SendMsg(pSrvProc, 'loopSaveMgr:1');
    end;
  end
  else
  begin
    SqlSvr_SendMsg(pSrvProc, 'HookState:0(未启用)');
    validCfg := d_checkSqlSvr(pSrvProc);
    SqlSvr_SendMsg(pSrvProc, Format('validCfg:%d(%s)', [validCfg, validCfgNam(validCfg)]));
  end;

  SqlSvr_SendMsg(pSrvProc, 'check end.....');
end;

/// <summary>
/// 控制主函数
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
        //srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:必须传入一个或多个参数', SRV_NULLTERM);
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
          savePageLog2;
          //d_Get_HasBeenHooked(pSrvProc);
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
/// 读取日志主函数
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
    if PagelogFileMgr.LogDataGetData(dbid, Lsn1, lsn2, lsn3, memory) then
    begin
      lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
      srv_setcoldata(pSrvProc, 1, lsnVal);
      srv_setcoldata(pSrvProc, 2, memory.Memory);
      srv_setcollen(pSrvProc, 2, memory.Size);
      srv_sendrow(pSrvProc);
    end else begin
      Sleep(2000);  //首次失败休息两秒再试，可能内容还未保存
      SqlSvr_SendMsg(pSrvProc,'Retry...');
      if PagelogFileMgr.LogDataGetData(dbid, Lsn1, lsn2, lsn3, memory) then
      begin
        lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
        srv_setcoldata(pSrvProc, 1, lsnVal);
        srv_setcoldata(pSrvProc, 2, memory.Memory);
        srv_setcollen(pSrvProc, 2, memory.Size);
        srv_sendrow(pSrvProc);
      end;
    end;
    memory.Free;
  end else begin
    SqlSvr_SendMsg(pSrvProc, '参数不正确！');
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
        if loopSaveMgr <> nil then
          loopSaveMgr.Free;
      end;
  end;
end;

function Lr_doo_test(dbid: Word; lsn1, lsn2: DWORD; lsn3: WORD):Int32;stdcall;
var
  memory:TMemoryStream;
begin
  memory := TMemoryStream.Create;
  if PagelogFileMgr.LogDataGetData(dbid, lsn1, lsn2, lsn3, memory) then
  begin
    Result := 1;
  end
  else
  begin
    result := 0;
  end;
  memory.Free;
end;

exports
  {$IFDEF DEBUG}

  {$ENDIF}
  savePageLog2,
  Lr_doo,
  Lr_roo
  ;

begin
  DLLProc := @DLLMainHandler; //动态库地址告诉系统，结束的时候执行卸载
  DLLMainHandler(DLL_PROCESS_ATTACH);

  DBH := TDBH.Create;
  {$IFDEF DEBUG}
  //test code
  pageCapture_init('project1.exe');
  {$ENDIF}
end.


//设置目录允许sqlserver访问
//cacls "c:\data" /T /e /g MSSQLSERVER:f
