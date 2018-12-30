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
  FastMM4 in 'H:\Delphi\FastMMnew\FastMM4.pas',
  FastMM4Messages in 'H:\Delphi\FastMMnew\FastMM4Messages.pas' ,
  SysUtils,
  Classes,
  Winapi.Windows,
  MsOdsApi in 'MsOdsApi.pas',
  SqlSvrHelper in 'SqlSvrHelper.pas',
  dbhelper in 'dbhelper.pas',
  pageCaptureDllHandler in 'pageCaptureDllHandler.pas',
  Memory_Common in 'H:\Delphi\通用的自定义单元\Memory_Common.pas',
  MakCommonfuncs in 'H:\Delphi\通用的自定义单元\MakCommonfuncs.pas',
  cfg in 'cfg.pas',
  loglog in '..\Common\loglog.pas',
  HashHelper in '..\Common\HashHelper.pas',
  p_RawMgr_2 in 'p_RawMgr_2.pas',
  p_HookHelper in 'p_HookHelper.pas';

{$R *.res}

const
  ModuleVersion = $00000001;
var
  LMMSkzbase: PLogMemoryManagerState = nil;


procedure exitAllThread;
begin
  DefLoger.Add('exiting....');
  if loopSaveMgr<>nil then
  begin
    loopSaveMgr.Terminate;
    loopSaveMgr.WaitFor;
    loopSaveMgr.Free;
    loopSaveMgr := nil;
  end;
  DefLoger.ClearLogEngine;
end;

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

function d_hook(pSrvProc: SRV_PROC): Integer;
var
  hookState:UInt64;
begin
  Result := SUCCEED;
  if Assigned(_Lc_doHook) and (SVR_hookPnt_Row > 0) then
  begin
    if loopSaveMgr = nil then
    begin
      SqlSvr_SendMsg(pSrvProc, '无法启动，请重新加载DLL!!!');
      exit;
    end;
    hookState := _Lc_doHook(SVR_hookPnt_Row);
    if hookState = 99 then
    begin
      _Lc_Set_Databases(cfg.CFG_DBids);
      SqlSvr_SendMsg(pSrvProc, '成功');
    end else begin
      //hook fail
      SqlSvr_SendMsg(pSrvProc, 'ERROR:' + HookFailMsg(hookState));
    end;
  end else begin
    SqlSvr_SendMsg(pSrvProc, '没有合适的配置!!!');
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
end;

procedure d_Set_Databases_0(pSrvProc: SRV_PROC);
var
  IptDBid: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:此方法需要【2】个参数！', SRV_NULLTERM);
  end
  else
  begin
    IptDBid := getParam_int(pSrvProc, 2);
    if IptDBid > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '数据库id必须是1..63之间的值' + UIntToStr(IptDBid));
      Exit;
    end;

    cfg.CFG_DBids := cfg.CFG_DBids and ((Uint64(1) shl (IptDBid-1)) xor $FFFFFFFFFFFFFFFF);
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(CFG_DBids));
    if Assigned(_Lc_Set_Databases) then
    begin
      _Lc_Set_Databases(cfg.CFG_DBids);
      SqlSvr_SendMsg(pSrvProc, '完成');
    end;
  end;
end;

procedure d_Set_Databases_1(pSrvProc: SRV_PROC);
var
  IptDBid: UInt64;
begin
  if srv_rpcparams(pSrvProc) <> 2 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:此方法需要【2】个参数！', SRV_NULLTERM);
  end
  else
  begin
    IptDBid := getParam_int(pSrvProc, 2);
    if IptDBid > 63 then
    begin
      SqlSvr_SendMsg(pSrvProc, '数据库id必须是1..63之间的值' + UIntToStr(IptDBid));
      Exit;
    end;
    SqlSvr_SendMsg(pSrvProc, 'ipt:' + UIntToStr(IptDBid));

    cfg.CFG_DBids := cfg.CFG_DBids or (Uint64(1) shl (IptDBid-1));
    cfg.saveCfg;
    SqlSvr_SendMsg(pSrvProc, 'DBids:' + UIntToStr(cfg.CFG_DBids));
    if Assigned(_Lc_Set_Databases) then
    begin
      _Lc_Set_Databases(cfg.CFG_DBids);
      SqlSvr_SendMsg(pSrvProc, '完成');
    end;
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
  dbids: UInt64;
  I: Integer;
  TmpStr: string;
begin
  SqlSvr_SendMsg(pSrvProc, 'checking.....');
  SqlSvr_SendMsg(pSrvProc, 'SqlMin:' + SVR_Sqlmin_md5);
  if SVR_hookPnt_Row > 0 then
  begin
    SqlSvr_SendMsg(pSrvProc, 'validCfg:1');
  end
  else
  begin
    SqlSvr_SendMsg(pSrvProc, 'validCfg:0');
  end;
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
      SqlSvr_SendMsg(pSrvProc, 'DLL已被预释放！请执行：dbcc LrExtutils(free)');
    end else begin
      SqlSvr_SendMsg(pSrvProc, 'loopSaveMgr:1');
    end;
  end;
  SqlSvr_SendMsg(pSrvProc, 'check end.....');
end;

procedure LMMSScompare(kz1, kz2: PLogMemoryManagerState);
var
  I,J: Integer;
  AllocatedtotalSize:UInt64;
