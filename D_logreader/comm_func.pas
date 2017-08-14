unit comm_func;

interface

uses
  p_structDefine;

function GetldfHandle(pid: Cardinal; logFileList:TlogFile_List): Boolean;


implementation

uses
  Windows, SysUtils, MakCommonfuncs, pluginlog, MakStrUtils;
  
type
  PSYSTEM_HANDLE_INFORMATION = ^SYSTEM_HANDLE_INFORMATION;

  _SYSTEM_HANDLE_INFORMATION = packed record
    ProcessId: DWORD;
    ObjectTypeNumber: Byte;
    Flags: Byte;
    Handle: Word;
    _Object: Pointer;
    GrantedAccess: ACCESS_MASK;
  end;

  SYSTEM_HANDLE_INFORMATION = _SYSTEM_HANDLE_INFORMATION;

  PSYSTEM_HANDLE_INFORMATION_list = ^SYSTEM_HANDLE_INFORMATION_list;

  SYSTEM_HANDLE_INFORMATION_list = packed record
    Length: DWORD;
    item: array[0..0] of _SYSTEM_HANDLE_INFORMATION;
  end;
type
  SYSTEM_INFORMATION_CLASS = (SystemBasicInformation,              // 0        Y        N
    SystemProcessorInformation,          // 1        Y        N
    SystemPerformanceInformation,        // 2        Y        N
    SystemTimeOfDayInformation,          // 3        Y        N
    SystemNotImplemented1,               // 4        Y        N
    SystemProcessesAndThreadsInformation, // 5       Y        N
    SystemCallCounts,                    // 6        Y        N
    SystemConfigurationInformation,      // 7        Y        N
    SystemProcessorTimes,                // 8        Y        N
    SystemGlobalFlag,                    // 9        Y        Y
    SystemNotImplemented2,               // 10       Y        N
    SystemModuleInformation,             // 11       Y        N
    SystemLockInformation,               // 12       Y        N
    SystemNotImplemented3,               // 13       Y        N
    SystemNotImplemented4,               // 14       Y        N
    SystemNotImplemented5,               // 15       Y        N
    SystemHandleInformation,             // 16       Y        N
    SystemObjectInformation,             // 17       Y        N
    SystemPagefileInformation,           // 18       Y        N
    SystemInstructionEmulationCounts,    // 19       Y        N
    SystemInvalidInfoClass1,             // 20
    SystemCacheInformation,              // 21       Y        Y
    SystemPoolTagInformation,            // 22       Y        N
    SystemProcessorStatistics,           // 23       Y        N
    SystemDpcInformation,                // 24       Y        Y
    SystemNotImplemented6,               // 25       Y        N
    SystemLoadImage,                     // 26       N        Y
    SystemUnloadImage,                   // 27       N        Y
    SystemTimeAdjustment,                // 28       Y        Y
    SystemNotImplemented7,               // 29       Y        N
    SystemNotImplemented8,               // 30       Y        N
    SystemNotImplemented9,               // 31       Y        N
    SystemCrashDumpInformation,          // 32       Y        N
    SystemExceptionInformation,          // 33       Y        N
    SystemCrashDumpStateInformation,     // 34       Y        Y/N
    SystemKernelDebuggerInformation,     // 35       Y        N
    SystemContextSwitchInformation,      // 36       Y        N
    SystemRegistryQuotaInformation,      // 37       Y        Y
    SystemLoadAndCallImage,              // 38       N        Y
    SystemPrioritySeparation,            // 39       N        Y
    SystemNotImplemented10,              // 40       Y        N
    SystemNotImplemented11,              // 41       Y        N
    SystemInvalidInfoClass2,             // 42
    SystemInvalidInfoClass3,             // 43
    SystemTimeZoneInformation,           // 44       Y        N
    SystemLookasideInformation,          // 45       Y        N
    SystemSetTimeSlipEvent,              // 46       N        Y
    SystemCreateSession,                 // 47       N        Y
    SystemDeleteSession,                 // 48       N        Y
    SystemInvalidInfoClass4,             // 49
    SystemRangeStartInformation,         // 50       Y        N
    SystemVerifierInformation,           // 51       Y        Y
    SystemAddVerifier,                   // 52       N        Y
    SystemSessionProcessesInformation    // 53       Y        N
);

