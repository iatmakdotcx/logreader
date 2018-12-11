unit MakCommonfuncs;

interface

uses
  Windows, SysUtils, Registry, Classes;

type
  //https://msdn.microsoft.com/en-us/library/windows/desktop/aa379626(v=vs.85).aspx
  _TOKEN_INFORMATION_CLASS = (TokenUser = 1, TokenGroups, TokenPrivileges, TokenOwner, TokenPrimaryGroup, TokenDefaultDacl, TokenSource, TokenType, TokenImpersonationLevel, TokenStatistics, TokenRestrictedSids, TokenSessionId, TokenGroupsAndPrivileges, TokenSessionReference, TokenSandBoxInert, TokenAuditPolicy, TokenOrigin, TokenElevationType, TokenLinkedToken, TokenElevation, TokenHasRestrictions, TokenAccessInformation, TokenVirtualizationAllowed, TokenVirtualizationEnabled, TokenIntegrityLevel,
    TokenUIAccess, TokenMandatoryPolicy, TokenLogonSid, TokenIsAppContainer, TokenCapabilities, TokenAppContainerSid, TokenAppContainerNumber, TokenUserClaimAttributes, TokenDeviceClaimAttributes, TokenRestrictedUserClaimAttributes, TokenRestrictedDeviceClaimAttributes, TokenDeviceGroups, TokenRestrictedDeviceGroups, TokenSecurityAttributes, TokenIsRestricted, MaxTokenInfoClass);

  TOKEN_INFORMATION_CLASS = _TOKEN_INFORMATION_CLASS;

const
  {$IFDEF UNICODE}
  AWSuffix = 'W';
  {$ELSE}
  AWSuffix = 'A';
  {$ENDIF UNICODE}
  SE_GROUP_LOGON_ID = $C0000000;

function ConvertSidToStringSidA(Sid: PSID; var StringSid: LPSTR): BOOL; stdcall; external advapi32;
{$EXTERNALSYM ConvertSidToStringSidA}

function ConvertSidToStringSidW(Sid: PSID; var StringSid: LPWSTR): BOOL; stdcall; external advapi32;
{$EXTERNALSYM ConvertSidToStringSidW}

function ConvertSidToStringSid(Sid: PSID; var StringSid: LPTSTR): BOOL; stdcall; external advapi32 name 'ConvertSidToStringSid' + AWSuffix;
{$EXTERNALSYM ConvertSidToStringSid}

function GetFileSizeEx(hFile: THANDLE; var lpFileSize: LARGE_INTEGER): BOOL; stdcall; external kernel32;
{$EXTERNALSYM GetFileSizeEx}

function SetFilePointerEx(hFile: THANDLE; liDistanceToMove: TLargeInteger; lpNewFilePointer: PLargeInteger; dwMoveMethod: DWORD): BOOL; stdcall; external kernel32;
{$EXTERNALSYM SetFilePointerEx}

