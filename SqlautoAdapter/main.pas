unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.VCLUI.Wait, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  FireDAC.Phys.SQLite, Data.Win.ADODB, Vcl.ExtCtrls;

type
  Tfrm_main = class(TForm)
    Button1: TButton;
    Button2: TButton;
    ADOQuery1: TADOQuery;
    Memo1: TMemo;
    Button3: TButton;
    Panel1: TPanel;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure processLog(logStr:string);
  end;

var
  frm_main: Tfrm_main;

implementation

uses
  DbgHelp, loglog, dbcfg, dbhelper, HashHelper;
{$R *.dfm}

function getPDBUrl(aName: string): string;
function Rva2Raw(imageBase: Pointer; RVA: Cardinal): Cardinal;
var
  dosHeader: PImageDosHeader;
  ntHeader: PImageNtHeaders;
  sectionHeader: PImageSectionHeader;
  i: integer;
begin
  Result := 0;
  dosHeader := pImageDosHeader(imageBase);
  ntHeader := pImageNtHeaders(UINTPTR(imageBase) + UINTPTR(dosHeader._lfanew));
  sectionHeader := PImageSectionHeader(LongInt(@ntHeader.OptionalHeader) + ntHeader.FileHeader.SizeOfOptionalHeader);
  for i := 0 to ntHeader.FileHeader.NumberOfSections - 1 do
  begin
    if (RVA > sectionHeader.VirtualAddress) and (RVA < sectionHeader.VirtualAddress + sectionHeader.Misc.VirtualSize) then
    begin
      Result := RVA + sectionHeader.PointerToRawData - sectionHeader.VirtualAddress;
      Break;
    end;
    Inc(sectionHeader);
  end;
end;

function GUIDToString(const Guid: TGUID): string;
begin
  Result := Format('%.8x%.4x%.4x%.2x%.2x%.2x%.2x%.2x%.2x%.2x%.2x',   // do not localize
    [Guid.D1, Guid.D2, Guid.D3, Guid.D4[0], Guid.D4[1], Guid.D4[2], Guid.D4[3],
    Guid.D4[4], Guid.D4[5], Guid.D4[6], Guid.D4[7]]);
end;

type
  PPdbInfo = ^TPdbInfo;

  TPdbInfo = packed record
    Signature: array[0..3] of AnsiChar;
    Guid: TGUID;
    Age: DWORD;
    PdbFileName: AnsiChar;
  end;
var
  hh: THandle;
  fSize, nSize: Cardinal;
  buf: Pointer;
  dosHeader: PImageDosHeader;
  ntHeader: PImageNtHeaders;
  OptionalHeader: PImageOptionalHeader32;
  OptionalHeader64: PImageOptionalHeader64;
  dbgVa: Cardinal;
  dbgSize: Integer;
  idebugDir: PImageDebugDirectory;
  dbgMisc: PImageDebugMisc;
  pdb7Data: PPdbInfo;
  PdbFileName:string;
  I: Integer;
