unit Sql2014LogReader;

interface

uses
  I_LogProvider, p_structDefine, Types, databaseConnection,
  LogSource, Classes, LogtransPkg, Contnrs, LogtransPkgMgr, Sql2014logAnalyzer,
  System.SyncObjs;

type
  TSqlProcessTerminatedCallback = procedure of object;

  TSqlProcessMonitor = class(TThread)
   private
     _SqlPid:Cardinal;
     _cback:TSqlProcessTerminatedCallback;
  public
    constructor Create(Pid:Cardinal;cback:TSqlProcessTerminatedCallback);
    procedure Execute; override;
  end;

  TSqlConntest = class(TThread)
  private
    FLogSource: TLogSource;
  public
    constructor Create(LogSource: TLogSource);
    destructor Destroy; override;
    procedure Execute; override;
  end;

  TSql2014LogReader = class(TObject)
  private
    FLogSource: TLogSource;
    FFFdataProvider: array[0..256] of TLogProvider;   //���ֻ����256��������־�ļ�
    FAddLogFilecs:TCriticalSection;
    procedure ClearReader;
  public
    constructor Create(LogSource: TLogSource);
    destructor Destroy; override;
    function GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;
    procedure RepairLogBlockOverlay(logblockData:Pointer);
    function getDataProvider(FileId:Integer):TLogProvider;
  end;

  TSql2014LogPicker = class(TLogPicker)
  private
    FLogReader: TSql2014LogReader;
    FLogSource: TLogSource;
    pkgMgr: TTransPkgMgr;
    FAnalyzer:TSql2014logAnalyzer;
    Fspm:TSqlProcessMonitor;
    FPicking: Boolean;
    FAutoRun: boolean;
    procedure getRawLogTrans(LSN: Tlog_LSN; tranCommitData: TMemory_data);
  public
    constructor Create(AutoRun:Boolean; LogSource: TLogSource);
    destructor Destroy; override;
    procedure Execute; override;
    procedure TerminatedSet;override;
    procedure TerminateDelegate;
    function GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean; override;
    procedure Start;override;
    function state:LS_STATUE;override;
  end;

implementation

uses
  Windows, SysUtils, Memory_Common, loglog, LocalDbLogProvider, OpCode,
  plugins, hexValUtils, ADOdb, db, sqlextendedprocHelper;


function logBlockRawCheck(Lb: TlogBlock): boolean;
begin
  if ((Lb.flag = $90) or
      (Lb.flag = $98) or
      (Lb.flag = $50) or
      (Lb.flag = $58)) and
     (Lb.Size > 0)
  then
  begin
    result := true;
  end else begin
    result := false;
  end;
end;

{ TSqlProcessMonitor }

constructor TSqlProcessMonitor.Create(Pid: Cardinal;cback:TSqlProcessTerminatedCallback);
begin
  _SqlPid := Pid;
  _cback := cback;
  inherited Create(False);
  Self.NameThreadForDebugging('TSqlProcessMonitor:' + IntToStr(_SqlPid), Self.ThreadID);
end;

procedure TSqlProcessMonitor.Execute;
var
  ProcessHandle:THandle;
  ProcessIsExit:Boolean;
begin
  ProcessIsExit := False;
  ProcessHandle := OpenProcess(PROCESS_ALL_ACCESS, False, _SqlPid);
  while not Terminated do
  begin
    if WaitForSingleObject(ProcessHandle, 100) <> WAIT_TIMEOUT then
    begin
      Self.Terminate;
      ProcessIsExit := True;
      Break;
    end;
  end;
  CloseHandle(ProcessHandle);
  if ProcessIsExit and Assigned(_cback) then
  begin
    _cback;
  end;
end;

{ TSql2014LogReader }

constructor TSql2014LogReader.Create(LogSource: TLogSource);
begin
  FLogSource := LogSource;
  FAddLogFilecs := TCriticalSection.Create;
end;

destructor TSql2014LogReader.Destroy;
begin
  ClearReader;
  FAddLogFilecs.Free;
  inherited;
end;

function TSql2014LogReader.getDataProvider(FileId: Integer): TLogProvider;
var
  I:Integer;
  logp: TLogProvider;
