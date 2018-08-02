unit DbgHelp;

interface

uses
  Winapi.Windows;

type
  SYM_TYPE = (
    SymNone,
    SymCoff,
    SymCv,
    SymPdb,
    SymExport,
    SymDeferred,
    SymSym                  { .sym file }
  );
  {$EXTERNALSYM SYM_TYPE}
  TSymType = SYM_TYPE;

  PSymbolInfo = ^TSymbolInfo;
  TSymbolInfo = record
    SizeOfStruct: Cardinal;
    TypeIndex: Cardinal;
    Reserved: array[0..1] of UInt64;
    Info: Cardinal;
    Size: Cardinal;
    ModBase: UInt64;
    Flags: Cardinal;
    Value: UInt64;
    Address: UInt64;
    Register_: Cardinal;
    Scope: Cardinal;
    Tag: Cardinal;
    NameLen: Cardinal;
    MaxNameLen: Cardinal;
    Name: array[0..0] of CHAR;
  end;

  PImageHlpModule64 = ^TImageHlpModule64;
  TImageHlpModule64 = record
    SizeOfStruct: DWORD;
    BaseOfImage: UInt64;
    ImageSize: DWORD;
    TimeDateStamp: DWORD;
    CheckSum: DWORD;
    NumSyms: DWORD;
    SymType: SYM_TYPE;
    ModuleName: array[0..31] of CHAR;
    ImageName: array[0..255] of CHAR;
    LoadedImageName: array[0..255] of CHAR;
    // new elements: 07-Jun-2002
    LoadedPdbName: array[0..255] of CHAR;
    CVSig: DWORD;
    CVData: array[0..MAX_PATH * 3 - 1] of CHAR;
    PdbSig: DWORD;
    PdbSig70: TGUID;
    PdbAge: DWORD;
    PdbUnmatched: BOOL;
    DbgUnmatched: BOOL;
    LineNumbers: BOOL;
    GlobalSymbols: BOOL;
    TypeInfo: BOOL;
    // new elements: 17-Dec-2003
    SourceIndexed: BOOL;
    Publics: BOOL;
  end;

  PImageHlpLine64 = ^TImageHlpLine64;
  TImageHlpLine64 = record
    SizeOfStruct: DWORD;
    Key: PVOID;
    LineNumber: DWORD;
    FileName: PCHAR;
    Address: UInt64;
  end;

  PModLoadData = ^TModLoadData;
  TModLoadData = record
    SSize: DWORD;
    SSig: DWORD;
    Data: Pointer;
    Size: DWORD;
    Flags: DWORD;
  end;

  PSourceFile = ^TSourceFile;
  TSourceFile = record
    Base: UInt64;
    FileName: PAnsiChar;
  end;

  TSymTagEnum = (
   SymTagNull,
   SymTagExe,
   SymTagCompiland,
   SymTagCompilandDetails,
   SymTagCompilandEnv,
   SymTagFunction,
   SymTagBlock,
   SymTagData,
   SymTagAnnotation,
   SymTagLabel,
   SymTagPublicSymbol,
   SymTagUDT,
   SymTagEnum,
   SymTagFunctionType,
   SymTagPointerType,
   SymTagArrayType,
   SymTagBaseType,
   SymTagTypedef,
   SymTagBaseClass,
   SymTagFriend,
   SymTagFunctionArgType,
   SymTagFuncDebugStart,
   SymTagFuncDebugEnd,
   SymTagUsingNamespace,
   SymTagVTableShape,
   SymTagVTable,
   SymTagCustom,
   SymTagThunk,
   SymTagCustomType,
   SymTagManagedType,
   SymTagDimension);

  PSymInfo = ^TSymInfo;
  TSymInfo = record
    SizeOfStruct: ULONG;
    TypeIndex: ULONG;
    Reserved: array[0..1] of ULONG64;
    Index: ULONG;
    Size: ULONG;
    ModBase: UInt64;
    Flags: ULONG;
    Value: UInt64;
    Address: UInt64;
    Reg: ULONG;
    Scope: ULONG;
    Tag: TSymTagEnum;
    NameLen: ULONG;
    MaxNameLen: ULONG;
    Name: Char;
  end;

  PSrcCodeInfo = ^TSrcCodeInfo;
  TSrcCodeInfo = record
    SizeOfStruct: DWORD;
    Key: Pointer;
    ModBase: UInt64;
    Obj: array[0..MAX_PATH] of Char;
    FileName: array[0..MAX_PATH] of Char;
    LineNumber: DWORD;
    Address: UInt64;
  end;

  TImageHlpCbaEvent = record
    severity: DWORD;
    code: DWORD;
    desc: PCHAR;
    object_: Pointer;
  end;

  TImageHlpDeferredSymbolLoad = record
    SizeOfStruct: DWORD;
    BaseOfImage: DWORD;
    CheckSum: DWORD;
    TimeDateStamp: DWORD;
    FileName: array [0..MAX_PATH - 1] of CHAR;
    Reparse: ByteBool;
    hFile: THANDLE;
  end;

  TSymInitializeFunc = function(hProcess: THandle; UserSearchPath: PChar; fInvadeProcess: LongBool): LongBool; stdcall;
  TSymGetOptionsFunc = function: DWORD; stdcall;
  TSymSetOptionsFunc = function(SymOptions: DWORD): DWORD; stdcall;
  TSymCleanupFunc = function(hProcess: THandle): LongBool; stdcall;
  TSymFromAddrFunc = function(hProcess: THandle; Address: UInt64; Displacement: Pointer { PUInt64 - C++ Builder 6 fails }; var Symbol: TSymbolInfo): LongBool; stdcall;
  TSymGetModuleInfo64Func = function(hProcess: THandle; qwAddr: UInt64; var ModuleInfo: TImageHlpModule64): LongBool; stdcall;
  TSymLoadModule64Func = function(hProcess, hFile: THandle; ImageName, ModuleName: PAnsiChar; BaseOfDll: UInt64; SizeOfDll: DWORD): UInt64; stdcall;
  TSymGetLineFromAddr64Func = function(hProcess: THandle; qwAddr: UInt64; var pdwDisplacement: DWORD; var Line64: TImageHlpLine64): LongBool; stdcall;
  TSymbolRegisteredCallback64 = function(hProcess: THandle; ActionCode: Cardinal; CallbackData: UInt64; UserContext: UInt64): LongBool; stdcall;
  TSymRegisterCallback64Func = function(hProcess: THandle; CallbackFunction: Pointer; UserContext: UInt64): LongBool; stdcall;
  TSymLoadModuleExFunc = function(hProcess, hFile: THandle; ImageName, ModuleName: PChar; BaseOfDll: UInt64; SizeOfDll: DWORD; ModData: PModLoadData; Flags: DWORD): UInt64; stdcall;
  TSymUnloadModule64Func = function(hProcess: THandle; BaseOfDll: UInt64): BOOL; stdcall;
  TSymEnumSourceFilesCallbackFunc = function(const ASourceFile: TSourceFile; AUserContext: Pointer): BOOL; stdcall;
  TSymEnumSourceFilesFunc = function(hProcess: THandle; BaseOfDll: UInt64; Mask: PAnsiChar; Callback: TSymEnumSourceFilesCallbackFunc; User: Pointer): BOOL; stdcall;
  TSymEnumSymbolsCallbackFunc = function(const ASymInfo: TSymInfo; SymSize: ULONG; AUserContext: Pointer): BOOL; stdcall;
  TSymEnumSymbolsFunc = function(hProcess: THandle; BaseOfDll: UInt64; Mask: PChar; Callback: TSymEnumSymbolsCallbackFunc; User: Pointer): BOOL; stdcall;
  TSymEnumLinesCallbackFunc = function(const ALineInfo: TSrcCodeInfo; UserContext: Pointer): BOOL; stdcall;
  TSymEnumLinesFunc = function(hProcess: THandle; Base: UInt64; Obj: PChar; AFile: PChar; ACallback: TSymEnumLinesCallbackFunc; UserContext: Pointer): BOOL; stdcall;
  TSymFromName = function(hProcess: THandle;Mask: PChar; Symbol:PSymInfo): BOOL; stdcall;