function GetFinalPathNameByHandleA(hFile: THANDLE; lpszFilePath: LPSTR; cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall; external kernel32;

function GetFinalPathNameByHandleW(hFile: THANDLE; lpszFilePath: LPWSTR; cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall; external kernel32;

function GetFinalPathNameByHandle(hFile: THANDLE; lpszFilePath: LPTSTR; cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall; external kernel32 name 'GetFinalPathNameByHandle' + AWSuffix;

function IsRunningAsAdmin: Boolean;

function IsEnableUAC: Boolean;

function FindSvrSwitch(const Switch: string; const Chars: TSysCharSet; IgnoreCase: Boolean = true): Boolean;

function FindSvrSwitchValue(const Switch: string; const Chars: TSysCharSet; IgnoreCase: Boolean = true): string;

function searchAllFile(dir: string): TStringList;
function searchAllFileAdv(dir: string): TStringList;

function setDebugPrivilege: Boolean;

function GetLoginSid: string;

function DuplicateHandleToCurrentProcesses(Pid: Cardinal; hdl: Cardinal): THandle; stdcall;

function GetFileProductVersionAsString(FileName:string=''): string;

function GetFileVersionAsString(FileName:string=''): string;
/// <summary>
/// 在cmd中执行命令，并获取控制台返回内容
/// </summary>
/// <param name="Command"></param>
/// <returns></returns>
function GetDosOutput(Command: string): string;


implementation
{$WARN SYMBOL_PLATFORM OFF}


function searchAllFile(dir: string): TStringList;
var
  targetpath: string;
  sr: TSearchRec;
  li, temp: TStringList;
  i: Integer;
  ExtN: string;
begin
  li := TStringList.Create;
  try
    ExtN := ExtractFileName(dir);
    targetpath := ExtractFilePath(dir); //分解路径名；
    if FindFirst(dir, faAnyFile xor faSysFile, sr) = 0 then
      repeat
        if (sr.Name <> '.') and (sr.Name <> '..') then
        begin
          if (sr.Attr and faDirectory) > 0 then
          begin
            temp := searchAllFile(targetpath + sr.Name + '\' + ExtN);
            try
              for i := 0 to temp.count - 1 do
                li.Add(temp[i]);
            finally
              temp.Free;
            end;
          end
          else
          begin
            li.Add(targetpath + sr.Name);
          end;
        end;
      until (FindNext(sr) <> 0);
  finally
    result := li;
  end;
end;

function searchAllFileAdv(dir: string): TStringList;
var
  targetpath: string;
  sr: TSearchRec;
  li, temp: TStringList;
  i: Integer;
  ExtN: string;
begin
  li := TStringList.Create;
  try
    ExtN := ExtractFileName(dir);
    targetpath := ExtractFilePath(dir); //分解路径名；
    if FindFirst(dir, faArchive xor faSysFile, sr) = 0 then
      repeat
        if (sr.Name <> '.') and (sr.Name <> '..') then
        begin
          if (sr.Attr and faDirectory) = 0 then
          begin
            li.Add(targetpath + sr.Name);
          end;
        end;
      until (FindNext(sr) <> 0);

    if FindFirst(targetpath + '*', faDirectory, sr) = 0 then
      repeat
        if (sr.Name <> '.') and (sr.Name <> '..') then
        begin
          if (sr.Attr and faDirectory) > 0 then
          begin
            temp := searchAllFileAdv(targetpath + sr.Name + '\' + ExtN);
            try
              for i := 0 to temp.count - 1 do
                li.Add(temp[i]);
            finally
              temp.Free;
            end;
          end;
        end;
      until (FindNext(sr) <> 0);

  finally
    result := li;
  end;
end;

function IsRunningAsAdmin: Boolean;
var
  TokenHandle: THandle;
  pRetLen: Dword;
  pppp:_TOKEN_ELEVATION ;
  GetTokenInformation: function(TokenHandle: THandle; TokenInformationClass: _TOKEN_INFORMATION_CLASS; TokenInformation: Pointer; TokenInformationLength: DWORD; var ReturnLength: DWORD): BOOL; stdcall;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, TokenHandle) then
  begin
    @GetTokenInformation := @Windows.GetTokenInformation;
    if GetTokenInformation(TokenHandle, TokenElevation, @pppp, SizeOf(_TOKEN_ELEVATION), pRetLen) and (pRetLen = SizeOf(_TOKEN_ELEVATION)) then
    begin
      Result := pppp.TokenIsElevated = 1;
    end;
    CloseHandle(TokenHandle);
  end;
end;

function GetLoginSid: string;
var
  TokenHandle: THandle;
  pRetLen: Dword;
  GetTokenInformation: function(TokenHandle: THandle; TokenInformationClass: _TOKEN_INFORMATION_CLASS; TokenInformation: Pointer; TokenInformationLength: DWORD; var ReturnLength: DWORD): BOOL; stdcall;
  ptg: PTokenGroups;
  I: Integer;
  pStringSid: LPTSTR;
begin
  Result := '';
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, TokenHandle) then
  begin
    ptg := nil;
    @GetTokenInformation := @Windows.GetTokenInformation;
    if not GetTokenInformation(TokenHandle, TokenGroups, ptg, 0, pRetLen) then
    begin
      if ERROR_INSUFFICIENT_BUFFER = GetLastError then
      begin
        ptg := HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, pRetLen);
        if GetTokenInformation(TokenHandle, TokenGroups, ptg, pRetLen, pRetLen) then
        begin
          //OutputDebugString(PChar(Format('共找到%d个组SID',[ptg.GroupCount])));
          for I := 0 to ptg.GroupCount - 1 do
          begin
            //ConvertSidToStringSid(ptg.Groups[i].Sid, pStringSid);
            //OutputDebugString(PChar(Format('%d:%s',[ptg.GroupCount,StrPas(pStringSid)])));
            if (ptg.Groups[I].Attributes and SE_GROUP_LOGON_ID) = SE_GROUP_LOGON_ID then
            begin
              ConvertSidToStringSid(ptg.Groups[I].Sid, pStringSid);
              Result := StrPas(pStringSid);
            end;
          end;
        end;
      end;
    end;
    CloseHandle(TokenHandle);
  end;
end;

procedure SetPrivilege;
var
  OldTokenPrivileges, TokenPrivileges: TTokenPrivileges;
  ReturnLength: dword;
  hToken: THandle;
  Luid: int64;
begin
  if OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES, hToken) then
  begin
    if LookupPrivilegeValue(nil, 'SeDebugPrivilege', Luid) then
    begin
      TokenPrivileges.PrivilegeCount := 1;
      TokenPrivileges.Privileges[0].Luid := Luid;
      TokenPrivileges.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
      AdjustTokenPrivileges(hToken, False, TokenPrivileges, SizeOf(TTokenPrivileges), OldTokenPrivileges, ReturnLength);
    end;

    CloseHandle(hToken);
  end;
end;

function setDebugPrivilege: Boolean;
var
  TokenHandle: THandle;
  NewState: TTokenPrivileges;
  BufferIsNull: DWORD;
  lpLuid: TLargeInteger;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, TokenHandle) then
  begin
    if (LookupPrivilegeValue(nil, 'SeDebugPrivilege', lpLuid)) then
    begin
      NewState.PrivilegeCount := 1;
      NewState.Privileges[0].Luid := lpLuid;
      NewState.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;

      BufferIsNull := 0;
      AdjustTokenPrivileges(TokenHandle, False, NewState, SizeOf(TOKEN_PRIVILEGES), nil, BufferIsNull);
      result := GetLastError() = 0;
    end;
    CloseHandle(TokenHandle);
  end;