begin
  Result := FFFdataProvider[FileId];
  if Result = nil then
  begin
    FAddLogFilecs.Enter;
    try
      if FFFdataProvider[FileId] = nil then
      begin
        FLogSource.Fdbc.getDb_allLogFiles;
        for I := 0 to Length(FLogSource.Fdbc.FlogFileList)-1 do
        begin
          if FLogSource.Fdbc.FlogFileList[i].fileId=FileId then
          begin
            logp := TLocalDbLogProvider.Create;
            if logp.init(FLogSource.Fdbc.FlogFileList[I].filehandle) then
            begin
              FFFdataProvider[FLogSource.Fdbc.FlogFileList[I].fileId] := logp;
              Result := logp;
            end else begin
              logp.Free;
              FLogSource.Loger.Add('�޷���ȡ��ȷ��Provider��%d',[FileId], LOG_ERROR);
            end;
          end;
        end;
      end;
    finally
      FAddLogFilecs.Leave;
    end;
  end;
end;

function TSql2014LogReader.GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;
var
  logBlockHeader: PlogBlock;
  logBlockBuffer:Pointer;
  LogBlockPosi: UIntPtr;
  RowOffset: Word;
  vlfs: PVLF_Info;
  DataProvider:TLogProvider;
begin
  Result := False;
  OutBuffer.data := nil;
  OutBuffer.dataSize := 0;
  if (LSN.LSN_1 = 0) or (LSN.LSN_2 = 0) or (LSN.LSN_3 = 0) then
  begin
    FLogSource.Loger.Add('invalid lsn [0]!%s', [LSN2Str(LSN)], LOG_ERROR);
    Exit;
  end;
  vlfs := FLogSource.GetVlf_SeqNo(lsn.LSN_1);
  try
    if (vlfs = nil) then
    begin
      FLogSource.Loger.Add('invalid lsn [1]!%s', [LSN2Str(LSN)], LOG_ERROR);
      Exit;
    end;
    LogBlockPosi := vlfs.VLFOffset + lsn.LSN_2 * $200;
    DataProvider := getDataProvider(vlfs.fileId);
    if DataProvider = nil then
    begin
      FLogSource.Loger.Add('���ڻ�ȡDataProviderʧ�ܣ�GetRawLogByLSNȡ����',[LOG_ERROR]);
      Exit;
    end;
  finally
    Dispose(vlfs);
  end;

  new(logBlockHeader);
  try
    if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) = 0) then
    begin
      FLogSource.Loger.Add('read logBlock data Error...%s', [LSN2Str(LSN)], LOG_ERROR);
      Exit;
    end;
    if (logBlockHeader.BeginLSN.LSN_1 <> LSN.LSN_1) and
       (logBlockHeader.BeginLSN.LSN_2 <> LSN.LSN_2) and
       (not logBlockRawCheck(logBlockHeader^)) then
    begin
      FLogSource.Loger.Add('logBlock data invalid...%s', [LSN2Str(LSN)], LOG_ERROR);
      Exit;
    end;

    if LSN.LSN_3 > logBlockHeader.OperationCount then
    begin
      //��ǰ����û�����id
      FLogSource.Loger.Add('invalid lsn [4] RowId no found !%s', [LSN2Str(LSN)], LOG_ERROR);
      Exit;
    end;

    logBlockBuffer := GetMemory(logBlockHeader.Size);
    try
      if (DataProvider.Read(logBlockBuffer^, LogBlockPosi, logBlockHeader.Size) <> logBlockHeader.Size) then
      begin
        FLogSource.Loger.Add('read logBlock data Error...%s', [LSN2Str(LSN)], LOG_ERROR);
        Exit;
      end;
      RepairLogBlockOverlay(logBlockBuffer);

      RowOffset := PWORD(Uintptr(logBlockBuffer) + logBlockHeader.endOfBlock - (LSN.LSN_3 - logBlockHeader.BeginLSN.LSN_3 + 1) * 2)^;
      if LSN.LSN_3 = logBlockHeader.BeginLSN.LSN_3 + logBlockHeader.OperationCount - 1 then
      begin
        //last one
        OutBuffer.dataSize := logBlockHeader.endOfBlock - logBlockHeader.OperationCount * 2 - RowOffset;
      end else begin
        OutBuffer.dataSize := PWORD(Uintptr(logBlockBuffer) + logBlockHeader.endOfBlock - (LSN.LSN_3 - logBlockHeader.BeginLSN.LSN_3 + 2) * 2)^ - RowOffset;
      end;

      if OutBuffer.dataSize > 0 then
      begin
        OutBuffer.data := GetMemory(OutBuffer.dataSize);
        Move(Pointer(Uintptr(logBlockBuffer) + RowOffset)^, OutBuffer.data^, OutBuffer.dataSize);
        Result := True;
      end else begin
        FLogSource.Loger.Add('read logBlock length Error...%s', [LSN2Str(LSN)], LOG_ERROR);
      end;
    finally
      FreeMemory(logBlockBuffer);
    end;
  finally
    Dispose(logBlockHeader);
  end;
