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

  TSql2014LogReader = class(TObject)
  private
    FLogSource: TLogSource;
    FFFdataProvider: array[0..256] of TLogProvider;   //最多只能有256个物理日志文件
    FAddLogFilecs:TCriticalSection;
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
    FBeginLsn:Tlog_LSN;
    //FvlfHeader: PVLFHeader;
    //FlogBlock: PlogBlock;
    //Fvlf:PVLF_Info;
    pkgMgr: TTransPkgMgr;
    FAnalyzer:TSql2014logAnalyzer;
    Fspm:TSqlProcessMonitor;
  public
    constructor Create(LogSource: TLogSource; BeginLsn: Tlog_LSN);
    destructor Destroy; override;
    procedure Execute; override;
    procedure TerminateDelegate;
    function GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean; override;
  end;

implementation

uses
  Windows, SysUtils, Memory_Common, loglog, LocalDbLogProvider, OpCode,
  plugins, hexValUtils;


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
var
  I: Integer;
begin
  for I := 0 to Length(FFFdataProvider) - 1 do
  begin
    if FFFdataProvider[I] <> nil then
      FFFdataProvider[I].Free;
  end;
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
              FLogSource.Loger.Add('无法获取正确的Provider：%d',[FileId], LOG_ERROR);
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
      FLogSource.Loger.Add('由于获取DataProvider失败！GetRawLogByLSN取消！',[LOG_ERROR]);
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
      //当前块中没有这个id
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

      RowOffset := Uintptr(logBlockBuffer) + logBlockHeader.endOfBlock - (LSN.LSN_3 - logBlockHeader.BeginLSN.LSN_3 + 1) * 2;
      OutBuffer.dataSize := PageRowCalcLength(Pointer(RowOffset));
      if OutBuffer.dataSize > 0 then
      begin
        OutBuffer.data := GetMemory(OutBuffer.dataSize);
        Move(Pointer(RowOffset)^, OutBuffer.data^, OutBuffer.dataSize);
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

constructor TSql2014LogPicker.Create(LogSource: TLogSource; BeginLsn: Tlog_LSN);
begin
  inherited Create(False);
  FLogReader := TSql2014LogReader.Create(LogSource);
  FLogSource := LogSource;
  FBeginLsn := BeginLsn;

  pkgMgr := TTransPkgMgr.Create(FLogSource);

  FAnalyzer := TSql2014logAnalyzer.Create(pkgMgr, LogSource);
  Self.NameThreadForDebugging('TSql2014LogPicker', Self.ThreadID);
  FLogSource.Loger.Add('LogPicker init...');

  Fspm := TSqlProcessMonitor.Create(LogSource.Fdbc.SvrProcessID, TerminateDelegate);
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
  FLogSource.Loger.Add('由于数据库服务已停止LogPicker将退出...', LOG_IMPORTANT or LOG_WARNING);
  Terminate;
  FLogSource.FLogPicker := nil;
  FLogSource.CreateAutoStartTimer;
end;

procedure TSql2014LogPicker.Execute;
var
  Tmpvlf: PVLF_Info;
  LogBlockPosi: Int64;
  RowLength: Integer;
  RowOffset:UIntPtr;
  I, J: Integer;
  RawData: TMemory_data;


  vlf: TVLF_Info;
  vlfHeader: TVLFHeader;
  LogBlockBuf:Pointer;
  DataProvider:TLogProvider;
  logBlockHeader: PlogBlock;
  CurLSN:Tlog_LSN;
