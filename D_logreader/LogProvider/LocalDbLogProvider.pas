unit LocalDbLogProvider;

interface

uses
  I_LogProvider, Classes, Windows;

type
  TLocalDbLogProvider = class(TLogProvider)
  private
    FfileHandle: THandle;
    FBuffer: Pointer;
    FBufferStartOffsetOfFile: Integer;
    FBufferSize: Integer;
    Flpap: POverlapped;
  public
    constructor Create;
    destructor Destroy; override;
    function init(fileHandle: THandle): Boolean;override;
    function Read(var Buffer; posiOfBegin: Int64; Count: Longint): Integer; override;
    function Read_Byte(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Word(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Dword(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Qword(var Buffer; posiOfBegin: Int64): Boolean; override;
    procedure flush;override;
  end;

implementation

uses
  SysUtils, MakCommonfuncs, loglog;

constructor TLocalDbLogProvider.Create;
begin
  inherited;
  FfileHandle := 0;
  fBufferStartOffsetOfFile := 0;
  fBufferSize := 0;
  GetMem(fBuffer, $10000);

  New(Flpap);
  Flpap.Internal := 0;
  Flpap.InternalHigh := 0;
  Flpap.Offset := 0;
  Flpap.OffsetHigh := 0;
  Flpap.hEvent := CreateEvent(nil, False, False, nil);

end;

destructor TLocalDbLogProvider.Destroy;
begin
  if FfileHandle > 0 then
  begin
    CloseHandle(FfileHandle)
  end;
  FreeMem(fBuffer);
  Dispose(Flpap);
  inherited;
end;

procedure TLocalDbLogProvider.flush;
begin
  fBufferStartOffsetOfFile := -1;
  fBufferSize := 0;
end;

function TLocalDbLogProvider.init(fileHandle: THandle): Boolean;
var
  hSize: LARGE_INTEGER;
begin
  Result := False;
  if (fileHandle = 0) or (fileHandle = INVALID_HANDLE_VALUE) then
  begin
    Exit;
  end;
  FfileHandle := fileHandle;
  Result := GetFileSizeEx(FfileHandle, hSize);
end;

function TLocalDbLogProvider.Read(var Buffer; posiOfBegin: Int64; Count: Integer): Integer;
var
  readRes: BOOL;
begin
  if (Count > 0) and (FfileHandle > 0) then
  begin
    if (posiOfBegin >= fBufferStartOffsetOfFile) and (posiOfBegin + Count < fBufferStartOffsetOfFile + fBufferSize) then
    begin
      //in range
      Result := Count;
      Move(Pointer(UIntPtr(fBuffer) + (posiOfBegin - fBufferStartOffsetOfFile))^, Buffer, Count);
    end
    else
    begin
      //not in range
      Flpap.Internal := 0;
      Flpap.InternalHigh := 0;
      Flpap.Offset := posiOfBegin and $FFFFFFFF;
      Flpap.OffsetHigh := (posiOfBegin shr 32) and $FFFFFFFF;
      if Count > $10000 then
      begin
        //´óÓÚ»º³åÇø
        readRes := ReadFile(FfileHandle, Buffer, Count, LongWord(Result), Flpap);
      end
      else
      begin
        readRes := ReadFile(FfileHandle, fBuffer^, $10000, LongWord(Result), Flpap);
      end;
      if not readRes then
      begin
        if GetLastError = ERROR_IO_PENDING then
        begin
          readRes := GetOverlappedResult(FfileHandle, Flpap^, LongWord(Result), True);
        end;
      end;

      if not readRes then
      begin
        Result := 0;
        Exit;
      end
      else if Count <= $10000 then
      begin
        fBufferStartOffsetOfFile := posiOfBegin;
        fBufferSize := Result;

        Move(Pointer(UIntPtr(fBuffer) + (posiOfBegin - fBufferStartOffsetOfFile))^, Buffer, Count);
      end;
    end;
  end
  else if FfileHandle < 1 then
  begin
    Result := 0;
  end;
end;

function TLocalDbLogProvider.Read_Byte(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Result := Read(Buffer,posiOfBegin, 1) <> 0;
end;

function TLocalDbLogProvider.Read_Word(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Result := Read(Buffer,posiOfBegin, 2) <> 0;
end;

function TLocalDbLogProvider.Read_Dword(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Result := Read(Buffer,posiOfBegin, 4) <> 0;
end;

function TLocalDbLogProvider.Read_Qword(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Result := Read(Buffer,posiOfBegin, 8) <> 0;
end;



end.