begin
  Result := '';
  hh := CreateFile(PChar(aName), GENERIC_READ, FILE_SHARE_DELETE or FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);

  //CreateFileMapping(hh, nil, PAGE_READONLY, 0, 0, nil);
  fSize := GetFileSize(hh, nil);
  buf := GetMemory(fSize);
  if ReadFile(hh, buf^, fSize, nSize, nil) and (nSize = fSize) then
  begin
    if (PWord(buf)^ = IMAGE_DOS_SIGNATURE) then
    begin
      //pe
      dosHeader := PImageDosHeader(buf);
      ntHeader := PImageNtHeaders(UINT_PTR(buf) + UINTPTR(dosHeader._lfanew));
      if ntHeader.OptionalHeader.Magic = $020B then
      begin
        OptionalHeader64 := @ntHeader.OptionalHeader;
        dbgVa := OptionalHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_DEBUG].VirtualAddress;
        dbgSize := OptionalHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_DEBUG].Size;
      end
      else
      begin
        OptionalHeader := @ntHeader.OptionalHeader;
        dbgVa := OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DEBUG].VirtualAddress;
        dbgSize := OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DEBUG].Size;
      end;
      if dbgSize > 0 then
      begin
        //ImageDirectoryEntryToData
        dbgSize := dbgSize div SizeOf(_IMAGE_DEBUG_DIRECTORY);
        dbgVa := Rva2Raw(buf, dbgVa);
        if (dbgVa > 0) and (dbgSize > 0) then
        begin
          idebugDir := PImageDebugDirectory(UINT_PTR(buf) + dbgVa);

          for I := 0 to dbgSize - 1 do
          begin
            if idebugDir._Type = IMAGE_DEBUG_TYPE_CODEVIEW then
            begin
              pdb7Data := PPdbInfo(UINT_PTR(buf) + idebugDir.PointerToRawData);
              PdbFileName := string(PAnsiChar(@pdb7Data.PdbFileName));
              result := Format('http://msdl.microsoft.com/download/symbols/%s/%s%d/%s',
                    [PdbFileName, guidtostring(pdb7Data.Guid), pdb7Data.Age, PdbFileName]);
              break;
            end
            else if idebugDir._Type = IMAGE_DEBUG_TYPE_MISC then
            begin
              dbgMisc := PImageDebugMisc(UINT_PTR(buf) + idebugDir.PointerToRawData);
            end;
            inc(idebugDir);
          end;
        end;
      end;
    end;
  end;
  FreeMemory(buf);
  CloseHandle(hh);
end;

procedure Tfrm_main.Button1Click(Sender: TObject);
var
  pdbPath:string;
begin
  //'http://msdl.microsoft.com/download/symbols/sqlmin.pdb/EF62962237614EF0B93B51D745D8662A2/sqlmin.pdb'
  pdbPath := getPDBUrl('W:\x86\Setup\sql_engine_core_inst_msi\PFiles\SqlServr\MSSQL.X\MSSQL\Binn\sqlmin.dll');
  memo1.lines.add(pdbPath);
end;


function GetFileSize(const AFileName: String): Int64;
var
  Find: THandle;
  Data: TWin32FindData;
  Sz: _LARGE_INTEGER;
begin
  Result := 0;

  Find := Winapi.Windows.FindFirstFile(PChar(AFileName), Data);
  if Find <> INVALID_HANDLE_VALUE then
  begin
    Sz.LowPart := Data.nFileSizeLow;
    Sz.HighPart := Data.nFileSizeHigh;
    Winapi.Windows.FindClose(Find);
    Result := Int64(Sz.QuadPart);
  end;
end;

function EnumFunctions(const ASymInfo: TSymInfo; SymSize: ULONG; AUserContext: Pointer): BOOL; stdcall;
var
  SymName: String;
  Addr: UInt64;
  Sz: Integer;
  Line: TImageHlpLine64;
  LastAddr: UInt64;
begin
  Addr := ASymInfo.Address - ASymInfo.ModBase;
  SetLength(SymName, ASymInfo.NameLen);
  Move(ASymInfo.Name, Pointer(SymName)^, Length(SymName) * SizeOf(SymName[1]));
  SymName := PChar(SymName);

  if (SymName = '_enc$textbss$begin') or (SymName = '_enc$textbss$end') then
  begin
    Result := True;
    Exit;
  end;

  Sz := ASymInfo.Size;
  if Sz = 0 then
    Sz := SymSize;

  LastAddr := Addr + Sz;

  FillChar(Line, SizeOf(Line), 0);
  Line.SizeOfStruct := SizeOf(Line);
  
  Result := True;
end;

function getPageRef_ModifyColumnsInternalFromSymbols(aPdbName:string):UINT_PTR;
var
  FLoadedImg:UInt64;
  ModuleInfo: PImageHlpModule64;
  ASymInfo: PSymInfo;
