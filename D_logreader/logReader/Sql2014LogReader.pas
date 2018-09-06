unit Sql2014LogReader;

interface

uses
  I_LogProvider, I_logReader, p_structDefine, Types, databaseConnection,
  LogSource, Classes, LogtransPkg, Contnrs, LogtransPkgMgr, Sql2014logAnalyzer;

type
  TSql2014LogReader = class(TlogReader)
  private
    FLogSource: TLogSource;
    FdataProvider: array[0..256] of TLogProvider;   //最多只能有256个物理日志文件
  public
    constructor Create(LogSource: TLogSource);
    destructor Destroy; override;
    procedure listVlfs(fid: Byte); override;
    procedure listLogBlock(vlfs: PVLF_Info); override;
    function GetRawLogByLSN(LSN: Tlog_LSN; vlfs: PVLF_Info; var OutBuffer: TMemory_data): Boolean; override;
    procedure custRead(fileId: byte; posi, size: Int64; var OutBuffer: TMemory_data); override;
    procedure RepairLogBlockAppendData(Pnt:Pointer;logBlock:PlogBlock);
  end;

  TSql2014LogPicker = class(TLogPicker)
  private
    FLogReader: TSql2014LogReader;
    FLogSource: TLogSource;
    FBeginLsn:Tlog_LSN;
    FvlfHeader: PVLFHeader;
    FlogBlock: PlogBlock;
    Fvlf:PVLF_Info;
    pkgMgr: TTransPkgMgr;
    FAnalyzer:TSql2014logAnalyzer;
    procedure RepairLogBlockAppendData(Pnt: Pointer; logBlock:PlogBlock);
  public
    constructor Create(LogSource: TLogSource; BeginLsn: Tlog_LSN);
    destructor Destroy; override;
    procedure Execute; override;
    procedure getTransBlock(rawlog: PRawLog_COMMIT_XACT);

  end;

implementation

uses
  Windows, SysUtils, Memory_Common, loglog, LocalDbLogProvider, OpCode,
  plugins, hexValUtils;


