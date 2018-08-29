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
  FireDAC.Phys.SQLite, Data.Win.ADODB, Vcl.ExtCtrls, loglog, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, Vcl.ComCtrls,
  p_structDefine;

type
  Tfrm_main = class(TForm)
    ADOQuery1: TADOQuery;
    Memo1: TMemo;
    btn_Analysis: TButton;
    Panel1: TPanel;
    ProgressBar1: TProgressBar;
    btn_test: TButton;
    Timer1: TTimer;
    btn_clear: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btn_AnalysisClick(Sender: TObject);
    procedure btn_testClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btn_clearClick(Sender: TObject);
  private
    autoAdapterTest_DBID:Integer;
    dbv_Major,dbv_Minor,dbv_BuildNumber:Integer;
    dbv_isX64:Boolean;
    RawLogOrder:TList;
    ModifyColumnsInternalAddr:Cardinal;
    sqlminMD5 :string;

    function getPageRef_ModifyColumnsInternalFromSymbols(
      aPdbName: string): UINT_PTR;
    function getPDBUrl(aName: string; var PdbSig70: TGUID; var PdbAge: DWORD): string;
    function downLocalPdb(pdbUrl: string; PdbSig70: TGUID; PdbAge: DWORD): Boolean;
    procedure IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure CreateMsgPipe;
    procedure CraeteTestDbAndTable;
    function checkPipeSuccData(data: pointer): Boolean;
    { Private declarations }
  public
    FPipe:THandle;
    { Public declarations }
    procedure processLog(logStr:string; level: Integer = LOG_INFORMATION);
  end;

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
  frm_main: Tfrm_main;

implementation

uses
  DbgHelp, dbcfg, dbhelper, HashHelper, Memory_Common;
{$R *.dfm}