end;

function IsEnableUAC: Boolean;
const
  SubKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\';
var
  Reg: TRegistry;
  EnableLUA: DWORD;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    Reg.OpenKey(SubKey, False);
    EnableLUA := Reg.ReadInteger('EnableLUA');
  finally
    Reg.free;
  end;
  Result := EnableLUA <> 0;
end;

function FindSvrSwitch(const Switch: string; const Chars: TSysCharSet; IgnoreCase: Boolean = true): Boolean;
var
  I: Integer;
  S: string;
begin
  for I := 1 to System.ParamCount do
  begin
    S := System.ParamStr(I);
    if (Chars = []) or (AnsiString(S)[1] in Chars) then
      if IgnoreCase then
      begin
        if (AnsiCompareText(Copy(S, 2, Maxint), Switch) = 0) then
        begin
          Result := True;
          Exit;
        end;
      end
      else
      begin
        if (AnsiCompareStr(Copy(S, 2, Maxint), Switch) = 0) then
        begin
          Result := True;
          Exit;
        end;
      end;
  end;
  Result := False;
end;

function FindSvrSwitchValue(const Switch: string; const Chars: TSysCharSet; IgnoreCase: Boolean = true): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := 1 to System.ParamCount do
  begin
    S := System.ParamStr(I);
    if (Chars = []) or (AnsiString(S)[1] in Chars) then
      if IgnoreCase then
      begin
        if (AnsiCompareText(Copy(S, 2, Length(Switch)), Switch) = 0) then
        begin
          Result := Copy(S, Length(Switch) + 2, Maxint);
          if Result = '' then
          begin
            Result := System.ParamStr(I + 1);
          end;
          Exit;
        end;
      end
      else
      begin
        if (AnsiCompareStr(Copy(S, 2, Length(Switch)), Switch) = 0) then
        begin
          Result := Copy(S, Length(Switch) + 2, Maxint);
          if Result = '' then
          begin
            Result := System.ParamStr(I + 1);
          end;
          Exit;
        end;
      end;
  end;
end;

function DuplicateHandleToCurrentProcesses(Pid: Cardinal; hdl: Cardinal): THandle; stdcall;
var
  SrcHandle: THandle;
begin
  Result := 0;
  setDebugPrivilege;
  SrcHandle := OpenProcess(PROCESS_DUP_HANDLE, False, Pid);
  if SrcHandle = 0 then
  begin
    Exit;
  end;
  try
    if not DuplicateHandle(SrcHandle, hdl, GetCurrentProcess, @Result, 0, False, DUPLICATE_SAME_ACCESS) then
    begin
      Result := 0;
    end;
  finally
    CloseHandle(SrcHandle);
  end;
end;