const
  STATUS_INFO_LENGTH_MISMATCH = ($C0000004);
 
function ZwQuerySystemInformation(SystemInformationClass: SYSTEM_INFORMATION_CLASS; SystemInformation: Pointer; SystemInformationLength: ULONG; ReturnLength: PULONG): Cardinal; stdcall; external 'ntdll.dll';

  
function GetldfHandle(pid: Cardinal; logFileList:TlogFile_List): Boolean;
var
  sqlHandle: THandle;
  Status: Cardinal;
  pbuffer: Pointer;
  dwSize: DWORD;
  cnt: Integer;
  pshi: PSYSTEM_HANDLE_INFORMATION;
  I, J: Integer;
  TargetHandle: THandle;
  tmpStr: string;
  usefulHandle: Boolean;

  items:PSYSTEM_HANDLE_INFORMATION_list;
  szName:array[0..MAX_PATH] of Char;

  bufSize:Integer;
begin
  Result := False;
  setDebugPrivilege;
  sqlHandle := OpenProcess(PROCESS_DUP_HANDLE, False, pid);
  if sqlHandle = 0 then
  begin
    loger.Add('GetldfHandle fail :Could not open PID %d! (%s)', [pid, SysErrorMessage(GetLastError)]);
    exit;
  end;
  bufSize := $2000;
  dwSize := 0;
  pbuffer := AllocMem(bufSize);
  try
    Status := ZwQuerySystemInformation(SystemHandleInformation, pbuffer, bufSize, @dwSize);
    if not Succeeded(Status) then
    begin
      if Status = STATUS_INFO_LENGTH_MISMATCH then
      begin
        FreeMem(pbuffer);
        bufSize := dwSize + 1024;
        pbuffer := AllocMem(bufSize);
        Status := ZwQuerySystemInformation(SystemHandleInformation, pbuffer, bufSize,nil);
        if not Succeeded(Status) then
        begin
          loger.Add('ZwQuerySystemInformation Call Error 2��' + SysErrorMessage(GetLastError));
          Exit;
        end;
      end
      else
      begin
        loger.Add('ZwQuerySystemInformation Call Error��' + SysErrorMessage(GetLastError));
        Exit;
      end;
    end;
    
    items := PSYSTEM_HANDLE_INFORMATION_list(pbuffer);
    for I := 0 to items.Length - 1 do
    begin
      if (items.item[i].ProcessId = pid) and (items.item[i].ObjectTypeNumber = 28) then
      begin
        if DuplicateHandle(sqlHandle, items.item[i].Handle, GetCurrentProcess(), @TargetHandle, 0, False, DUPLICATE_SAME_ACCESS) then
        begin
          usefulHandle := False;
          GetFinalPathNameByHandle(TargetHandle, @szName, MAX_PATH, 0);
          tmpStr := StrPas(szName);
          if StrEndsWith(tmpStr,'.ldf') then
          begin
            for j := 0 to Length(logFileList) - 1 do
            begin
              if StrEndsWith(tmpStr, logFileList[j].fileFullPath) then
              begin
                logFileList[j].filehandle := TargetHandle;
                logFileList[j].Srchandle := items.item[i].Handle;
                usefulHandle := true;
                break;
              end;
            end;  
          end;
          if not usefulHandle then
            CloseHandle(TargetHandle);
        end;
      end;
    end;
    Result := True;
  finally
    CloseHandle(sqlHandle); 
    FreeMem(pbuffer);
  end;
end;


end.