var
  SymInitialize: TSymInitializeFunc = nil;
  SymGetOptions: TSymGetOptionsFunc = nil;
  SymSetOptions: TSymSetOptionsFunc = nil;
  SymCleanup: TSymCleanupFunc = nil;
  SymFromAddr: TSymFromAddrFunc = nil;
  SymGetModuleInfo64: TSymGetModuleInfo64Func = nil;
  SymLoadModule64: TSymLoadModule64Func = nil;
  SymGetLineFromAddr64: TSymGetLineFromAddr64Func = nil;
  SymRegisterCallback64: TSymRegisterCallback64Func = nil;
  SymLoadModuleEx: TSymLoadModuleExFunc = nil;
  SymUnloadModule64: TSymUnloadModule64Func = nil;
  SymEnumSourceFiles: TSymEnumSourceFilesFunc = nil;
  SymEnumSymbols: TSymEnumSymbolsFunc = nil;
  SymEnumLines: TSymEnumLinesFunc = nil;
  SymFromName: TSymFromName = nil;

const
  SymInitializeName         = 'SymInitialize';         // Do Not Localize
  SymGetOptionsName         = 'SymGetOptions';         // Do Not Localize
  SymSetOptionsName         = 'SymSetOptions';         // Do Not Localize
  SymCleanupName            = 'SymCleanup';            // Do Not Localize
  SymFromAddrName           = 'SymFromAddr';           // Do Not Localize
  SymGetModuleInfo64Name    = 'SymGetModuleInfo64';    // Do Not Localize
  SymLoadModule64Name       = 'SymLoadModule64';       // Do Not Localize
  SymGetLineFromAddr64Name  = 'SymGetLineFromAddr64';  // Do Not Localize
  SymRegisterCallback64Name = 'SymRegisterCallback64'; // Do Not Localize
  SymLoadModuleExName       = 'SymLoadModuleEx';       // Do Not Localize
  SymUnloadModule64Name     = 'SymUnloadModule64';     // Do Not Localize
  SymEnumSourceFilesName    = 'SymEnumSourceFiles';    // Do Not Localize
  SymEnumSymbolsName        = 'SymEnumSymbols';        // Do Not Localize
  SymEnumLinesName          = 'SymEnumLines';          // Do Not Localize
  SymFromNameName           = 'SymFromName';