begin
  for I := 0 to kz2.ObjCnt - 1 do
  begin
    for J := 0 to kz1.ObjCnt - 1 do
    begin
      if kz2.Detail[I].InstanceName = kz1.Detail[J].InstanceName then
      begin
        kz2.Detail[I].InstanceCount := kz2.Detail[I].InstanceCount - kz1.Detail[J].InstanceCount;
        kz2.Detail[I].totalSize := kz2.Detail[I].totalSize - kz1.Detail[J].totalSize;
        Break;
      end;
    end;
  end;
  AllocatedtotalSize := 0;
  for I := 0 to kz2.ObjCnt - 1 do
  begin
    AllocatedtotalSize := AllocatedtotalSize + kz2.Detail[I].totalSize;
  end;
  kz2.Allocated := AllocatedtotalSize div 1024;
end;

function LMMSS2Str(kz: PLogMemoryManagerState): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  Result.Capacity := kz.ObjCnt + 10;
  Result.Add(Format('Allocated:%dK', [kz.Allocated]));
  Result.Add(Format('Overhead:%dK', [kz.Overhead]));
  Result.Add(Format('Efficiency:%dK', [kz.Efficiency]));
  Result.Add(Format('ObjCnt:%d'#$D#$A#$D#$A, [kz.ObjCnt]));
  for I := 0 to kz.ObjCnt - 1 do
  begin
    if kz.Detail[I].InstanceCount > 0 then
      Result.Add(Format('%d bytes: %s x %d ', [kz.Detail[I].totalSize, kz.Detail[I].InstanceName, kz.Detail[I].InstanceCount]));
  end;
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
  kz222: PLogMemoryManagerState;
  LMMSScompareoutData:TStringList;
begin
  Result := SUCCEED;
  try
    try
      if srv_rpcparams(pSrvProc) < 1 then
      begin
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
          PageLog_save;
        end
        else if action = 'E' then
        begin
          SqlSvr_SendMsg(pSrvProc, 'dbid:' + inttostr(cfg.CFG_DBids));
        end
        else if action = 'F' then
        begin
          d_unhook(pSrvProc);
          exitAllThread;
        end
        else if action = 'G' then
        begin
          srv_describe(pSrvProc, 1, 'status', SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), nil);
          if SVR_hookPnt_Row>0 then
          begin
            tmpint := 1
          end else begin
            tmpint := 0
          end;
          srv_setcoldata(pSrvProc, 1, @tmpint);
          srv_sendrow(pSrvProc);
        end
        else if action = 'V' then
        begin
          srv_describe(pSrvProc, 1, 'version', SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), nil);
          tmpint := ModuleVersion;
          srv_setcoldata(pSrvProc, 1, @tmpint);
          srv_sendrow(pSrvProc);
        end else if action = 'Tbase' then
        begin
          if LMMSkzbase <> nil then
            VirtualFree(LMMSkzbase, 0, MEM_RELEASE);
          LMMSkzbase := LogMemoryManagerStateToStruct;
          SqlSvr_SendMsg(pSrvProc, 'ok');
        end
        else if action = 'Tcb' then
        begin
          if LMMSkzbase = nil then
            LMMSkzbase := LogMemoryManagerStateToStruct;
          kz222 := LogMemoryManagerStateToStruct;
          LMMSScompare(LMMSkzbase, kz222);
          LMMSScompareoutData := LMMSS2Str(kz222);
          SqlSvr_SendMsg(pSrvProc, LMMSScompareoutData.Text);
          VirtualFree(kz222, 0, MEM_RELEASE);
          LMMSScompareoutData.Free;
        end else if action = 'Tpc' then
        begin
          kz222 := LogMemoryManagerStateToStruct;
          LMMSScompareoutData := LMMSS2Str(kz222);
          VirtualFree(kz222, 0, MEM_RELEASE);
          SqlSvr_SendMsg(pSrvProc, LMMSScompareoutData.Text);
          LMMSScompareoutData.Free;
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
    if PageLog_load(dbid, Lsn1, lsn2, lsn3, memory) then
    begin
      lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
      srv_setcoldata(pSrvProc, 1, lsnVal);
      srv_setcoldata(pSrvProc, 2, memory.Memory);
      srv_setcollen(pSrvProc, 2, memory.Size);
      srv_sendrow(pSrvProc);
    end else begin
      if _Lc_Get_PaddingDataCnt>0 then
      begin
        Sleep(2000);  //首次失败休息两秒再试，可能内容还未保存
        SqlSvr_SendMsg(pSrvProc, 'Retry...');
        if PageLog_load(dbid, Lsn1, lsn2, lsn3, memory) then
        begin
          lsnVal := PAnsiChar(AnsiString(Format('%.8x:%.8x:%.4x', [Lsn1, lsn2, lsn3])));
          srv_setcoldata(pSrvProc, 1, lsnVal);
          srv_setcoldata(pSrvProc, 2, memory.Memory);
          srv_setcollen(pSrvProc, 2, memory.Size);
          srv_sendrow(pSrvProc);
        end;
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

      end;
  end;
end;

procedure Lr_doo_test;
var
  mmO: TMemoryStream;
begin
  mmO := TMemoryStream.Create;
  try
    PageLog_load(5, 161, $A0, 2, mmO);
    DefLoger.Add(DumpMemory2Str(mmO.Memory, mmO.Size));
  finally
    mmO.Free;
  end;
end;

exports
  PageLog_save name 'savePageLog2',
  {$IFDEF DEBUG}
  Lr_doo_test,
  d_example,
  {$ENDIF}
  Lr_doo,
  exitAllThread,
  Lr_roo;

begin
  DLLProc := @DLLMainHandler; //动态库地址告诉系统，结束的时候执行卸载
  DLLMainHandler(DLL_PROCESS_ATTACH);

  {$IFDEF DEBUG}
  //test code
  pageCapture_init('project1.exe');
  {$ENDIF}

  HookpreInit;
end.


//设置目录允许sqlserver访问
//cacls "c:\data" /T /e /g MSSQLSERVER:f
