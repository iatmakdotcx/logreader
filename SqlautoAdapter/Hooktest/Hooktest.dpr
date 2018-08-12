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
  EMemLeaks,
  EResLeaks,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EDebugExports,
  EFixSafeCallException,
  EMapWin32,
  ExceptionLog7,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  System.SyncObjs,
  Winapi.Messages,
  Log4D in '..\..\Common\Log4D.pas',
  loglog in '..\..\Common\loglog.pas',
  MsOdsApi in '..\..\Extdll\MsOdsApi.pas',
  SqlSvrHelper in '..\..\Extdll\SqlSvrHelper.pas',
  disassembler in '..\..\Common\disassembler.pas',
  Memory_Common in 'H:\Delphi\通用的自定义单元\Memory_Common.pas',
  p_structDefine in '..\..\D_logreader\p_structDefine.pas';

type
  PPipeBBData = ^TPipeBBData;
  TPipeBBData=packed record
    head:Byte;
    dbid:Word;
    lsn:Tlog_LSN;
    rawdata:array[0..0] of Byte;
  end;

const
  pipeName='\\.\pipe\hooktest';

var
  _critical : TCriticalSection;
  Sqlmin_PageRef_ModifyColumnsInternal_Ptr:UInt_Ptr = 0;
  Sqlmin_PageRef_ModifyColumnsInternal_Data:Pointer = nil;
  Sqlmin_PageRef_ModifyColumnsInternal_Len:Cardinal = 0;
  CfgViewFPipe:THandle = 0;

procedure interLockSetVal_128(addr:Pointer;data:Pointer);
asm
  movq xmm0,[rdx]
  movq [rcx],xmm0
end;

procedure llll_Send(aMsg:string);
var
  Data: TBytes;
  nSent:Cardinal;
  Rv:Byte;
