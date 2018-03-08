unit SqlSvrHelper;

interface

uses
  MsOdsApi;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg: PAnsiChar); overload;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg: string); overload;

function getParam_int(pSrvProc: SRV_PROC; ParamIdx:Integer):UInt64;

implementation

uses
  Winapi.Windows;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg: PAnsiChar);
begin
  if pSrvProc <> nil then
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, msg, SRV_NULLTERM);
end;

procedure SqlSvr_SendMsg(pSrvProc: SRV_PROC; msg: string);
begin
  if pSrvProc <> nil then
    srv_sendmsg(pSrvProc, SRV_MSG_INFO, 0, 0, 0, nil, 0, 0, PAnsiChar(AnsiString(msg)), SRV_NULLTERM);
end;

function getParam_int(pSrvProc: SRV_PROC; ParamIdx:Integer):UInt64;
var
  bNull: BOOL;
  bType: BYTE;
  uLen: ULONG;
  uMaxLen: ULONG;
  DataBuf: array of Byte;
begin
  srv_paraminfo(pSrvProc, ParamIdx, @bType, @uMaxLen, @uLen, nil, @bNull);
  SetLength(DataBuf, uLen + 2);
  ZeroMemory(@DataBuf[0], uLen + 2);
  srv_paraminfo(pSrvProc, ParamIdx, @bType, @uMaxLen, @uLen, @DataBuf[0], @bNull);

  if uLen = 1 then
  begin
    Result := PByte(@DataBuf[0])^;
  end
  else if uLen = 2 then
  begin
    Result := PWORD(@DataBuf[0])^;
  end
  else if (uLen = 3) or (uLen = 4) then
  begin
    Result := PDWORD(@DataBuf[0])^;
  end
  else
  begin
    Result := PUInt64(@DataBuf[3])^;
  end;
  SetLength(DataBuf, 0);
end;

end.

