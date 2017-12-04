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
  SysUtils,
  Classes,
  HashHelper in 'HashHelper.pas',
  MsOdsApi in 'MsOdsApi.pas',
  Winapi.Windows,
  SqlSvrHelper in 'SqlSvrHelper.pas',
  dbhelper in 'dbhelper.pas',
  pageCapture in 'pageCapture.pas';

{$R *.res}



function HookFailMsg(ErrCode:Integer):string;
begin
  case ErrCode of
    0:Result := '成功';
    1:Result := '数据捕获程序已安装';
    2:Result := 'sqlmin加载失败';
    3:Result := '数据捕获点不正确(位置不可读)';
    4:Result := '数据捕获点不正确(内容效验失败)';
    5:Result := '数据捕获点区域效验失败';
    6:Result := '';
    7:Result := '';
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
      on e:Exception do
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


function d_checkSqlSvr(pSrvProc: SRV_PROC): Integer; cdecl;
var
  hdl:tHandle;
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  sqlminMD5:string;

  hookPnt:Integer;
  dllPath:string;
begin
  Result := SUCCEED;
  hdl := GetModuleHandle('sqlmin.dll');
  if hdl=0 then
  begin
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, 'Error:sqlmin.dll加载失败', SRV_NULLTERM);
  end else begin
    ZeroMemory(@Pathbuf[0], MAX_PATH + 2);
    GetModuleFileName(hdl, Pathbuf, MAX_PATH);
    sqlminMD5 := GetFileHashMD5(Pathbuf);

    SqlSvr_SendMsg(pSrvProc, string(Pathbuf));
    SqlSvr_SendMsg(pSrvProc, sqlminMD5);

    GetModuleFileName(HInstance, Pathbuf, MAX_PATH);
    SqlSvr_SendMsg(pSrvProc, string(Pathbuf));

    TEstSrvProc :=pSrvProc;
    try
      dbhelper.init;
      if DBH.checkMd5(sqlminMD5) then
      begin
        SqlSvr_SendMsg(pSrvProc, '准备加载已知方案');
        if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
        begin
          pageCapture_init(dllPath);
          hookPnt := _Lc_doHook(hookPnt);
          if hookPnt>0 then
          begin
            //hook fail
            SqlSvr_SendMsg(pSrvProc, 'ERROR:'+HookFailMsg(hookPnt));
          end;
        end;
      end
      else
      begin
        //TODO:如何是好
        SqlSvr_SendMsg(pSrvProc, '为确认的数据采集方案');


      end;
    except
      on e:Exception do
      begin
        SqlSvr_SendMsg(pSrvProc, e.Message);
      end;
    end;
    srv_senddone(pSrvProc, SRV_DONE_FINAL, 0, 0);
  end;

end;


exports
  d_example,
  d_checkSqlSvr;

begin

end.