begin
  Result := 0;
  FLoadedImg := SymLoadModuleEx(GetCurrentProcess, 0, PChar(aPdbName), nil, $40000000, GetFileSize(aPdbName), nil, 0);
  if FLoadedImg = 0 then
  begin
    Loger.Add('getPageRef_ModifyColumnsInternalFromSymbols:SymLoadModuleEx fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
    Exit;
  end;
  ModuleInfo := AllocMem(SizeOf(TImageHlpModule64));
  try
    ModuleInfo.SizeOfStruct := SizeOf(TImageHlpModule64);
    if not SymGetModuleInfo64(GetCurrentProcess, FLoadedImg, ModuleInfo^) then
    begin
      Loger.Add('getPageRef_ModifyColumnsInternalFromSymbols:SymGetModuleInfo64 fail! ' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
      Exit;
    end;
    New(ASymInfo);
    try
      ASymInfo.SizeOfStruct := SizeOf(TSymInfo);
      ASymInfo.MaxNameLen := MAX_PATH;

      if not SymFromName(GetCurrentProcess, 'PageRef::ModifyColumnsInternal', ASymInfo) then
      begin
        Loger.Add('getPageRef_ModifyColumnsInternalFromSymbols:SymFromName fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
        Exit;
      end;
      Result := ASymInfo.Address - ASymInfo.ModBase;
    finally
      Dispose(ASymInfo);
    end;
//      if not SymEnumSymbols(GetCurrentProcess, FLoadedImg, 'PageRef::ModifyColumnsInternal', EnumFunctions, nil) then
//      begin
//        Loger.Add('getPageRef_ModifyColumnsInternalFromSymbols:' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
//        Exit;
//      end;
  finally
    FreeMem(ModuleInfo);
  end;
  SymUnloadModule64(GetCurrentProcess, FLoadedImg);
end;

procedure Tfrm_main.Button2Click(Sender: TObject);
begin
  getPageRef_ModifyColumnsInternalFromSymbols('H:\Symbols\sqlmin.pdb\D1C97E280B0140E18A5ACD148315ED1A2\sqlmin.pdb')
end;

procedure Tfrm_main.Button3Click(Sender: TObject);
var
  microsoftversion: Integer;
  Major,Minor,BuildNumber:Integer;
  SqlrootPath:string;
  sqlMinPath:String;
  sqlminMD5 :string;
begin
  adoquery1.ConnectionString := dbcfg.getConnectionString(dbcfg_Host, dbcfg_user, dbcfg_pass);
  adoquery1.SQL.Text := 'declare @SmoRoot nvarchar(512)'+
    ' exec master.dbo.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''SOFTWARE\Microsoft\MSSQLServer\Setup'', N''SQLPath'', @SmoRoot OUTPUT; '+
    ' select cast(@@VERSION as varchar(500)),@@microsoftversion ,@SmoRoot';
  adoquery1.Open;
  processLog(adoquery1.Fields[0].AsString);
  microsoftversion := adoquery1.Fields[1].AsInteger;
  Major := (microsoftversion shr 24) and $FF;
  Minor := (microsoftversion shr 16) and $FF;
  BuildNumber := microsoftversion and $FFFF;
  processLog(Format('Major:%d,Minor:%d,BuildNumber:%d', [Major, Minor, BuildNumber]));
  SqlrootPath := adoquery1.Fields[2].AsString;
  processLog('RootPath:' + SqlrootPath);

  sqlMinPath := SqlrootPath +'\Binn\sqlmin.dll';
  processLog('sqlmin:' + sqlMinPath);
  sqlminMD5 := GetFileHashMD5(sqlMinPath);
  processLog('MD5:' + sqlminMD5);
  if DBH.checkMd5(sqlminMD5) then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!Ext cfg exists!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  if Major < 10 then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!暂不支持2008之前的版本!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  processLog('---------------------------准备测试自动方案---------------------------');

end;

procedure Tfrm_main.FormCreate(Sender: TObject);
begin
  LoadDebugFunctions;
  SymInitialize(GetCurrentProcess, nil, False);
end;

procedure Tfrm_main.FormShow(Sender: TObject);
begin
  if dbcfg_Host = '' then
  begin
    frm_dbcfg := Tfrm_dbcfg.create(nil);
    frm_dbcfg.ShowModal;
    if dbcfg_Host = '' then
    begin
      Application.Terminate;
    end;
  end;

  self.Caption := self.Caption + ' - ' + dbcfg_Host;

  DBH := TDBH.Create;
end;


procedure Tfrm_main.processLog(logStr: string);
begin
  memo1.Lines.Add(logStr);
  Loger.Add(logStr);
end;

end.