end;

procedure TSql2014LogReader.RepairLogBlockOverlay(logblockData: Pointer);
var
  logBlock:PlogBlock;
  bBlockPosi:UIntPtr;
  eBlockPosi:UIntPtr;
begin
  logBlock := PlogBlock(logblockData);
  bBlockPosi := 0;
  eBlockPosi := UIntPtr(logblockData) + logBlock.Size - 1;
  while bBlockPosi < logBlock.Size do
  begin
    PByte(UIntPtr(logblockData) + bBlockPosi)^ := Pbyte(eBlockPosi)^;
    bBlockPosi := bBlockPosi + $200;
    eBlockPosi := eBlockPosi - 1;
  end;
end;

{ TSql2014LogPicker }

procedure TSql2014LogReader.ClearReader;
var
  I: Integer;
begin
  FAddLogFilecs.Enter;
  try
    for I := 0 to length(FFFdataProvider)-1 do
    begin
      if FFFdataProvider[i]<>nil then
      begin
        FreeAndNil(FFFdataProvider[i]);
      end;
    end;
  finally
    FAddLogFilecs.Leave;
  end;
end;

constructor TSql2014LogPicker.Create(AutoRun:Boolean; LogSource: TLogSource);
begin
  FPicking := AutoRun;
  FLogSource := LogSource;
  inherited Create(False);
  FLogReader := TSql2014LogReader.Create(LogSource);

  pkgMgr := TTransPkgMgr.Create(FLogSource);

  FAnalyzer := TSql2014logAnalyzer.Create(pkgMgr, LogSource);
  Self.NameThreadForDebugging('TSql2014LogPicker', Self.ThreadID);
  FLogSource.Loger.Add('LogPicker init...');
  Fspm := nil;
end;

destructor TSql2014LogPicker.Destroy;
begin
  if Fspm<>nil then
  begin
    if not Fspm.Terminated then
    begin
      Fspm.Terminate;
      Fspm.WaitFor;
    end;
    Fspm.Free;
  end;

  FAnalyzer.Terminate;
  FAnalyzer.WaitFor;
  FAnalyzer.Free;

  pkgMgr.Free;
  FLogReader.Free;
  FLogSource.Loger.Add('LogPicker.Destroy.....');
  inherited;
end;

procedure TSql2014LogPicker.TerminateDelegate;
begin
  FLogSource.Loger.Add('�������ݿ������ֹͣLogPicker�ж�...', LOG_IMPORTANT or LOG_WARNING);
  FAutoRun := true;
  TerminatedSet;
  Fspm.FreeOnTerminate := True;
  Fspm := nil;
end;

procedure TSql2014LogPicker.TerminatedSet;
begin
  FPicking := False;
end;

procedure TSql2014LogPicker.Execute;
label
  beginPoint;
var
  Tmpvlf: PVLF_Info;
  vlf: TVLF_Info;
  vlfHeader: TVLFHeader;
  LogBlockBuf:Pointer;
  DataProvider:TLogProvider;
  logBlockHeader: PlogBlock;
  LogBlockPosi: Int64;
  RowOffset:UIntPtr;
  I, J: Integer;
  CurLSN:Tlog_LSN;
  RowLength: Integer;
  RawData: TMemory_data;
  sctest:TSqlConntest;