begin
  if CfgViewFPipe=0 then
  begin
    CfgViewFPipe := CreateFile(pipeName, GENERIC_READ or GENERIC_WRITE,
      FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
    if CfgViewFPipe=INVALID_HANDLE_VALUE then
    begin
      loger.EnableCallback := False;
      loger.Add('!!!!!!!!! 打开管道失败 '+SysErrorMessage(GetLastError), LOG_ERROR);
      loger.EnableCallback := True;
      CfgViewFPipe := 0;
    end;
  end;
  if CfgViewFPipe>0 then
  begin
    Data := TEncoding.UTF8.GetBytes(aMsg);
    WriteFile(CfgViewFPipe, Data[0], Length(Data), nSent, nil);
    ReadFile(CfgViewFPipe, Rv, 1, nSent, nil);
  end;
end;

procedure msgOut(aMsg: string; level: Integer);
begin
  llll_Send(aMsg);
end;

procedure domyWork_2(PageRef:Pointer; stackRsp:Pointer);stdcall;
var
  PageType:byte;
  XdesRMFull:Pointer;
  rawdata:Pointer;
  dbid:Word;
  LSN:Plog_LSN;
  RawLen:WORD;
  ResPnt:Pointer;
  nSent:Cardinal;
  Rv:Byte;
  pbb:PPipeBBData;
begin
  try
    if IsBadReadPtr(PageRef, 8) then
    begin
      Loger.Add('!!!!!!!!!!!!!!PageRef 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    PageRef := Pointer(PUINT_PTR(PageRef)^);
    if IsBadReadPtr(PageRef, 8) then
    begin
      Loger.Add('!!!!!!!!!!!!!!PageRef::base 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    PageRef := Pointer(PUINT_PTR(PageRef)^);
    if IsBadReadPtr(PageRef, 8) then
    begin
      Loger.Add('!!!!!!!!!!!!!!Page::data 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    PageType := Pbyte(UINT_PTR(PageRef) + 1)^;
    if (PageType <> 1) and (PageType <> 3) then
    begin
      Loger.Add('===================PageType:%d===================', [PageType], LOG_ERROR);
      Exit;
    end;
    Loger.Add('PageRef.type 效验通过！', LOG_INFORMATION);
    XdesRMFull := PPointer(UINT_PTR(stackRsp) + $E0)^;
    rawdata := PPointer(UINT_PTR(stackRsp) + $108)^;
    if IsBadReadPtr(XdesRMFull, $464) then
    begin
      Loger.Add('!!!!!!!!!!!!!!XdesRMFull 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    dbid := PWord(UINT_PTR(XdesRMFull) + $460)^;
    Loger.Add('dbid:%d', [dbid], LOG_INFORMATION);
    if dbid=0 then
    begin
      Exit;
    end;
    LSN := Plog_LSN(UINT_PTR(XdesRMFull) + $32c);
    Loger.Add('LSN:%.8x:%.8x:%.4x', [LSN.LSN_1, LSN.LSN_2, LSN.LSN_3], LOG_INFORMATION);
    if IsBadReadPtr(rawdata, $8) then
    begin
      Loger.Add('!!!!!!!!!!!!!!rawdata 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    rawdata := PPointer(rawdata)^;
    if IsBadReadPtr(rawdata, $10) then
    begin
      Loger.Add('!!!!!!!!!!!!!!rawdata:stack 无效!!!!!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
    RawLen := PWord(UINT_PTR(rawdata) + 4)^;
    Loger.Add('RawLen:%d(0x%.4x)', [RawLen, RawLen], LOG_INFORMATION);
    rawdata := PPointer(UINT_PTR(rawdata) + 8)^;
    RawLen := PageRowCalcLength(rawdata);
    Loger.Add('CalcRawLen:%d(0x%.4x)', [RawLen, RawLen], LOG_INFORMATION);
    Loger.Add('=======================Dump=========================' + #$D#$A + bytestostr(rawdata, RawLen), LOG_INFORMATION);

    ResPnt := GetMemory(RawLen+$10);
    pbb:=PPipeBBData(ResPnt);
    pbb.head := $bb;
    pbb.dbid := dbid;
    pbb.lsn := LSN^;
    CopyMemory(@pbb.rawdata, rawdata, RawLen);
    if CfgViewFPipe>0 then
    begin
      WriteFile(CfgViewFPipe, ResPnt^, RawLen+$10, nSent, nil);
      ReadFile(CfgViewFPipe, Rv, 1, nSent, nil);
    end;
    FreeMem(ResPnt);
  except
    on eee:Exception do
    begin
      Loger.Add('=======================Exception========================='+eee.Message);
    end;
  end;
end;

procedure doWordEnd;
asm
  db $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90
  db $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90
  db $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90
  db $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90
  db $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90,  $90,$90,$90,$90
end;

procedure doWord;
asm
  push rbp
	push rax
	push rbx
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
	push rdi
	push rsi

	sub rsp,20h  //; shadow space

	mov rdx, rsp
	call domyWork_2

	add rsp,20h

	pop rsi
	pop rdi
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rbx
	pop rax
	pop rbp

  jmp doWordEnd;
end;

function TestHookEntry(pSrvProc: SRV_PROC; hp: UINT_PTR): Boolean;stdcall;
var
  sqlminBase: Thandle;
  ModifyColumnsInternalAddr:UINT_PTR;
  dis:TDisassembler;
  TmpPnt:UINT_PTR;
  I:Integer;
  disStr,disDesc:string;
begin
  Result := false;
  sqlminBase := GetModuleHandle('sqlmin.dll');
  Loger.Add('sqlminBase:%.16X,hp:%d', [sqlminBase, hp], LOG_INFORMATION);
  ModifyColumnsInternalAddr := sqlminBase + hp;

  if (IsBadReadPtr(Pointer(ModifyColumnsInternalAddr - $10), $30)) then
  begin
    Loger.Add('!!!!!!!!!!!!!!!!!!IsBadReadPtr:%.8X!!!!!!!!!!!!!!', [ModifyColumnsInternalAddr], LOG_ERROR);
    Exit;
  end;

  if (PWORD(ModifyColumnsInternalAddr - 2)^ <> $9090) and
     (PWORD(ModifyColumnsInternalAddr - 2)^ <> $CCCC) then
  begin
    //一般函数头前面都是9090或者CCCC分隔。
    Loger.Add('!!!!!!!!!!!!!!!!!!函数头分隔效验失败!!!!!!!!!!!!!!', LOG_ERROR);
    Exit;
  end;

  //-------------------
  TmpPnt := ModifyColumnsInternalAddr;
  disStr := '';
  dis := TDisassembler.Create(True);
  for I := 0 to 10 do
  begin
    disStr := disStr + #$D#$A + dis.disassemble(TmpPnt, disDesc);
  end;
  dis.Free;
  //Loger.Add(disStr);
  //SqlSvr_SendMsg(pSrvProc, disStr);
  //------------------------------

  //一般函数开头都会有一堆push（先效验4个
  TmpPnt := ModifyColumnsInternalAddr;
  dis := TDisassembler.Create(True);
  for I := 0 to 4 do
  begin
    dis.disassemble(TmpPnt, disDesc);
    if dis.LastDisassembleData.opcode <> 'push' then
    begin
      Loger.Add('!!!!!!!!!!!!!!!!!!函数头入栈效验失败!!!!!!!!!!!!!!', LOG_ERROR);
      Exit;
    end;
  end;
  dis.Free;
  Loger.Add('入口效验通过！', LOG_INFORMATION);

  Result := True
end;

function hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked: Boolean;stdcall;
begin
  if (Sqlmin_PageRef_ModifyColumnsInternal_Data <> nil) and
		(Sqlmin_PageRef_ModifyColumnsInternal_Len > 0) and
		(Sqlmin_PageRef_ModifyColumnsInternal_Ptr > 0) and
		(not CompareMem(Sqlmin_PageRef_ModifyColumnsInternal_Data,
       Pointer(Sqlmin_PageRef_ModifyColumnsInternal_Ptr),
       Sqlmin_PageRef_ModifyColumnsInternal_Len)) then
	begin
		Result := True;
	end
	else begin
		Result := False;
	end
end;

procedure hook_sqlmin_PageRef_ModifyColumnsInternal_x64_unhook;
begin
  if hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked then
  begin
    PUINT_PTR(Sqlmin_PageRef_ModifyColumnsInternal_Ptr)^ := PUINT_PTR(Sqlmin_PageRef_ModifyColumnsInternal_Data)^;
    //interLockSetVal_128(Pointer(Sqlmin_PageRef_ModifyColumnsInternal_Ptr), Sqlmin_PageRef_ModifyColumnsInternal_Data);
  end;
end;

procedure hook_sqlmin_PageRef_ModifyColumnsInternal_x64(hook_Ptr, sqlminBase: UINT_PTR);
const
  MinOpcLen = 6; //最小需要的空间   jmp []
var
  dis:TDisassembler;
  TmpPnt:UINT_PTR;
  I:Integer;
  disDesc:string;
  hookPntData:UINT_PTR;
  dwOldP:Cardinal;
begin
  if not hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked then
  begin
    Sqlmin_PageRef_ModifyColumnsInternal_Ptr := sqlminBase + hook_Ptr;
    CopyMemory(Sqlmin_PageRef_ModifyColumnsInternal_Data, Pointer(Sqlmin_PageRef_ModifyColumnsInternal_Ptr), $20);

    TmpPnt := Sqlmin_PageRef_ModifyColumnsInternal_Ptr;
    dis := TDisassembler.Create(SizeOf(Pointer) = 8);
    for I := 0 to 10 do
    begin
      dis.disassemble(TmpPnt, disDesc);
      if TmpPnt-(Sqlmin_PageRef_ModifyColumnsInternal_Ptr) >= MinOpcLen then
      begin
        Break;
      end;
    end;
    dis.Free;
    Sqlmin_PageRef_ModifyColumnsInternal_Len := TmpPnt - (Sqlmin_PageRef_ModifyColumnsInternal_Ptr);
    //
    VirtualProtect(Pointer(sqlminBase + $20), 8, PAGE_READWRITE, dwOldP);
		PUINT_PTR(sqlminBase + $20)^ := UINT_PTR(@doWord);
    //back
    VirtualProtect(@doWordEnd, $20, PAGE_EXECUTE_READWRITE, dwOldP);
    CopyMemory(@doWordEnd, Pointer(Sqlmin_PageRef_ModifyColumnsInternal_Ptr), Sqlmin_PageRef_ModifyColumnsInternal_Len);
    PWord(UINT_PTR(@doWordEnd)+ Sqlmin_PageRef_ModifyColumnsInternal_Len)^ := $25FF;
    PDWord(UINT_PTR(@doWordEnd)+ Sqlmin_PageRef_ModifyColumnsInternal_Len + 2)^ := 0;
    PUINT_PTR(UINT_PTR(@doWordEnd)+ Sqlmin_PageRef_ModifyColumnsInternal_Len + 6)^ := UINT_PTR(Sqlmin_PageRef_ModifyColumnsInternal_Ptr + Sqlmin_PageRef_ModifyColumnsInternal_Len);
    //hook
    VirtualProtect(Pointer(Sqlmin_PageRef_ModifyColumnsInternal_Ptr), $10, PAGE_EXECUTE_READWRITE, dwOldP);
    hookPntData := ((sqlminBase + $20 - Sqlmin_PageRef_ModifyColumnsInternal_Ptr) and $FFFFFFFF) - MinOpcLen;
    TmpPnt := PUINT_PTR(Sqlmin_PageRef_ModifyColumnsInternal_Ptr)^;
    TmpPnt := (TmpPnt and $FFFF000000000000) or $25FF;
    hookPntData := hookPntData shl 16;
    TmpPnt := TmpPnt or hookPntData;
    PUINT_PTR(Sqlmin_PageRef_ModifyColumnsInternal_Ptr)^ := TmpPnt;
  end;
end;

function hook(pSrvProc: SRV_PROC; hp: UINT_PTR): Integer;stdcall;
var
  sqlminBase: Thandle;
  Rv:Byte;
  nSent:Cardinal;
begin
  _critical.Enter;
  try
    Result := -1;
    if hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked then
    begin
      Loger.Add('尝试重复hook', LOG_ERROR);
      Exit;
    end;
    sqlminBase := GetModuleHandle('sqlmin.dll');
    if sqlminBase = 0 then
    begin
      Loger.Add('hook 失败!!! Sqlmin 加载失败!', LOG_ERROR);
      Exit;
    end;
    hook_sqlmin_PageRef_ModifyColumnsInternal_x64(hp, sqlminBase);
    if hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked then
    begin
      Loger.Add('===================hook=====================', LOG_INFORMATION);
      if CfgViewFPipe>0 then
      begin
        Rv := $bc;
        WriteFile(CfgViewFPipe, Rv, 1, nSent, nil);
        ReadFile(CfgViewFPipe, Rv, 1, nSent, nil);
      end;
    end;
    Result := SUCCEED;
  finally
    _critical.Leave;
  end;
end;

procedure unhook;stdcall;
begin
  _critical.Enter;
  try
    hook_sqlmin_PageRef_ModifyColumnsInternal_x64_unhook;
  finally
    _critical.Leave;
  end;
end;

function t_oo(pSrvProc: SRV_PROC): Integer; cdecl;
var
  tmpint: Integer;
  action: Integer;
begin
  Result := SUCCEED;
  try
    try
      if srv_rpcparams(pSrvProc) < 2 then
      begin
        SqlSvr_SendMsg(pSrvProc, 'd_oo need params');
      end
      else
      begin
        action := getParam_int(pSrvProc, 1);
        if action=0 then
        begin
          //test hook point entry
          if CfgViewFPipe>0 then
          begin
            CloseHandle(CfgViewFPipe);
            CfgViewFPipe := 0;
          end;
          tmpint := getParam_int(pSrvProc, 2);
          if TestHookEntry(pSrvProc, tmpint) then
            hook(pSrvProc, tmpint);
        end else if action=1 then begin
          //hook
          tmpint := getParam_int(pSrvProc, 2);
          hook(pSrvProc, tmpint);
        end else if action=2 then begin
          unhook;
          Loger.Add('=============unhook=============');
        end else if action=100 then begin
          SqlSvr_SendMsg(pSrvProc, 'ok');
        end;
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

procedure DLLMainHandler(Reason: Integer);
begin
  case Reason of
    DLL_PROCESS_ATTACH:
      begin
        Sqlmin_PageRef_ModifyColumnsInternal_Data := GetMemory($1000);
        _critical := TCriticalSection.Create;
        loger.registerCallBack(msgOut);
      end;
    DLL_PROCESS_DETACH:
      begin
        unhook;
        FreeMem(Sqlmin_PageRef_ModifyColumnsInternal_Data);
        _critical.Free;
        if CfgViewFPipe>0 then
         CloseHandle(CfgViewFPipe);
      end;
  end;
end;

exports
  hook,
  unhook,
  t_oo;

{$R *.res}

begin
  DLLProc := @DLLMainHandler;
  DLLMainHandler(DLL_PROCESS_ATTACH);
end.

