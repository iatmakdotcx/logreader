unit Sql2014LogReader;

interface

uses
  I_LogProvider, I_logReader, p_structDefine, Types, databaseConnection,
  LogSource;

type
  TSql2014LogReader = class(TlogReader)
  private
    FLogSource: TLogSource;
    FdataProvider: array[0..256] of TLogProvider;     //最多只能有256个
  public
    constructor Create(LogSource: TLogSource);
    destructor Destroy; override;
    procedure listVlfs(fid: Byte); override;
    procedure listLogBlock(vlfs: PVLF_Info); override;
    function GetRawLogByLSN(LSN: Tlog_LSN; vlfs: PVLF_Info; var OutBuffer: TMemory_data): Boolean; override;
    procedure custRead(fileId: byte; posi, size: Int64; var OutBuffer: TMemory_data); override;
  end;

implementation

uses
  Classes, Windows, SysUtils, Memory_Common, pluginlog, LocalDbLogProvider;

{ TSql2014LogReader }

constructor TSql2014LogReader.Create(LogSource: TLogSource);
var
  I: Integer;
  logp: TLocalDbLogProvider;
begin
  FLogSource := LogSource;

  for I := 0 to Length(FLogSource.Fdbc.FlogFileList) - 1 do
  begin
    if LogSource.Fdbc.CheckIsLocalHost then
    begin
      logp := TLocalDbLogProvider.Create;
      logp.init(FLogSource.Fdbc.FlogFileList[I].filehandle);
      FdataProvider[FLogSource.Fdbc.FlogFileList[I].fileId] := logp;
    end
    else
    begin
      //TODO:支持远程运行
      Loger.Add('远程运行！', log_error);
    end;

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
  LogBlockPosi, RowPosi, RowLength: Integer;
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
    while LogBlockPosi < vlfs.VLFSize do
    begin
      FdataProvider[vlfs.fileId].Seek(LogBlockPosi + vlfs.VLFOffset, soBeginning);
      if (FdataProvider[vlfs.fileId].Read(abuf^, SizeOf(TlogBlock)) = 0) then
      begin
        Loger.Add('read data Error...........');
        Exit;
      end;
      if abuf.flag <> 0 then
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
        if not FdataProvider[vlfs.fileId].Read_Word(RowOffset2, LogBlockPosi + 1) then
        begin
          Loger.Add('invalid lsn [7] get RowOffset Fail!%s', [LSN2Str(LSN)]);
          Exit;
        end;
        RowPosi := RowPosi + RowOffset;
        RowLength := RowOffset - RowOffset2;
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

end.

