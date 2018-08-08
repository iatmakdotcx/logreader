library Hooktest;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Log4D in '..\..\Common\Log4D.pas',
  loglog in '..\..\Common\loglog.pas',
  MsOdsApi in '..\..\Extdll\MsOdsApi.pas',
  SqlSvrHelper in '..\..\Extdll\SqlSvrHelper.pas';



function hook(hp: UINT_PTR): Boolean;stdcall;
var
  sqlminBase: Thandle;
begin
  sqlminBase := GetModuleHandle('sqlmin.dll');
  Loger.Add('sqlminBase:%.16X', [sqlminBase], LOG_INFORMATION);

end;

function unhook: Boolean;stdcall;
begin

end;

function t_oo(pSrvProc: SRV_PROC): Integer; cdecl;
var
  tmpint: Integer;
begin
  Result := SUCCEED;
  try
    try
      if srv_rpcparams(pSrvProc) < 1 then
      begin
        SqlSvr_SendMsg(pSrvProc, 'd_oo');
      end
      else
      begin
        tmpint := getParam_int(pSrvProc, 1);
        SqlSvr_SendMsg(pSrvProc, 'hP:'+inttostr(tmpint));
        hook(tmpint);

      end;
    except
      on e: Exception do
      begin
        srv_sendmsg(pSrvProc, SRV_MSG_ERROR, 0, 0, 0, nil, 0, 0, PAnsiChar(AnsiString(e.Message)), SRV_NULLTERM);
      end;
    end;
  finally
    srv_senddone(pSrvProc, SRV_DONE_FINAL or SRV_DONE_COUNT, 0, 0);
  end;

end;


exports
  hook,
  unhook,
  t_oo;

{$R *.res}



begin

end.