begin
  New(logBlockHeader);
  while not Terminated do
  begin
    Sleep(100);
    if FAutoRun then
    begin
      FPicking := true;
      FAutoRun := False;
      FLogSource.loger.Add('�����ɼ��߳�...', log_warning);
    end;

    if not FPicking then Continue;

    FLogSource.Loger.Add('LogPicker Search begin Offset...');
    while pkgMgr.FpaddingPrisePkg.Count > 0 do
    begin
      FLogSource.loger.Add('�ȴ���������գ�', log_warning);
      sleep(1000);
      if not FPicking then
        goto beginPoint;
    end;

      CurLSN := FLogSource.FProcCurLSN;
      if (CurLSN.LSN_1 = 0) or (CurLSN.LSN_2 = 0) or (CurLSN.LSN_3 = 0) then
      begin
        FLogSource.Loger.Add('LogPicker.Execute:invalid lsn [0]!%s', [LSN2Str(CurLSN)], LOG_ERROR);
        Sleep(1000);
        Continue;
      end;
      sctest := TSqlConntest.create(FLogSource);
      if WaitForSingleObject(sctest.Handle, 3000) = WAIT_TIMEOUT then
      begin
        sctest.FreeOnTerminate := True;
        FLogSource.Loger.Add('�������ݿⳬʱ!%s', [LSN2Str(CurLSN)], LOG_ERROR);
        Continue;
      end;
      sctest.Free;
      FLogSource.Loger.Add('���ݿ����ӳɹ�...');

    setDbOn(FLogSource.Fdbc);
    setCapLogStart(FLogSource.Fdbc);
    FLogSource.Fdbc.getDb_dbInfo(true);
    if Fspm = nil then
      Fspm := TSqlProcessMonitor.Create(FLogSource.Fdbc.SvrProcessID, TerminateDelegate);

      Tmpvlf := FLogSource.GetVlf_SeqNo(CurLSN.LSN_1);
      try
        if (Tmpvlf = nil) or (Tmpvlf.SeqNo <> CurLSN.LSN_1) then
        begin
          FLogSource.Loger.Add('LogPicker.Execute:lsn out of vlfs [1]!%s', [LSN2Str(CurLSN)], LOG_ERROR);
          Sleep(1000);
          Continue;
        end;
        DataProvider := FLogReader.getDataProvider(Tmpvlf.fileId);
        if DataProvider = nil then
        begin
          FLogSource.Loger.Add('LogPicker.Execute:���ڻ�ȡDataProviderʧ�ܣ�GetRawLogByLSNȡ����',[LOG_ERROR]);
          Sleep(1000);
          Continue;
        end;
        LogBlockPosi := Tmpvlf.VLFOffset + CurLSN.LSN_2 * $200;
        vlf := Tmpvlf^;
      finally
        if Tmpvlf<>nil then
          Dispose(Tmpvlf);
      end;

      if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
      begin
        FLogSource.Loger.Add('LogPicker.Execute:read logBlock data Error...%s', [LSN2Str(CurLSN)], LOG_ERROR);
        Sleep(1000);
        Continue;
      end;
      if (logBlockHeader.BeginLSN.LSN_1 <> CurLSN.LSN_1) and
         (logBlockHeader.BeginLSN.LSN_2 <> CurLSN.LSN_2) and
         (not logBlockRawCheck(logBlockHeader^)) then
      begin
        FLogSource.Loger.Add('LogPicker.Execute:logBlock data invalid...%s', [LSN2Str(CurLSN)], LOG_ERROR);
        Sleep(1000);
        Continue;
      end;

      if CurLSN.LSN_3 > logBlockHeader.OperationCount then
      begin
        //��ǰ����û�����id
        FLogSource.Loger.Add('LogPicker.Execute:invalid lsn [4] RowId no found !%s', [LSN2Str(CurLSN)], LOG_ERROR);
        Sleep(1000);
        Continue;
      end;

    //������һ���飨֮��ѭ����ȡ����
    LogBlockPosi := LogBlockPosi + logBlockHeader.Size;
    while FPicking do
    begin
      while True do
      begin
        if (LogBlockPosi + SizeOf(TlogBlock)) > (vlf.VLFOffset + vlf.VLFSize) then
        begin
          //vlf�Ѷ���
          Break;
        end;
        //ѭ��ֱ����һ����Ч
        while True do
        begin
          DataProvider.flush;
          if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
          begin
            FLogSource.Loger.Add('LogPicker.Execute:read logBlock data Error...%s', [LSN2Str(CurLSN)], LOG_ERROR);
            goto beginPoint;
          end;
          if (logBlockHeader.BeginLSN.LSN_1 = CurLSN.LSN_1) and logBlockRawCheck(logBlockHeader^) then
          begin
            Break;
          end;
          //�������黹û�б���ʼ�����͵�10s�ڶ�ȡһ��. <<<����ÿ����Ӧһ�� Terminated>>>
          for I := 0 to 10 - 1 do
          begin
            Sleep(1000);
            if not FPicking then
            begin
              goto beginPoint;
            end;
          end;
        end;
        //����������
        LogBlockBuf := GetMemory(logBlockHeader.Size);
        CurLSN := logBlockHeader.BeginLSN;
        if DataProvider.Read(LogBlockBuf^, LogBlockPosi, logBlockHeader.Size) <> logBlockHeader.Size then
        begin
          FLogSource.Loger.Add('LogPicker.Execute:get LogBlock  fail!%s', [LSN2Str(CurLSN)], LOG_ERROR);
          FreeMem(LogBlockBuf);
          goto beginPoint;
        end;
        FLogReader.RepairLogBlockOverlay(LogBlockBuf);
        for I := 0 to logBlockHeader.OperationCount - 1 do
        begin
          RowOffset := PWORD(UIntPtr(LogBlockBuf) + logBlockHeader.endOfBlock - I * 2 - 2)^;
          if I = logBlockHeader.OperationCount - 1 then
          begin
          //last one
            RowLength := logBlockHeader.endOfBlock - logBlockHeader.OperationCount * 2 - RowOffset;
          end
          else
          begin
            RowLength := PWORD(UIntPtr(LogBlockBuf) + logBlockHeader.endOfBlock - I * 2 - 4)^ - RowOffset;
          end;

          RawData.dataSize := RowLength;
          RawData.data := GetMemory(RowLength);
          Move(Pointer(UIntPtr(LogBlockBuf) + RowOffset)^, RawData.data^, RowLength);

          if pkgMgr.addRawLog(CurLSN, RawData, False) = Pkg_Err_NoBegin then
          begin
            getRawLogTrans(CurLSN, RawData);
            FreeMem(RawData.data);
          end;
        //�������̫��������ͣ��ȡ����
          while pkgMgr.FpaddingPrisePkg.Count > paddingPrisePkgMaxSize do
          begin
            FLogSource.loger.Add('��������������ͣ��ȡ��־������30s�������', log_warning or LOG_IMPORTANT);
            for J := 0 to 30 - 1 do
            begin
              Sleep(100);
              if not FPicking then
              begin
                FreeMem(LogBlockBuf);
                goto beginPoint;
              end;
            end;
          end;

          if not FPicking then
          begin
            FreeMem(LogBlockBuf);
            goto beginPoint;
          end;
          CurLSN.LSN_3 := CurLSN.LSN_3 + 1;
        end;
        FreeMem(LogBlockBuf);
        //��һ����
        LogBlockPosi := LogBlockPosi + logBlockHeader.Size;
      end;
      //��һ��VLF
      while True do
      begin
        FLogSource.Fdbc.getDb_VLFs();
        Tmpvlf := FLogSource.GetVlf_SeqNo(CurLSN.LSN_1 + 1);
        if Tmpvlf <> nil then
        begin
          vlf := Tmpvlf^;
          Dispose(Tmpvlf);
          DataProvider := FLogReader.getDataProvider(vlf.fileId);
          if DataProvider = nil then
          begin
            FLogSource.Loger.Add('��ȡVLF����%d', [CurLSN.LSN_1 + 1], LOG_ERROR);
          end else begin
            DataProvider.flush;
            if (DataProvider.Read(vlfHeader, vlf.VLFOffset, SizeOf(TVLFHeader)) = SizeOf(TVLFHeader)) then
            begin
              if (vlfHeader.VLFHeadFlag = $AB) and (vlfHeader.SeqNo = CurLSN.LSN_1 + 1) then
              begin
                //ȷ���ҵ�Vlf
                Break;
              end;
            end;
            //FLogSource.Loger.Add('��ȡVLF���ݳ���%d', [CurLSN.LSN_1 + 1], LOG_ERROR);
          end;
        end;
        //���û���ҵ����͵�10s����  <<<����ÿ����Ӧһ�� Terminated>>>
        for I := 0 to 10 - 1 do
        begin
          Sleep(1000);
          if not FPicking then
          begin
            //��Ӧ Terminated
            goto beginPoint;
          end;
        end;
      end;
      CurLSN.LSN_1 := CurLSN.LSN_1 + 1;
      //�ҵ�Vlf�еĵ�һ����
      LogBlockPosi := vlf.VLFOffset + $200;
      while LogBlockPosi < vlf.VLFOffset + vlf.VLFSize do
      begin
        if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
        begin
          FLogSource.Loger.Add('LogPicker.Execute:logBlock Read fail! no more data !%s', [LSN2Str(CurLSN)], LOG_ERROR);
          goto beginPoint;
        end;
        if logBlockRawCheck(logBlockHeader^) and (CurLSN.LSN_1 = logBlockHeader.BeginLSN.LSN_1) then
        begin
          Break;
        end
        else
        begin
          LogBlockPosi := LogBlockPosi + $200;
        end;
      end;
    end;