function LoadDebugFunctions: Boolean;
function UnloadDebugFunctions: Boolean;

implementation

uses
  StrUtils;

function LoadDebugFunctions: Boolean;

  function LoadDebugFuncsFromLibrary(const ALib: HMODULE): Boolean;

    function FindProc(const ALib: HMODULE; const AName: String; const AStrictName: Boolean = False): Pointer;
    begin
      if not AStrictName then
      begin
        {$IFDEF UNICODE}
        Result := GetProcAddress(ALib, PChar(AName + 'W')); // Do Not Localize
        {$ELSE}
        Result := GetProcAddress(ALib, PChar(AName + 'A')); // Do Not Localize
        {$ENDIF}
        if (not Assigned(Result)) and AnsiEndsStr('64', AName) then // Do Not Localize
          {$IFDEF UNICODE}
          Result := GetProcAddress(ALib, PChar(Copy(AName, 1, Length(AName) - 2) + 'W64')); // Do Not Localize
          {$ELSE}
          Result := GetProcAddress(ALib, PChar(Copy(AName, 1, Length(AName) - 2) + 'A64')); // Do Not Localize
          {$ENDIF}
        if Assigned(Result) then
          Exit;
      end;
      Result := GetProcAddress(ALib, PChar(AName));
    end;

  begin
    if ALib <> 0 then
    begin
      SymInitialize          := FindProc(ALIb, SymInitializeName);
      SymGetOptions          := FindProc(ALIb, SymGetOptionsName);
      SymSetOptions          := FindProc(ALIb, SymSetOptionsName);
      SymCleanup             := FindProc(ALIb, SymCleanupName);
      SymFromAddr            := FindProc(ALIb, SymFromAddrName);
      SymGetModuleInfo64     := FindProc(ALIb, SymGetModuleInfo64Name);
      SymLoadModule64        := FindProc(ALIb, SymLoadModule64Name, True); // A only
      SymGetLineFromAddr64   := FindProc(ALIb, SymGetLineFromAddr64Name);
      SymRegisterCallback64  := FindProc(ALIb, SymRegisterCallback64Name);
      SymLoadModuleEx        := FindProc(ALIb, SymLoadModuleExName);
      SymUnloadModule64      := FindProc(ALib, SymUnloadModule64Name);
      SymEnumSourceFiles     := FindProc(ALib, SymEnumSourceFilesName, True); // A only (Unicode is buggy - http://www.codeproject.com/Questions/624671/SymEnumSourceFiles-get-incomplete-file-names)
      SymEnumSymbols         := FindProc(ALib, SymEnumSymbolsName);
      SymEnumLines           := FindProc(ALib, SymEnumLinesName);
      SymFromName            := FindProc(ALib, SymFromNameName);
    end;

    // SymGetLineFromAddrFunc is optional
    Result := (ALib <> 0) and
      Assigned(SymInitialize) and     Assigned(SymGetOptions) and
      Assigned(SymSetOptions) and     Assigned(SymCleanup) and
      Assigned(SymFromAddr) and       Assigned(SymGetModuleInfo64) and
      Assigned(SymLoadModule64) and   Assigned(SymGetLineFromAddr64) and
      Assigned(SymRegisterCallback64);

    if not Result then
      UnloadDebugFunctions;
  end;

var
  hh:THandle;
begin
  hh := LoadLibrary('C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\dbghelp.dll');
  Result := LoadDebugFuncsFromLibrary(hh);
end;

function UnloadDebugFunctions: Boolean;
begin
  Result := True;

  SymInitialize := nil;
  SymGetOptions := nil;
  SymSetOptions := nil;
  SymCleanup := nil;
  SymFromAddr := nil;
  SymGetModuleInfo64 := nil;
  SymLoadModule64 := nil;
  SymGetLineFromAddr64 := nil;
  SymRegisterCallback64 := nil;
  SymLoadModuleEx := nil;
  SymUnloadModule64 := nil;
  SymEnumSourceFiles := nil;
  SymEnumSymbols := nil;
  SymEnumLines := nil;
end;

end.