begin
  FLogSource.Loger.Add('LogPicker start...');

  if (FBeginLsn.LSN_1 = 0) or (FBeginLsn.LSN_2 = 0) or (FBeginLsn.LSN_3 = 0) then
  begin
    FLogSource.Loger.Add('LogPicker.Execute:invalid lsn [0]!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  Tmpvlf := FLogSource.GetVlf_SeqNo(FBeginLsn.LSN_1);
  try
    if (Tmpvlf = nil) or (Tmpvlf.SeqNo <> FBeginLsn.LSN_1) then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:lsn out of vlfs [1]!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;
    DataProvider := FLogReader.getDataProvider(Tmpvlf.fileId);
    if DataProvider = nil then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:由于获取DataProvider失败！GetRawLogByLSN取消！',[LOG_ERROR]);
      Exit;
    end;
    LogBlockPosi := Tmpvlf.VLFOffset + FBeginLsn.LSN_2 * $200;
    vlf := Tmpvlf^;
  finally
    Dispose(Tmpvlf);
  end;
  New(logBlockHeader);
  try
    if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) = 0) then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:read logBlock data Error...%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;
    if (logBlockHeader.BeginLSN.LSN_1 <> FBeginLsn.LSN_1) and
       (logBlockHeader.BeginLSN.LSN_2 <> FBeginLsn.LSN_2) and
       (not logBlockRawCheck(logBlockHeader^)) then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:logBlock data invalid...%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;

    if FBeginLsn.LSN_3 > logBlockHeader.OperationCount then
    begin
      //当前块中没有这个id
      FLogSource.Loger.Add('LogPicker.Execute:invalid lsn [4] RowId no found !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;
    //跳到下一个块（之后循环读取数据
    LogBlockPosi := LogBlockPosi + logBlockHeader.Size;

    if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:read logBlock data Error...%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;
    if (logBlockHeader.BeginLSN.LSN_1 <> FBeginLsn.LSN_1) and
       (logBlockHeader.BeginLSN.LSN_2 <> FBeginLsn.LSN_2) and
       (not logBlockRawCheck(logBlockHeader^)) then
    begin
      FLogSource.Loger.Add('LogPicker.Execute:logBlock data invalid...%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;

    while not Terminated do
    begin
      while True do  //循环块
      begin
        //先读出整个块，然后处理末尾的修复数据
        LogBlockBuf := GetMemory(logBlockHeader.Size);
        try
          CurLSN := logBlockHeader.BeginLSN;
          if DataProvider.Read(LogBlockBuf^, LogBlockPosi, logBlockHeader.Size) <> logBlockHeader.Size then
          begin
            FLogSource.Loger.Add('LogPicker.Execute:get LogBlock  fail!%s', [LSN2Str(CurLSN)], LOG_ERROR);
            Exit;
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
              RowLength := PWORD(UIntPtr(LogBlockBuf) + logBlockHeader.endOfBlock - I * 2 - 2)^ - RowOffset;
            end;

            RawData.dataSize := RowLength;
            RawData.data := GetMemory(RowLength);
            Move(RawData.data^, Pointer(UIntPtr(LogBlockBuf) + RowOffset)^, RowLength);

            if pkgMgr.addRawLog(CurLSN, RawData, False) = Pkg_Err_NoBegin then
            begin
              FreeMem(RawData.data);
            end;
          //如果队列太大，这里暂停读取数据
            while pkgMgr.FpaddingPrisePkg.Count > paddingPrisePkgMaxSize do
            begin
              FLogSource.loger.Add('缓冲区已满！暂停读取日志。将于30s后继续！', log_warning or LOG_IMPORTANT);
              for J := 0 to 30 - 1 do
              begin
                Sleep(100);
                if Terminated then
                begin
                //响应 Terminated
                  Exit;
                end;
              end;
            end;

            if Terminated then
            begin
            //响应 Terminated
              Exit;
            end;
            CurLSN.LSN_3 := CurLSN.LSN_3 + 1;
          end;
        finally
          FreeMem(LogBlockBuf);
        end;

        //一个块儿处理完 继续下一个块
        LogBlockPosi := LogBlockPosi + logBlockHeader.Size;
        if (LogBlockPosi + SizeOf(TlogBlock)) > (vlf.VLFOffset + vlf.VLFSize) then
        begin
          //vlf已读完
          break;
        end;
        //循环直到下一块生效
        while True do
        begin
          DataProvider.flush;
          if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
          begin
            FLogSource.Loger.Add('LogPicker.Execute:read logBlock data Error...%s', [LSN2Str(CurLSN)], LOG_ERROR);
            Exit;
          end;
          if (logBlockHeader.BeginLSN.LSN_1 = CurLSN.LSN_1) and
             logBlockRawCheck(logBlockHeader^) then
          begin
            Break;
          end;
          //如果这个块还没有被初始化，就等10s在读取一次. <<<必须每秒响应一次 Terminated>>>
          for I := 0 to 10 - 1 do
          begin
            Sleep(1000);
            if Terminated then
            begin
              //响应 Terminated
              Exit;
            end;
          end;
        end;
      end;
      //当前vlf已读取完，查找下一个vlf
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
            FLogSource.Loger.Add('获取VLF出错！%d', [CurLSN.LSN_1 + 1], LOG_ERROR);
          end else begin
            DataProvider.flush;
            if (DataProvider.Read(vlfHeader, vlf.VLFOffset, SizeOf(TVLFHeader)) = SizeOf(TVLFHeader)) then
            begin
              if (vlfHeader.VLFHeadFlag = $AB) and (vlfHeader.SeqNo = CurLSN.LSN_1 + 1) then
              begin
                //确认找到Vlf
                Break;
              end;
            end;
          end;
        end;
        //如果没有找到，就等10s再试  <<<必须每秒响应一次 Terminated>>>
        for I := 0 to 10 - 1 do
        begin
          Sleep(1000);
          if Terminated then
          begin
            //响应 Terminated
            Exit;
          end;
        end;
      end;
      //找到Vlf中的第一个块
      LogBlockPosi := vlf.VLFOffset + $200;
      while LogBlockPosi < vlf.VLFOffset + vlf.VLFSize do
      begin
        if (DataProvider.Read(logBlockHeader^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
        begin
          FLogSource.Loger.Add('LogPicker.Execute:logBlock Read fail! no more data !%s', [LSN2Str(CurLSN)], LOG_ERROR);
          Exit;
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
  finally
    Dispose(logBlockHeader);
  end;

end;

function TSql2014LogPicker.GetRawLogByLSN(LSN: Tlog_LSN; var OutBuffer: TMemory_data): Boolean;
begin
  Result := FLogReader.GetRawLogByLSN(lsn, OutBuffer);
end;




end.