beginPoint:
    FLogReader.ClearReader;
    pkgMgr.ClearItems;
  end;

  Dispose(logBlockHeader);
end;

function TSql2014LogPicker.GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;
begin
  Result := FLogReader.GetRawLogByLSN(lsn, OutBuffer);
end;

procedure TSql2014LogPicker.getRawLogTrans(LSN: Tlog_LSN; tranCommitData: TMemory_data);
var
  COMMIT_XACT:PRawLog_COMMIT_XACT;
  sql:string;
  resDataset:TCustomADODataSet;
  TTsPkg :TTransPkg;
  tmplsn:Tlog_LSN;
  tmpRaw:TMemory_data;
  bb:TBlobField;
begin
  COMMIT_XACT := PRawLog_COMMIT_XACT(tranCommitData.data);
  if COMMIT_XACT.normalData.OpCode<>LOP_COMMIT_XACT then
    Exit;

  sql :=Format('select [Current LSN],[Log Record] from fn_dblog(''%s'',''%s'') where [Transaction ID]=''%s'' ',[
     LSN2Str(COMMIT_XACT.BeginLsn), LSN2Str(lsn), TranId2Str(COMMIT_XACT.normalData.TransID) ]);
  if FLogSource.Fdbc.ExecSql(sql, resDataset, True) then
  begin
    if resDataset.RecordCount > 2 then
    begin
      resDataset.First;
      TTsPkg := TTransPkg.Create(COMMIT_XACT.normalData.TransID);
      while not resDataset.eof do
      begin
        if resDataset.Fields[1].IsBlob then
        begin
          bb := TBlobField(resDataset.Fields[1]);
          tmpRaw.dataSize := bb.Size;
          tmpRaw.data := getmemory(tmpRaw.dataSize);
          Move(bb.Value[0], tmpRaw.data^, tmpRaw.dataSize);
          tmplsn := Str2LSN(resDataset.Fields[0].AsString);
          TTsPkg.addRawLog(TTransPkgItem.Create(tmplsn, tmpRaw));
        end;
        resDataset.Next;
      end;
      pkgMgr.FpaddingPrisePkg.Push(TTsPkg);
    end;
    resDataset.Free;
  end;
end;

procedure TSql2014LogPicker.Start;
begin
  FPicking := True;
end;

function TSql2014LogPicker.state: LS_STATUE;
begin
  if Terminated then
    Result := tLS_stopped
  else if not FPicking then
    Result := tLS_suspension
  else begin
    Result := tLS_running;
  end;
end;

{ TSqlConntest }

constructor TSqlConntest.Create(LogSource: TLogSource);
begin
  FLogSource := LogSource;
  inherited Create(False);
end;

destructor TSqlConntest.Destroy;
begin

  inherited;
end;

procedure TSqlConntest.Execute;
begin
  FLogSource.Fdbc.reConnect;
end;

end.