function Tfrm_main.getPDBUrl(aName: string; var PdbSig70: TGUID; var PdbAge: DWORD): string;
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
  sectionHeader := PImageSectionHeader(UINTPTR(@ntHeader.OptionalHeader) + ntHeader.FileHeader.SizeOfOptionalHeader);
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
  if hh=INVALID_HANDLE_VALUE then
  begin
    processLog('CreateFile fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
    Exit;
  end;
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
              PdbSig70 := pdb7Data.Guid;
              PdbAge := pdb7Data.Age;
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
    end else begin
      processLog('ReadFile check fail! 不是有效的Pe文件', LOG_ERROR or LOG_IMPORTANT);
    end;
  end else begin
    processLog('ReadFile fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
  end;
  FreeMemory(buf);
  CloseHandle(hh);
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

function Tfrm_main.getPageRef_ModifyColumnsInternalFromSymbols(aPdbName:string):UINT_PTR;
var
  FLoadedImg:UInt64;
  ModuleInfo: PImageHlpModule64;
  ASymInfo: PSymInfo;
begin
  Result := 0;
  FLoadedImg := SymLoadModuleEx(GetCurrentProcess, 0, PChar(aPdbName), nil, $40000000, GetFileSize(aPdbName), nil, 0);
  if FLoadedImg = 0 then
  begin
    processLog('getPageRef_ModifyColumnsInternalFromSymbols:SymLoadModuleEx fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
    Exit;
  end;
  ModuleInfo := AllocMem(SizeOf(TImageHlpModule64));
  try
    ModuleInfo.SizeOfStruct := SizeOf(TImageHlpModule64);
    if not SymGetModuleInfo64(GetCurrentProcess, FLoadedImg, ModuleInfo^) then
    begin
      processLog('getPageRef_ModifyColumnsInternalFromSymbols:SymGetModuleInfo64 fail! ' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
      Exit;
    end;
    ASymInfo := AllocMem($1000);
    try
      ASymInfo.SizeOfStruct := SizeOf(TSymInfo);
      ASymInfo.MaxNameLen := MAX_PATH;

      if not SymFromName(GetCurrentProcess, 'PageRef::ModifyColumnsInternal', ASymInfo) then
      begin
        processLog('getPageRef_ModifyColumnsInternalFromSymbols:SymFromName fail!' + SysErrorMessage(GetLastError), LOG_ERROR or LOG_IMPORTANT);
        Exit;
      end;
      Result := ASymInfo.Address - ASymInfo.ModBase;
    finally
      FreeMem(ASymInfo);
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


function MyThreadFun(param:pointer): Integer; stdcall;
begin
  frm_main.CreateMsgPipe;

  frm_main.adoquery1.Close;
  frm_main.adoquery1.SQL.Text := Format('exec t_oo 0,%d', [frm_main.ModifyColumnsInternalAddr]);;
  frm_main.adoquery1.ExecSQL;
  frm_main.adoquery1.Close;

  Result := 0;
end;

procedure Tfrm_main.btn_testClick(Sender: TObject);
var
  dllPath:string;
  ThreadID:Cardinal;
begin
  adoquery1.Close;
  adoquery1.ConnectionString := getConnectionString(dbcfg_Host,dbcfg_user,dbcfg_pass);
  adoquery1.SQL.Text := 'select IS_SRVROLEMEMBER(''sysadmin'')';
  adoquery1.Open;
  if adoquery1.Fields[0].AsString<>'1' then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!用户必须是sysadmin成员!!!!!!!!!!!!!!!!!!!');
    exit;
  end;
  adoquery1.Close;
  adoquery1.SQL.Text := 'select object_id(''t_oo'',''X'')';
  adoquery1.Open;
  if adoquery1.Fields[0].AsString='' then
  begin
    processLog('--------新增t_oo');
    dllPath := ExtractFilePath(GetModuleName(HInstance)) + 'Hooktest.dll';
    adoquery1.Close;
    adoquery1.SQL.Text := Format('exec sp_addextendedproc ''t_oo'',''%s'' ',[dllPath]);
    adoquery1.ExecSQL;
  end;
  CraeteTestDbAndTable;
  BeginThread(nil,0,@MyThreadFun,nil,0,ThreadID);
end;

procedure Tfrm_main.CraeteTestDbAndTable;
begin
  adoquery1.Close;
  adoquery1.SQL.Text := 'if db_id(''autoAdapterTest'') is null Create database autoAdapterTest;';
  adoquery1.ExecSQL;

  adoquery1.Close;
  adoquery1.SQL.Text := 'if OBJECT_ID(''[autoAdapterTest].[dbo].[a1]'',''u'') is null CREATE TABLE [autoAdapterTest].[dbo].[a1]([id] [int] NOT NULL PRIMARY key,[dm] [varchar](50) NULL,[mc] [varchar](50) NULL);';
  adoquery1.ExecSQL;

  adoquery1.Close;
  adoquery1.SQL.Text := 'if not exists(select top 1 1 from [autoAdapterTest].[dbo].[a1])'+
    'insert [autoAdapterTest].[dbo].[a1](id,dm,mc)values(1,''aaaaa'',''bbbbb'');';
  adoquery1.ExecSQL;

  adoquery1.Close;
  adoquery1.SQL.Text := 'select db_id(''autoAdapterTest'')';
  adoquery1.Open;
  autoAdapterTest_DBID := adoquery1.Fields[0].AsInteger;
  adoquery1.Close;
end;

procedure Tfrm_main.btn_clearClick(Sender: TObject);
begin
  //删除测试库
  adoquery1.Close;
  adoquery1.SQL.Text := 'if db_id(''autoAdapterTest'') is not null drop database autoAdapterTest;';
  adoquery1.ExecSQL;
  //删除扩展存储过程
  adoquery1.Close;
  adoquery1.SQL.Text := 'exec sp_dropextendedproc ''t_oo'';';
  adoquery1.ExecSQL;
end;

procedure Tfrm_main.btn_AnalysisClick(Sender: TObject);
var
  microsoftversion: Integer;
  SqlrootPath:string;
  sqlMinPath:String;
  pdbPath: string;
  PdbSig70: TGUID;
  PdbAge: DWORD;
  pnt: Integer;
  dll: string;
begin
  adoquery1.Close;
  adoquery1.ConnectionString := getConnectionString(dbcfg_Host,dbcfg_user,dbcfg_pass);
  adoquery1.SQL.Text := 'declare @SmoRoot nvarchar(512)'+
    ' exec master.dbo.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''SOFTWARE\Microsoft\MSSQLServer\Setup'', N''SQLPath'', @SmoRoot OUTPUT; '+
    ' select cast(@@VERSION as varchar(500)),@@microsoftversion ,@SmoRoot,charindex(''64'',cast(SERVERPROPERTY(''Edition'')as varchar(100)))';
  adoquery1.Open;
  processLog(adoquery1.Fields[0].AsString);
  microsoftversion := adoquery1.Fields[1].AsInteger;
  dbv_Major := (microsoftversion shr 24) and $FF;
  dbv_Minor := (microsoftversion shr 16) and $FF;
  dbv_BuildNumber := microsoftversion and $FFFF;
  processLog(Format('Major:%d,Minor:%d,BuildNumber:%d', [dbv_Major, dbv_Minor, dbv_BuildNumber]));
  dbv_isX64 := adoquery1.Fields[3].AsInteger > 0;
  SqlrootPath := adoquery1.Fields[2].AsString;
  processLog('RootPath:' + SqlrootPath);

  sqlMinPath := SqlrootPath +'\Binn\sqlmin.dll';
  processLog('sqlmin:' + sqlMinPath);
  sqlminMD5 := GetFileHashMD5(sqlMinPath);
  processLog('MD5:' + sqlminMD5);
  if DBH.cfg(sqlminMD5, pnt, dll) then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!Ext cfg exists!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  if not dbv_isX64 then
  begin
    //仅支持x64
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!仅支持64位的数据库!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  if dbv_Major < 10 then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!暂不支持2008之前的版本!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  processLog('---------------------------准备测试自动方案---------------------------');
  pdbPath := getPDBUrl(sqlMinPath, PdbSig70, PdbAge);
  if pdbPath='' then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!获取Pdb信息失败!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  processLog('pdbUrl:' + pdbPath);
  downLocalPdb(pdbPath, PdbSig70, PdbAge);
  pdbPath := ExtractFilePath(Application.ExeName) + '/sqlmin.pdb';
  ModifyColumnsInternalAddr := getPageRef_ModifyColumnsInternalFromSymbols(pdbPath);
  if ModifyColumnsInternalAddr = 0 then
  begin
    processLog('!!!!!!!!!!!!!!!!!!!!!!!!!!!!解析PDB失败!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  processLog(Format('MCIA:%08X', [ModifyColumnsInternalAddr]));
  processLog('---------------------------测试MCIA有效性---------------------------');

  //Button1Click(nil);
  btn_test.Enabled := True;
  btn_clear.Enabled := True;
end;


procedure Tfrm_main.CreateMsgPipe;
var
  ssd:TSecurityDescriptor;
  ssA:TSecurityAttributes;
begin
  ssA.nLength:=Sizeof(TSecurityAttributes);
  ssA.lpSecurityDescriptor := @ssd;
  InitializeSecurityDescriptor(ssA.lpSecurityDescriptor,   SECURITY_DESCRIPTOR_REVISION);
  // ACL is set as NULL in order to allow all access to the object.
  SetSecurityDescriptorDacl(ssA.lpSecurityDescriptor, TRUE, nil, FALSE);
  ssA.bInheritHandle:=True;
  if FPipe>0 then
    CloseHandle(FPipe);
  FPipe := CreateNamedPipe(pipeName, PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_NOWAIT,
    PIPE_UNLIMITED_INSTANCES, $2000, $2000, 1000, @ssA);
end;

function Tfrm_main.downLocalPdb(pdbUrl:string; PdbSig70: TGUID; PdbAge: DWORD):Boolean;
var
  aPath:string;
  FLoadedImg:UInt64;
  ModuleInfo: PImageHlpModule64;
  NeedRedown:Boolean;
  idh:Tidhttp;
  vSSL: TIdSSLIOHandlerSocketOpenSSL;
  mmo:TMemoryStream;
begin
  Result := False;
  NeedRedown := True;
  aPath := ExtractFilePath(Application.ExeName) +'/sqlmin.pdb';
  if FileExists(aPath) then
  begin
    //如果目录下有pdb先效验下版本
    FLoadedImg := SymLoadModuleEx(GetCurrentProcess, 0, PChar(aPath), nil, $40000000, GetFileSize(aPath), nil, 0);
    if FLoadedImg > 0 then
    begin
      ModuleInfo := AllocMem(SizeOf(TImageHlpModule64));
      try
        ModuleInfo.SizeOfStruct := SizeOf(TImageHlpModule64);
        if SymGetModuleInfo64(GetCurrentProcess, FLoadedImg, ModuleInfo^) then
        begin
          if (PdbSig70 = ModuleInfo.PdbSig70) and (PdbAge= ModuleInfo.PdbAge) then
          begin
            NeedRedown := False;
            processLog('本地Pdb已存在.......');
            //SymUnloadModule64(GetCurrentProcess, FLoadedImg);
            //Exit;
          end else begin
            processLog('!!!!!!!!!!!!!!!本地PDB无效.Sig失败!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
          end;
        end;
      finally
        FreeMemory(ModuleInfo);
      end;
    end else begin
      processLog('!!!!!!!!!!!!!!!本地PDB无效!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      DeleteFile(aPath);
    end;
    SymUnloadModule64(GetCurrentProcess, FLoadedImg);
  end;
  if FileExists(aPath) and NeedRedown then
  begin
    processLog('!!!!!!!!!!!!!!!'+aPath+' 被占用!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    Exit;
  end;
  if NeedRedown then
  begin
    idh := Tidhttp.Create(nil);
    vSSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
    try
      idh.OnWork := IdHTTP1Work;
      idh.IOHandler := vSSL;
      vSSL.SSLOptions.Method := sslvTLSv1;
      while True do
      begin
        try
          idh.Head(pdbUrl);
          processLog(Format('PDB文件大小：%db(%fMB)', [idh.Response.ContentLength,idh.Response.ContentLength /(1024*1024)]));
          ProgressBar1.Max := Integer(idh.Response.ContentLength);
          ProgressBar1.Position := 0;
          ProgressBar1.Show;
        except
          on EE:Exception do
          begin
            if ee.Message.StartsWith('HTTP/1.1 302') then
            begin
              pdbUrl := idh.Response.Location;
              processLog('Url重定向：'+pdbUrl);
              Continue;
            end else begin
              processLog('!!!!!!!!!!!!!!!'+ee.Message+'!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            end;
          end;
        end;
        Break;
      end;
      mmo := TMemoryStream.Create;
      try
        idh.Get(pdbUrl, mmo);
        mmo.SaveToFile(aPath);
        ProgressBar1.Hide;
        processLog('PDB下载完成：'+aPath);
      finally
        mmo.Free;
      end;
    finally
      idh.Free;
      vSSL.Free;
    end;
  end;
end;

procedure Tfrm_main.FormCreate(Sender: TObject);
begin
  LoadDebugFunctions;
  SymInitialize(GetCurrentProcess, nil, False);

  RawLogOrder:=TList.Create;
end;

procedure Tfrm_main.FormDestroy(Sender: TObject);
begin
  CloseHandle(FPipe);

  RawLogOrder.Free;
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
    frm_dbcfg.Free;
  end;

  self.Caption := self.Caption + ' - ' + dbcfg_Host;

  Memo1.Lines.Add(IntToStr(Self.Handle));
end;

procedure Tfrm_main.processLog(logStr: string;level: Integer = LOG_INFORMATION);
begin
  memo1.Lines.Add(logStr);
  Loger.Add(logStr, level);
end;

function ffffdoUpdate(param:pointer): Integer; stdcall;
var
  adoq:Tadoquery;
begin
  adoq := Tadoquery.Create(nil);
  try
    adoq.LockType := ltReadOnly;
    adoq.ConnectionString := getConnectionString(dbcfg_Host,dbcfg_user,dbcfg_pass);
    adoq.SQL.Text := 'update [autoAdapterTest].[dbo].[a1] set dm='''+formatdatetime('HH:nn:ss.zzz', Now)+''' where id=1';
    adoq.ExecSQL;
  finally
    adoq.Free;
  end;

  Sleep(5000);//等5秒，看看有没有捕获到数据
  if frm_main.RawLogOrder.count = 0 then
  begin
    frm_main.processLog('!!!!!!!!!!!!!!!!!!捕获日志内容失败!!!!!!!!!!!!!!');
  end;
  Result := 0;
end;

function ffffdoUnhook(param:pointer): Integer; stdcall;
var
  I: Integer;
  dataMemo:Pointer;
begin
  Sleep(5000);
  frm_main.adoquery1.Close;
  frm_main.adoquery1.SQL.Text := 'exec t_oo 2,2';;
  frm_main.adoquery1.ExecSQL;
  frm_main.adoquery1.Close;
  frm_main.processLog(Format('==============RawLogCnt:%d=================', [frm_main.RawLogOrder.Count]));
  for I := 0 to frm_main.RawLogOrder.Count-1 do
  begin
    dataMemo := frm_main.RawLogOrder[i];
    try
      try
        if frm_main.checkPipeSuccData(dataMemo) then
        begin
          Break;
        end;
      except
        on ee:Exception do
        begin
          frm_main.processLog(ee.Message);
        end;
      end;
    finally
      FreeMem(dataMemo);
    end;
  end;
  Result := 0;
end;

procedure Tfrm_main.Timer1Timer(Sender: TObject);
var
  Data: TBytes;
  nRead, nWrite: DWORD;
  Buffer: Pointer;
  Msg: string;
  Rval:byte;
  ThreadID:Cardinal;
  ssMmo:Pointer;
begin
  Buffer := GetMemory($2000);
  if ReadFile(FPipe, Buffer^, $2000, nRead, nil) then
  begin
    Rval := 1;
    WriteFile(FPipe, Rval, 1, nWrite, nil);
    if Pbyte(Buffer)^=$BB then
    begin
      //捕获成功的
      ssMmo := GetMemory(nRead);
      CopyMemory(ssMmo, Buffer, nRead);
      RawLogOrder.Add(ssMmo);
      if RawLogOrder.count=1 then
        BeginThread(nil,0,@ffffdoUnhook,nil,0,ThreadID);   //收到第一个捕获的消息开始。5秒后unhook
    end else if Pbyte(Buffer)^=$BC then
    begin
      //hook成功
      processLog('$BC');
      BeginThread(nil,0,@ffffdoUpdate,nil,0,ThreadID);
    end else begin
      SetLength(Data, nRead);
      Move(Buffer^, Data[0], nRead);
      Msg := TEncoding.UTF8.GetString(Data);
      Memo1.Lines.Add(Msg);
      SetLength(Data, 0);
    end;
  end;
  FreeMem(Buffer);
end;

function Tfrm_main.checkPipeSuccData(data:pointer):Boolean;
var
  pbb:PPipeBBData;
  adoq:Tadoquery;
  lsnL:string;
  aSql:string;
  pageId:string;
  fid,Pid,sid:Cardinal;
  ResData:string;
  dbccPagedata:Tbytes;
begin
  Result := False;
  pbb := data;
  lsnL := format('%.8X:%.8X:%.4X', [pbb.lsn.LSN_1, pbb.lsn.LSN_2, pbb.lsn.LSN_3]);
  processLog(Format('========解析已捕获数据：dbid:%d,Plsn:%s',[pbb.dbid, lsnL]));
  if autoAdapterTest_DBID = pbb.dbid then
  begin
    adoq := Tadoquery.Create(nil);
    try
      try
        adoq.LockType := ltReadOnly;
        adoq.ConnectionString := getConnectionString(dbcfg_Host,dbcfg_user,dbcfg_pass);
        adoq.SQL.Text := Format('use [autoAdapterTest];select [Page ID],[Slot ID] from sys.fn_dblog(''0x%s'',null) where [Previous LSN]=''%s'' ',[lsnL,lsnL]);
        adoq.Open;
        if adoq.RecordCount=0 then
        begin
          processLog('!!!!!!!!!!获取日志无效!!!!!!!!!');
          Exit;
        end;
        pageId :=adoq.Fields[0].AsString;
        if pageId='' then
        begin
          processLog('!!!!!!!!!!日志无效pageId效验失败!!!!!!!!!');
          Exit;
        end;
        fid := StrToInt('$' + Copy(pageId, 1, 4));
        pid := StrToInt('$' + Copy(pageId, 6, 12));
        sid := adoq.Fields[1].AsInteger;

        aSql := 'create table #a(p varchar(100),o varchar(100),f varchar(100),v varchar(100)) ';
        aSql := aSql + Format(' insert into #a exec(''dbcc page(%s,%d,%d,1)with tableresults'') ',['autoAdapterTest',FID,PID]);
        if dbv_isX64 then
        begin
          aSql := aSql + Format(' select substring(v,21,44) from #a where p like ''Slot %d,%%'' ',[sid]);
        end else begin
          aSql := aSql + Format(' select substring(v,13,44) from #a where p like ''Slot %d,%%'' ',[sid]);
        end;
        aSql := aSql + ' drop table #a';
        adoq.Close;
        adoq.SQL.Text := aSql;
        adoq.Open;

        ResData := '';
        adoq.first;
        while not adoq.Eof do
        begin
          ResData := ResData + adoq.Fields[0].AsString;
          adoq.Next;
        end;

        dbccPagedata := strToBytes(ResData);
        if CompareMem(@pbb.rawdata, @dbccPagedata[0], Length(dbccPagedata)) then
        begin
          processLog(#$D#$A+'========================Raw效验通过=========================='+
                     #$D#$A+'============================================================'+
                     #$D#$A+'============================MCIA============================='+
                     #$D#$A+'===========================  '+Format('%.8X',[ModifyColumnsInternalAddr])+'  =========================='+
                     #$D#$A+'============================================================'
          );
          Result := True;
          DBH.cfgAdd(sqlminMD5, ModifyColumnsInternalAddr, dbv_Major);
        end else begin
          processLog('!!!!!!!!!!Raw效验失败!!!!!!');
        end;
      except
        on eee:Exception do
        begin
          processLog('!!!!!!!!!!'+eee.Message+'!!!!!!');
        end;
      end;
    finally
      adoq.Free;
    end;
  end else begin
    processLog('skipped')
  end;
end;


procedure Tfrm_main.IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
  ProgressBar1.Position := Integer(AWorkCount);
  Application.ProcessMessages;
end;



end.