function logBlockRawCheck(Lb: TlogBlock): boolean;
begin
  if ((Lb.flag = $90) or
      (Lb.flag = $98) or
      (Lb.flag = $40) or
      (Lb.flag = $48) or
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


{ TSql2014LogReader }

constructor TSql2014LogReader.Create(LogSource: TLogSource);
var
  I: Integer;
  logp: TLocalDbLogProvider;
begin
  FLogSource := LogSource;
  for I := 0 to Length(FLogSource.Fdbc.FlogFileList) - 1 do
  begin
    logp := TLocalDbLogProvider.Create;
    logp.init(FLogSource.Fdbc.FlogFileList[I].filehandle);
    FdataProvider[FLogSource.Fdbc.FlogFileList[I].fileId] := logp;
  end;
end;

procedure TSql2014LogReader.custRead(fileId: byte; posi, size: Int64; var OutBuffer: TMemory_data);
begin
  if size = -1 then
    size := FdataProvider[fileId].getFileSize;

  OutBuffer.data := AllocMem(size);
  OutBuffer.dataSize := size;
  FdataProvider[fileId].Seek(posi, soBeginning);
  if FdataProvider[fileId].Read(OutBuffer.data^, size) = 0 then
  begin
    Loger.Add('读取文件失败！@！');
    FreeMem(OutBuffer.data);
    OutBuffer.data := nil;
    OutBuffer.dataSize := 0;
    Exit;
  end
  else
  begin

  end;
end;

destructor TSql2014LogReader.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(FdataProvider) - 1 do
  begin
    if FdataProvider[I] <> nil then
      FdataProvider[I].Free;
  end;
  inherited;
end;

function TSql2014LogReader.GetRawLogByLSN(LSN: Tlog_LSN; vlfs: PVLF_Info; var OutBuffer: TMemory_data): Boolean;
var
  pbb: PVLFHeader;
  abuf: PlogBlock;
  LogBlockPosi, RowPosi, RowLength: UIntPtr;
  RowOffset, RowOffset2: Word;
begin
  Result := False;
  OutBuffer.data := nil;
  OutBuffer.dataSize := 0;
  if (LSN.LSN_1 = 0) or (LSN.LSN_2 = 0) or (LSN.LSN_3 = 0) then
  begin
    Loger.Add('invalid lsn [0]!%s', [LSN2Str(LSN)]);
    Exit;
  end;

  if (vlfs = nil) or (vlfs.SeqNo <> LSN.LSN_1) then
  begin
    Loger.Add('invalid lsn [1]!%s', [LSN2Str(LSN)]);
    Exit;
  end;
  FdataProvider[vlfs.fileId].Seek(vlfs.VLFOffset, soBeginning);
  New(pbb);
  new(abuf);
  try
    if (FdataProvider[vlfs.fileId].Read(pbb^, SizeOf(TVLFHeader)) = 0) then
    begin
      Loger.Add('invalid lsn [2] VLFOffset out of range !%s', [LSN2Str(LSN)]);
      Exit;
    end;
    if (pbb.VLFHeadFlag <> $AB) or (pbb.SeqNo <> LSN.LSN_1) then
    begin
      Loger.Add('invalid lsn [3] VLFOffset Error !%s', [LSN2Str(LSN)]);
      Exit;
    end;

    LogBlockPosi := $200;
    //查找此vlf中第一个块（虽然从数据上看第一个块总是在$2000的位置）
    while LogBlockPosi < vlfs.VLFSize do
    begin
      FdataProvider[vlfs.fileId].Seek(LogBlockPosi + vlfs.VLFOffset, soBeginning);
      if (FdataProvider[vlfs.fileId].Read(abuf^, SizeOf(TlogBlock)) = 0) then
      begin
        Loger.Add('read data Error...........');
        Exit;
      end;
      if logBlockRawCheck(abuf^) then
      begin
        if abuf.BeginLSN.LSN_1 <> vlfs.SeqNo then
        begin
          //走到这里，说明当前vlf中前半部分被新日志覆盖，后面是老数据（正在使用的vlf）
          Exit;
        end
        else
        begin
          if abuf.BeginLSN.LSN_2 = LSN.LSN_2 then
          begin
            //找到日志块
            Break;
          end;
          LogBlockPosi := LogBlockPosi + abuf.Size;
        end;
      end
      else
      begin
        LogBlockPosi := LogBlockPosi + $200;
      end;
    end;
    if abuf.BeginLSN.LSN_2 = LSN.LSN_2 then
    begin
      LogBlockPosi := LogBlockPosi + vlfs.VLFOffset;
      if LSN.LSN_3 > abuf.OperationCount then
      begin
        //当前块中没有这个id
        Loger.Add('invalid lsn [4] RowId no found !%s', [LSN2Str(LSN)]);
        Exit;
      end
      else if LSN.LSN_3 = abuf.OperationCount then
      begin
        //最后一个
        RowPosi := LogBlockPosi;
        LogBlockPosi := LogBlockPosi + abuf.endOfBlock - LSN.LSN_3 * 2;
        if not FdataProvider[vlfs.fileId].Read_Word(RowOffset, LogBlockPosi) then
        begin
          Loger.Add('invalid lsn [5] get RowOffset Fail!%s', [LSN2Str(LSN)]);
          Exit;
        end;
        RowPosi := RowPosi + RowOffset;
        RowLength := LogBlockPosi - RowPosi;
      end
      else
      begin
        RowPosi := LogBlockPosi;
        LogBlockPosi := LogBlockPosi + abuf.endOfBlock - LSN.LSN_3 * 2;
        if not FdataProvider[vlfs.fileId].Read_Word(RowOffset, LogBlockPosi) then
        begin
          Loger.Add('invalid lsn [6] get RowOffset Fail!%s', [LSN2Str(LSN)]);
          Exit;
        end;
        if not FdataProvider[vlfs.fileId].Read_Word(RowOffset2, LogBlockPosi - 2) then
        begin
          Loger.Add('invalid lsn [7] get RowOffset Fail!%s', [LSN2Str(LSN)]);
          Exit;
        end;
        RowPosi := RowPosi + RowOffset;
        RowLength := RowOffset2 - RowOffset;
      end;

      OutBuffer.data := AllocMem(RowLength);
      FdataProvider[vlfs.fileId].Seek(RowPosi, soBeginning);
      if FdataProvider[vlfs.fileId].Read(OutBuffer.data^, RowLength) = 0 then
      begin
        Loger.Add('get Row log fail!%s', [LSN2Str(LSN)]);
        FreeMem(OutBuffer.data);
        OutBuffer.data := nil;
        Exit;
      end;
      OutBuffer.dataSize := RowLength;
      Result := true;
    end;
  finally
    Dispose(abuf);
    Dispose(pbb);
  end;
end;

procedure TSql2014LogReader.listLogBlock(vlfs: PVLF_Info);
var
  abuf: PlogBlock;
  posi: Integer;
begin
  // 每个块最大0xFFFF  最小0x0200
  new(abuf);
  posi := $200;
  while posi < vlfs.VLFSize do
  begin
    FdataProvider[vlfs.fileId].Seek(posi + vlfs.VLFOffset, soBeginning);
    if (FdataProvider[vlfs.fileId].Read(abuf^, SizeOf(TlogBlock)) = 0) then
    begin
      Loger.Add('read data Error...........');
      break;
    end;
    if abuf.flag <> 0 then
    begin
      if abuf.BeginLSN.LSN_1 <> vlfs.SeqNo then
      begin
        break;
      end
      else
      begin
        OutputDebugString(PChar(bytestostr(abuf, SizeOf(TlogBlock))));
        posi := posi + abuf.Size;
      end;
    end
    else
    begin
      posi := posi + $200;
    end;
  end;
  Dispose(abuf);
end;

procedure TSql2014LogReader.listVlfs(fid: Byte);
var
  pbb: PVLFHeader;
  iiiii: integer;
  ssIze: Integer;
begin
  iiiii := 0;
  FdataProvider[fid].Seek($2000, soBeginning);
  ssIze := SizeOf(TVLFHeader);
  New(pbb);
  repeat
    if (FdataProvider[fid].Read(pbb^, ssIze) = 0) then
      break;
    OutputDebugString(PChar(bytestostr(pbb, ssIze)));
    FdataProvider[fid].Seek(pbb^.CurrentBlockSize - ssIze, soCurrent);

    iiiii := iiiii + 1;

  until (pbb^.CurrentBlockSize = 0) or (iiiii > 200);

  Dispose(pbb);
end;

procedure TSql2014LogReader.RepairLogBlockAppendData(Pnt: Pointer;logBlock:PlogBlock);
var
  bBlockPosi:UIntPtr;
  eBlockPosi:UIntPtr;
begin
  bBlockPosi := 0;
  eBlockPosi := UIntPtr(Pnt) + logBlock.Size - 1;
  while bBlockPosi < logBlock.Size do
  begin
    PByte(UIntPtr(Pnt) + bBlockPosi)^ := Pbyte(eBlockPosi)^;
    bBlockPosi := bBlockPosi + $200;
    eBlockPosi := eBlockPosi - 1;
  end;
end;

{ TSql2014LogPicker }

constructor TSql2014LogPicker.Create(LogSource: TLogSource; BeginLsn: Tlog_LSN);
begin
  inherited Create(False);
  FLogReader := LogSource.FLogReader as TSql2014LogReader;
  FLogSource := LogSource;
  FBeginLsn := BeginLsn;

  pkgMgr := TTransPkgMgr.Create(FLogSource);
  New(FvlfHeader);
  New(FlogBlock);
  New(Fvlf);

  FAnalyzer := TSql2014logAnalyzer.Create(pkgMgr, LogSource);
  Self.NameThreadForDebugging('TSql2014LogPicker', Self.ThreadID);
end;

destructor TSql2014LogPicker.Destroy;
begin
  FAnalyzer.Terminate;
  FAnalyzer.WaitFor;
  FAnalyzer.Free;

  Dispose(FvlfHeader);
  Dispose(FlogBlock);
  Dispose(Fvlf);

  pkgMgr.Free;
  Loger.Add('LogPicker.Destroy.....');
  inherited;
end;

procedure TSql2014LogPicker.RepairLogBlockAppendData(Pnt:Pointer; logBlock:PlogBlock);
var
  bBlockPosi:UIntPtr;
  eBlockPosi:UIntPtr;
begin
  bBlockPosi := 0;
  eBlockPosi := UIntPtr(Pnt) + logBlock.Size - 1;
  while bBlockPosi < logBlock.Size do
  begin
    PByte(UIntPtr(Pnt) + bBlockPosi)^ := Pbyte(eBlockPosi)^;
    bBlockPosi := bBlockPosi + $200;
    eBlockPosi := eBlockPosi - 1;
  end;
end;

procedure TSql2014LogPicker.Execute;
label
  ExitLabel;
var
  vlf: PVLF_Info;
  LogBlockPosi: Int64;
  RowLength: Integer;
  RowOffset:UIntPtr;
  RowdataBuffer: Pointer;
  RowOffsetTable: array of Word;
  RIdx: Integer; //要获取的第N行
  I: Integer;
  NowLsn: Tlog_LSN;
  RawData: TMemory_data;
  LogBlockBuf:Pointer;
//  TmPPosition:Integer;
begin
  if (FBeginLsn.LSN_1 = 0) or (FBeginLsn.LSN_2 = 0) or (FBeginLsn.LSN_3 = 0) then
  begin
    Loger.Add('LogPicker.Execute:invalid lsn [0]!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  vlf := FLogSource.GetVlf_LSN(FBeginLsn);
  if (vlf = nil) or (vlf.SeqNo <> FBeginLsn.LSN_1) then
  begin
    Loger.Add('LogPicker.Execute:lsn out of vlfs [1]!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  Fvlf^ := vlf^;
  if (FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(FvlfHeader^, Fvlf.VLFOffset, SizeOf(TVLFHeader)) <> SizeOf(TVLFHeader)) then
  begin
    Loger.Add('LogPicker.Execute:vlfHeader Read fail! no more data !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  if (FvlfHeader.VLFHeadFlag <> $AB) or (FvlfHeader.SeqNo <> FBeginLsn.LSN_1) then
  begin
    Loger.Add('LogPicker.Execute:vlfHeader check Error !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  LogBlockPosi := Fvlf.VLFOffset + $200;
  while LogBlockPosi < Fvlf.VLFOffset + Fvlf.VLFSize do
  begin
    if (FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(FlogBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
    begin
      Loger.Add('LogPicker.Execute:logBlock Read fail! no more data !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      Exit;
    end;
    if logBlockRawCheck(FlogBlock^) then
    begin
      if FlogBlock.BeginLSN.LSN_1 <> Fvlf.SeqNo then
      begin
        //走到这里，说明当前vlf中前半部分被新日志覆盖，后面是老数据（正在使用的vlf）
        Exit;
      end
      else
      begin
        if FlogBlock.BeginLSN.LSN_2 = FBeginLsn.LSN_2 then
        begin
          //找到日志块
          Break;
        end;
        LogBlockPosi := LogBlockPosi + FlogBlock.Size;
      end;
    end
    else
    begin
      LogBlockPosi := LogBlockPosi + $200;
    end;
  end;
  if FlogBlock.BeginLSN.LSN_2 <> FBeginLsn.LSN_2 then
  begin
    Loger.Add('LogPicker.Execute:logBlock No found! vlf Eof!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;

  if FBeginLsn.LSN_3 > FlogBlock.OperationCount then
  begin
    //当前块中没有这个id
    Loger.Add('LogPicker.Execute:LSN RowId no found !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
    Exit;
  end;
  RIdx := FBeginLsn.LSN_3 - 1;
  while not Terminated do
  begin
    while True do  //循环块
    begin
      //先读出整个块，然后处理末尾的修复数据
      LogBlockBuf := GetMemory(FlogBlock.Size);
      if FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(LogBlockBuf^, LogBlockPosi, FlogBlock.Size)<>FlogBlock.Size then
      begin
        Loger.Add('LogPicker.Execute:get LogBlock  fail!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
        FreeMem(LogBlockBuf);
        Exit;
      end;
      RepairLogBlockAppendData(LogBlockBuf, FlogBlock);
      SetLength(RowOffsetTable, FlogBlock.OperationCount);
      for I := 0 to FlogBlock.OperationCount - 1 do
      begin
        RowOffsetTable[I] := PWORD(UIntPtr(LogBlockBuf) + UIntPtr(FlogBlock.endOfBlock - I * 2 - 2))^;
      end;
      if FlogBlock.BeginLSN.LSN_3 <> 1 then
      begin
        Loger.Add('LogPicker.Execute:FlogBlock is not begin from 1!%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
      end;

      while RIdx < FlogBlock.OperationCount do  //循环行
      begin
        if RIdx = FlogBlock.OperationCount - 1 then
        begin
          //最后一个
          RowOffset := UIntPtr(LogBlockBuf) + RowOffsetTable[RIdx];
          RowLength := UIntPtr(LogBlockBuf) + UIntPtr(FlogBlock.endOfBlock - FlogBlock.OperationCount * 2) - RowOffset;
        end
        else
        begin
          RowOffset := UIntPtr(LogBlockBuf) + RowOffsetTable[RIdx];
          RowLength := RowOffsetTable[RIdx + 1] - RowOffsetTable[RIdx];
        end;
        RowdataBuffer := GetMemory(RowLength);
        MoveMemory(RowdataBuffer, Pointer(RowOffset), RowLength);
        //如果成功。。
        NowLsn.LSN_1 := FlogBlock.BeginLSN.LSN_1;
        NowLsn.LSN_2 := FlogBlock.BeginLSN.LSN_2;
        NowLsn.LSN_3 := FlogBlock.BeginLSN.LSN_3 + RIdx;
        RawData.data := RowdataBuffer;
        RawData.dataSize := RowLength;

        if pkgMgr.addRawLog(NowLsn, RawData, False) = Pkg_Err_NoBegin then
        begin
          getTransBlock(RowdataBuffer);
          FreeMem(RowdataBuffer);
        end;
        //如果队列太大，这里暂停读取数据
        while pkgMgr.FpaddingPrisePkg.Count > paddingPrisePkgMaxSize do
        begin
          loger.Add('缓冲区已满！暂停读取日志。将于30s后继续！', log_warning or LOG_IMPORTANT);
          for I := 0 to 30 - 1 do
          begin
            Sleep(100);
            if Terminated then
            begin
              //响应 Terminated
              goto ExitLabel;
            end;
          end;
        end;

        //下一行
        RIdx := RIdx + 1;
        if Terminated then
        begin
          //响应 Terminated
          goto ExitLabel;
        end;
      end;
      FreeMem(LogBlockBuf);
      RIdx := 0;
      //一个块儿处理完 继续下一个块
      LogBlockPosi := LogBlockPosi + FlogBlock.Size;
      if (LogBlockPosi + SizeOf(TlogBlock)) > (Fvlf.VLFOffset + Fvlf.VLFSize) then
      begin
        //vlf已读完
        break;
      end;
      while True do
      begin
        FLogReader.FdataProvider[Fvlf.fileId].flush();
        if (FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(FlogBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
        begin
          Loger.Add('LogPicker.Execute:Next logBlock Read fail! no more data !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
          Exit;
        end;
        if logBlockRawCheck(FlogBlock^) and (FBeginLsn.LSN_1 = FlogBlock.BeginLSN.LSN_1) then
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
            goto ExitLabel;
          end;
        end;
      end;
      FBeginLsn.LSN_2 := FlogBlock.BeginLSN.LSN_2;
      FBeginLsn.LSN_3 := FlogBlock.BeginLSN.LSN_3;
    end;
    //当前vlf已读取完，查找下一个vlf
    while True do
    begin
      FLogSource.Fdbc.getDb_VLFs();
      vlf := FLogSource.GetVlf_SeqNo(FBeginLsn.LSN_1 + 1);
      if vlf <> nil then
      begin
        Fvlf^ := vlf^;
        FLogReader.FdataProvider[Fvlf.fileId].flush();
        if (FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(FvlfHeader^, Fvlf.VLFOffset, SizeOf(TVLFHeader)) = SizeOf(TVLFHeader)) then
        begin
          if (FvlfHeader.VLFHeadFlag = $AB) and (FvlfHeader.SeqNo = FBeginLsn.LSN_1 + 1) then
          begin
            //确认找到Vlf
            Break;
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
          goto ExitLabel;
        end;
      end;
    end;
    FBeginLsn.LSN_1 := FBeginLsn.LSN_1 + 1;
    //找到Vlf中的第一个块
    LogBlockPosi := Fvlf.VLFOffset + $200;
    while LogBlockPosi < Fvlf.VLFOffset + Fvlf.VLFSize do
    begin
      if (FLogReader.FdataProvider[Fvlf.fileId].Read_Bytes(FlogBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
      begin
        Loger.Add('LogPicker.Execute:logBlock Read fail! no more data !%s', [LSN2Str(FBeginLsn)], LOG_ERROR);
        Exit;
      end;
      if logBlockRawCheck(FlogBlock^) and (FBeginLsn.LSN_1 = FlogBlock.BeginLSN.LSN_1) then
      begin
        Break;
      end
      else
      begin
        LogBlockPosi := LogBlockPosi + $200;
      end;
    end;
    FBeginLsn.LSN_2 := FlogBlock.BeginLSN.LSN_2;
    FBeginLsn.LSN_3 := FlogBlock.BeginLSN.LSN_3;
  end;

ExitLabel:


end;

procedure TSql2014LogPicker.getTransBlock(rawlog: PRawLog_COMMIT_XACT);
label
  ExitLabel;
var
  vlf: PVLF_Info;
  Fpxvlf: TVLF_Info;
  LogBlockPosi: UIntPtr;
  RowLength, RowOffset: UIntPtr;
  RowdataBuffer: Pointer;
  RowOffsetTable: array of Word;
  RIdx: Integer; //要获取的第N行
  I: Integer;
  NowLsn: Tlog_LSN;
  RawData: TMemory_data;
  vlfHeader: PVLFHeader;
  logBlock: PlogBlock;
  prl:PRawLog;
  OpCode:Integer;
  LogBlockBuf:Pointer;
begin
  New(vlfHeader);
  New(logBlock);

  if rawlog = nil then
  begin
    Loger.Add('LogPicker.getTransBlock:BeginLsn lsn invalid[0]! NULL', LOG_ERROR);
    Exit;
  end;
  if (rawlog.BeginLsn.LSN_1 = 0) or (rawlog.BeginLsn.LSN_2 = 0) or (rawlog.BeginLsn.LSN_3 = 0) then
  begin
    Loger.Add('LogPicker.getTransBlock:BeginLsn lsn invalid[0]!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;
  vlf := FLogSource.GetVlf_LSN(rawlog.BeginLsn);
  if (vlf = nil) or (vlf.SeqNo <> rawlog.BeginLsn.LSN_1) then
  begin
    Loger.Add('LogPicker.getTransBlock:lsn out of vlfs [1]!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;
  Fpxvlf := vlf^;
  if (FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(vlfHeader^, Fpxvlf.VLFOffset, SizeOf(TVLFHeader)) <> SizeOf(TVLFHeader)) then
  begin
    Loger.Add('LogPicker.getTransBlock:vlfHeader Read fail! no more data !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;
  if (vlfHeader.VLFHeadFlag <> $AB) or (vlfHeader.SeqNo <> rawlog.BeginLsn.LSN_1) then
  begin
    Loger.Add('LogPicker.getTransBlock:vlfHeader check Error !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;
  LogBlockPosi := Fpxvlf.VLFOffset + $200;
  while LogBlockPosi < Fpxvlf.VLFOffset + Fpxvlf.VLFSize do
  begin
    if (FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(logBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
    begin
      Loger.Add('LogPicker.getTransBlock:logBlock Read fail! no more data !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
      Exit;
    end;
    if logBlockRawCheck(logBlock^) then
    begin
      if logBlock.BeginLSN.LSN_1 <> Fpxvlf.SeqNo then
      begin
        //走到这里，说明当前vlf中前半部分被新日志覆盖，后面是老数据（正在使用的vlf）
        Exit;
      end
      else
      begin
        if logBlock.BeginLSN.LSN_2 = rawlog.BeginLsn.LSN_2 then
        begin
          //找到日志块
          Break;
        end;
        LogBlockPosi := LogBlockPosi + logBlock.Size;
      end;
    end
    else
    begin
      LogBlockPosi := LogBlockPosi + $200;
    end;
  end;
  if logBlock.BeginLSN.LSN_2 <> rawlog.BeginLsn.LSN_2 then
  begin
    Loger.Add('LogPicker.getTransBlock:logBlock No found! vlf Eof!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;

  if rawlog.BeginLsn.LSN_3 > logBlock.OperationCount then
  begin
    //当前块中没有这个id
    Loger.Add('LogPicker.getTransBlock:LSN RowId no found !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
    Exit;
  end;
  RIdx := rawlog.BeginLsn.LSN_3 - 1;
  while True do // 循环Vlfs
  begin
    while True do  //循环块
    begin
      //先读出整个块，然后处理末尾的修复数据
      LogBlockBuf := AllocMem(logBlock.Size);
      if FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(LogBlockBuf^, LogBlockPosi, logBlock.Size)<>logBlock.Size then
      begin
        Loger.Add('LogPicker.Execute:get LogBlock  fail!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
        FreeMem(LogBlockBuf);
        Exit;
      end;
      RepairLogBlockAppendData(LogBlockBuf, logBlock);
      SetLength(RowOffsetTable, logBlock.OperationCount);
      for I := 0 to logBlock.OperationCount - 1 do
      begin
        RowOffsetTable[I] := PWORD(UIntPtr(LogBlockBuf) + UIntPtr(logBlock.endOfBlock - I * 2 - 2))^;
      end;
      while RIdx < logBlock.OperationCount do  //循环行
      begin
        if RIdx = logBlock.OperationCount - 1 then
        begin
          //最后一个
          RowOffset := UIntPtr(LogBlockBuf) + RowOffsetTable[RIdx];
          RowLength := UIntPtr(LogBlockBuf) + (logBlock.endOfBlock - logBlock.OperationCount * 2) - RowOffset;
        end
        else
        begin
          RowOffset := UIntPtr(LogBlockBuf) + RowOffsetTable[RIdx];
          RowLength := RowOffsetTable[RIdx+1] - RowOffsetTable[RIdx];
        end;
        RowdataBuffer := AllocMem(RowLength);
        MoveMemory(RowdataBuffer, Pointer(RowOffset), RowLength);
        //如果成功。。
        prl := RowdataBuffer;
        if (prl.TransID.Id1=rawlog.normalData.TransID.Id1) and (prl.TransID.Id2=rawlog.normalData.TransID.Id2) then
        begin
          //只找这个事务的数据
          NowLsn.LSN_1 := logBlock.BeginLSN.LSN_1;
          NowLsn.LSN_2 := logBlock.BeginLSN.LSN_2;
          NowLsn.LSN_3 := logBlock.BeginLSN.LSN_3 + RIdx;
          RawData.data := RowdataBuffer;
          RawData.dataSize := RowLength;
          OpCode := prl.OpCode;
          if pkgMgr.addRawLog(NowLsn, RawData, True) = Pkg_Err_NoBegin then
          begin
            FreeMem(RowdataBuffer);
          end;
          if OpCode = LOP_COMMIT_XACT then
          begin
            FreeMem(LogBlockBuf);
            goto ExitLabel;
          end;
        end else begin
          //不是当前事务的数据，这里直接释放掉
          FreeMem(RowdataBuffer);
        end;
        //下一行
        RIdx := RIdx + 1;
        if Terminated then
        begin
          //响应 Terminated
          FreeMem(LogBlockBuf);
          goto ExitLabel;
        end;
      end;
      RIdx := 0;
      FreeMem(LogBlockBuf);
      //一个块儿处理完 继续下一个块
      LogBlockPosi := LogBlockPosi + logBlock.Size;
      if (LogBlockPosi + SizeOf(TlogBlock)) > (Fpxvlf.VLFOffset + Fpxvlf.VLFSize) then
      begin
        //vlf已读完
        break;
      end;

      if (FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(logBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
      begin
        Loger.Add('LogPicker.getTransBlock:Next logBlock Read fail! no more data !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
        Exit;
      end;
      if (logBlock.flag = 0) or (logBlock.Size = 0) then
      begin
        Loger.Add('LogPicker.getTransBlock:Next logBlock is null!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
        Exit;
      end;
      //如果这个块还没有被初始化，就等10s在读取一次. <<<必须每秒响应一次 Terminated>>>

      rawlog.BeginLsn.LSN_2 := logBlock.BeginLSN.LSN_2;
      rawlog.BeginLsn.LSN_3 := logBlock.BeginLSN.LSN_3;
    end;
    //当前vlf已读取完，查找下一个vlf
    vlf := FLogSource.GetVlf_SeqNo(rawlog.BeginLsn.LSN_1 + 1);
    if vlf <> nil then
    begin
      Fpxvlf := vlf^;
      if (FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(vlfHeader^, Fpxvlf.VLFOffset, SizeOf(TVLFHeader)) = SizeOf(TVLFHeader)) then
      begin
        if (vlfHeader.VLFHeadFlag <> $AB) or (vlfHeader.SeqNo <> rawlog.BeginLsn.LSN_1 + 1) then
        begin
          Loger.Add('LogPicker.getTransBlock:Cross vlf data read fail!%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
          Exit;
        end;
      end else begin
        Loger.Add('LogPicker.getTransBlock:Cross vlf data read fail! no more data !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
        Exit;
      end;
    end;
   
    rawlog.BeginLsn.LSN_1 := rawlog.BeginLsn.LSN_1 + 1;
    //找到Vlf中的第一个块
    LogBlockPosi := Fpxvlf.VLFOffset + $200;
    if (FLogReader.FdataProvider[Fpxvlf.fileId].Read_Bytes(logBlock^, LogBlockPosi, SizeOf(TlogBlock)) <> SizeOf(TlogBlock)) then
    begin
      Loger.Add('LogPicker.getTransBlock:vlf first logBlock Read fail! no more data !%s', [LSN2Str(rawlog.BeginLsn)], LOG_ERROR);
      Exit;
    end;
    rawlog.BeginLsn.LSN_2 := logBlock.BeginLSN.LSN_2;
    rawlog.BeginLsn.LSN_3 := logBlock.BeginLSN.LSN_3;
  end;

ExitLabel:
  Dispose(vlfHeader);
  Dispose(logBlock);
end;




end.

