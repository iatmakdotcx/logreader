unit SqlSvrHelper;

interface
uses
  MsOdsApi;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg:PAnsiChar);overload;
procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg:string);overload;

implementation


procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg:PAnsiChar);
begin
  srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, msg, SRV_NULLTERM);
end;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg:string);
begin
  srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, PAnsiChar(AnsiString(msg)), SRV_NULLTERM);
end;


end.