function GetFileVersionAsString(FileName:string=''): string;
var
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  VerInfo: ^VS_FIXEDFILEINFO;
begin
  Result := '0.0.0.0';
  if FileName='' then
  begin
    FileName := GetModuleName(HInstance);
  end;
  InfoSize := GetFileVersionInfoSize(PChar(FileName), Wnd);
  if InfoSize <> 0 then
  begin
    GetMem(VerBuf, InfoSize);
    try
      if GetFileVersionInfo(PChar(FileName), Wnd, InfoSize, VerBuf) then
      begin
        VerInfo := nil;
        VerQueryValue(VerBuf, '\', Pointer(VerInfo), Wnd);
        if VerInfo <> nil then
          Result := Format('%d.%d.%d.%d', [VerInfo^.dwFileVersionMS shr 16, VerInfo^.dwFileVersionMS and $0000ffff, VerInfo^.dwFileVersionLS shr 16, VerInfo^.dwFileVersionLS and $0000ffff]);
      end;
    finally
      FreeMem(VerBuf, InfoSize);
    end;
  end;
end;

function GetFileProductVersionAsString(FileName:string=''): string;
var
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  VerInfo: ^VS_FIXEDFILEINFO;
begin
  Result := '0.0.0.0';
  if FileName='' then
  begin
    FileName := GetModuleName(HInstance);
  end;
  InfoSize := GetFileVersionInfoSize(PChar(FileName), Wnd);
  if InfoSize <> 0 then
  begin
    GetMem(VerBuf, InfoSize);
    try
      if GetFileVersionInfo(PChar(FileName), Wnd, InfoSize, VerBuf) then
      begin
        VerInfo := nil;
        VerQueryValue(VerBuf, '\', Pointer(VerInfo), Wnd);
        if VerInfo <> nil then
          Result := Format('%d.%d.%d.%d', [VerInfo^.dwProductVersionMS shr 16, VerInfo^.dwProductVersionMS and $0000ffff, VerInfo^.dwProductVersionLS shr 16, VerInfo^.dwProductVersionLS and $0000ffff]);
      end;
    finally
      FreeMem(VerBuf, InfoSize);
    end;
  end;
end;

function GetDosOutput(Command: string): string;
var
  hReadPipe: THandle;
  hWritePipe: THandle;
  SI: TStartUpInfo;
  PI: TProcessInformation;
  SA: TSecurityAttributes;
  BytesRead: DWORD;
  Dest: array[0..32767] of ansichar;
  CmdLine: array[0..512] of char;
  Avail, ExitCode, wrResult: DWORD;
  osVer: TOSVERSIONINFO;
  tmpstr: AnsiString;
  Line: string;
begin
  osVer.dwOSVersionInfoSize := Sizeof(TOSVERSIONINFO);
  GetVersionEX(osVer);
  if osVer.dwPlatformId = VER_PLATFORM_WIN32_NT then
  begin
    SA.nLength := SizeOf(SA);
    SA.lpSecurityDescriptor := nil;
    SA.bInheritHandle := True;
    CreatePipe(hReadPipe, hWritePipe, @SA, 0);
  end
  else
    CreatePipe(hReadPipe, hWritePipe, nil, 1024);
  try
    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(TStartUpInfo);
    SI.wShowWindow := SW_HIDE;
    SI.dwFlags := STARTF_USESHOWWINDOW;
    SI.dwFlags := SI.dwFlags or STARTF_USESTDHANDLES;
    SI.hStdOutput := hWritePipe;
    SI.hStdError := hWritePipe;
    if not Command.StartsWith('cmd') then
      Command := 'cmd /c '+Command;
    StrPCopy(CmdLine, Command);
    if CreateProcess(nil, CmdLine, nil, nil, True, NORMAL_PRIORITY_CLASS, nil, nil, SI, PI) then
    begin
      ExitCode := 0;
      while ExitCode = 0 do
      begin
        wrResult := WaitForSingleObject(PI.hProcess, 1000);
        if PeekNamedPipe(hReadPipe, @Dest[0], 32768, @Avail, nil, nil) then
        begin
          if Avail > 0 then
          begin
            try
              FillChar(Dest, SizeOf(Dest), 0);
              ReadFile(hReadPipe, Dest[0], Avail, BytesRead, nil);
              TmpStr := Copy(Dest, 0, BytesRead - 1);
              Line := Line + string(TmpStr);
            except
            end;
          end;
        end;
        if wrResult <> WAIT_TIMEOUT then ExitCode := 1;
      end;
      GetExitCodeProcess(PI.hProcess, ExitCode);
      CloseHandle(PI.hProcess);
      CloseHandle(PI.hThread);
    end;
  finally
    result := Line;
    CloseHandle(hReadPipe);
    CloseHandle(hWritePipe);
  end;
end;


end.

