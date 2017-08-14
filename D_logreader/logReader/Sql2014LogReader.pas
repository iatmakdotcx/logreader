unit Sql2014LogReader;

interface

uses
  I_LogProvider, I_logReader, p_structDefine, Types, databaseConnection, 
  LogSource;

type
  TSql2014LogReader = class(TlogReader)
  private
     FLogSource: TLogSource;
     FdataProvider:array[0..256] of TLogProvider;     //最多只能有256个
  public
    constructor Create(LogSource: TLogSource);
    
    procedure listVlfs;override;
    procedure listLogBlock(vlfs:PVLF_Info);override;
    function GetRawLogByLSN(LSN:Tlog_LSN; vlfs:PVLF_Info ;OutBuffer:TMemory_data):Boolean;
  end;

implementation

uses
  Classes, Windows, SysUtils, Memory_Common, pluginlog;

{ TSql2014LogReader }

constructor TSql2014LogReader.Create(LogSource: TLogSource);
var
  I: Integer;
  logp:TLogProvider;
begin
  FLogSource := LogSource;

  for I := 0 to Length(FLogSource.Fdbc.FlogFileList) - 1 do
  begin
    logp := TLogProvider.Create;
    FdataProvider[FLogSource.Fdbc.FlogFileList[i].fileId] ;

  
  end;


end;

function TSql2014LogReader.GetRawLogByLSN(LSN:Tlog_LSN; vlfs:PVLF_Info ;OutBuffer:TMemory_data):Boolean;
var
  pbb: PVLFHeader;
begin
  Result:= False;
  OutBuffer.data := nil;
  OutBuffer.dataSize := 0;
  if (vlfs = nil) or (vlfs.SeqNo <> LSN.LSN_1) then
  begin
    Loger.Add('invalid lsn [1]!%s',[LSN2Str(LSN)]);
    Exit;
  end;
  FdataProvider.Seek(vlfs.VLFOffset, soBeginning);
  New(pbb);
  if (FdataProvider.Read(pbb^, SizeOf(TVLFHeader))=0) then
  begin
    Loger.Add('invalid lsn [2] VLFOffset out of range !%s',[LSN2Str(LSN)]);
    Exit;
  end;
  if (pbb.VLFHeadFlag <> $AB) or (pbb.SeqNo <> LSN.LSN_1) then
  begin
    Loger.Add('invalid lsn [3] VLFOffset Error !%s',[LSN2Str(LSN)]);
    Exit;
  end;
  Dispose(pbb); 
end;

function TSql2014LogReader.init(dbc: TdatabaseConnection): Boolean;
begin
  Fdbc := dbc;
  Result := True;
end;

procedure TSql2014LogReader.listLogBlock(vlfs:PVLF_Info);
var
  abuf:PlogBlock;
  posi:Integer;
begin
  // 每个块最大0xFFFF  最小0x0200
  new(abuf);
  posi := 200;
  while posi < vlfs.VLFOffset do
  begin
    FdataProvider.Seek(posi + vlfs.VLFOffset, soBeginning);
    if (FdataProvider.Read(abuf^, SizeOf(TlogBlock))=0) then
    begin
      Loger.Add('read data Error...........');
      Exit;
    end;
    if abuf.flag <> 0 then
    begin
      OutputDebugString(PChar(bytestostr(abuf, SizeOf(TlogBlock))));
      posi := posi + abuf.Size;
    end else begin
      posi := posi + 200;
    end;
  end;

  Dispose(abuf);
end;

procedure TSql2014LogReader.listVlfs;
var
  pbb: PVLFHeader;
  iiiii:integer;
  ssIze:Integer;
begin
iiiii:= 0;
  FdataProvider.Seek($2000, soBeginning);
  ssIze := SizeOf(TVLFHeader);
  New(pbb);
  repeat
    if (FdataProvider.Read(pbb^, ssIze)=0) then
    break;
    OutputDebugString(PChar(bytestostr(pbb, ssIze)));
    FdataProvider.Seek(pbb^.CurrentBlockSize-ssIze, soCurrent);

    iiiii := iiiii + 1;
    
  until (pbb^.CurrentBlockSize=0) or (iiiii>200);

  Dispose(pbb);
end;

end.

