unit LocalDbLogProvider;

interface

uses
  I_LogProvider, Classes, Windows;

type
  TLocalDbLogProvider = class(TLogProvider)
  private
    Fposition: Int64;
    FfileHandle: THandle;
    Fsize: Int64;
    FBuffer: Pointer;
    FBufferStartOffsetOfFile: Integer;
    FBufferSize: Integer;
    Flpap: POverlapped;
    procedure refreshFileSize;
  public
    constructor Create;
    destructor Destroy; override;
    function init(fileHandle: THandle): Boolean;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function Read_Byte(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Word(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Dword(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Qword(var Buffer; posiOfBegin: Int64): Boolean; override;
    function Read_Bytes(var Buffer; posiOfBegin: Int64; Count: Longint): Integer; override;
    function getFileSize: Int64; override;
    procedure flush();override;
  end;

implementation

uses
  SysUtils, MakCommonfuncs, loglog;

constructor TLocalDbLogProvider.Create;
begin
  inherited;
  FfileHandle := 0;
  Fposition := 0;
  Fsize := 0;
  fBufferStartOffsetOfFile := 0;
  fBufferSize := 0;
  fBuffer := nil;

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
  if fBuffer <> nil then
  begin
    FreeMem(fBuffer);
  end;
  Dispose(Flpap);
  inherited;
end;

procedure TLocalDbLogProvider.flush;
begin
  fBufferStartOffsetOfFile := -1;
  fBufferSize := 0;
end;

function TLocalDbLogProvider.getFileSize: Int64;
begin
  Result := Fsize;
end;

function TLocalDbLogProvider.init(fileHandle: THandle): Boolean;
begin
  Result := False;
  if (fileHandle = 0) or (fileHandle = INVALID_HANDLE_VALUE) then
  begin
    Exit;
  end;
  FfileHandle := fileHandle;
  refreshFileSize;
  Result := Fsize > 0;
end;

function TLocalDbLogProvider.Read(var Buffer; Count: Integer): Longint;
var
  readRes: BOOL;
begin
  if (Count > 0) and (FfileHandle > 0) then
  begin
    if fBuffer = nil then
    begin
      GetMem(fBuffer, $10000);
      fBufferStartOffsetOfFile := -1;
      fBufferSize := 0;
    end;
    if Fposition > Fsize then
    begin
      refreshFileSize;
      if Fposition > Fsize then
      begin
        Result := 0;
        Exit;
      end;
    end;
    if Fposition + Count > Fsize then
    begin
      Count := Fsize - Fposition;
    end;
    if (Count < 1) or (Fposition < 0) then
    begin
      Result := 0;
      Exit;
    end;

    if (Fposition > fBufferStartOffsetOfFile) and (Fposition + Count < fBufferStartOffsetOfFile + fBufferSize) then
    begin
      //in range
      Result := Count;
    end
    else
    begin
      //not in range
      Flpap.Offset := Fposition and $FFFFFFFF;
      Flpap.OffsetHigh := (Fposition shr 32) and $FFFFFFFF;
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
        if GetLastError = $3E5 then
        begin
          readRes := GetOverlappedResult(FfileHandle, Flpap^, LongWord(Result), True);
        end;
      end;

      if not readRes then
      begin
        Result := 0;
        Loger.Add('read log File fail:' + SysErrorMessage(GetLastError));
        Exit;
      end
      else if Count > $10000 then
      begin
        Count := 0;
      end
      else
      begin
        fBufferStartOffsetOfFile := Fposition;
        fBufferSize := Result;

        if Count > Result then
        begin
          Count := Result;
        end else begin
          Result := Count;
        end;
      end;
    end;
    Move(Pointer(UIntPtr(fBuffer) + (Fposition - fBufferStartOffsetOfFile))^, Buffer, Count);
    Fposition := Fposition + Count;
  end
  else if FfileHandle < 1 then
  begin
    Loger.Add('TLocalDbLogProvider not init.');
  end;
end;

function TLocalDbLogProvider.Read_Bytes(var Buffer; posiOfBegin: Int64; Count: Integer): Integer;
begin
  Fposition := posiOfBegin;
  Result := Read(Buffer, Count);
end;

function TLocalDbLogProvider.Read_Byte(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Fposition := posiOfBegin;
  Result := Read(Buffer, 1) <> 0;
end;

function TLocalDbLogProvider.Read_Word(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Fposition := posiOfBegin;
  Result := Read(Buffer, 2) <> 0;
end;

function TLocalDbLogProvider.Read_Dword(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Fposition := posiOfBegin;
  Result := Read(Buffer, 4) <> 0;
end;

function TLocalDbLogProvider.Read_Qword(var Buffer; posiOfBegin: Int64): Boolean;
begin
  Fposition := posiOfBegin;
  Result := Read(Buffer, 8) <> 0;
end;

procedure TLocalDbLogProvider.refreshFileSize;
var
  hSize: LARGE_INTEGER;
begin
  if not GetFileSizeEx(FfileHandle, hSize) then
  begin
    Fsize := -1;
  end
  else
  begin
    Fsize := hSize.QuadPart;
  end;
end;

function TLocalDbLogProvider.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      Fposition := Offset;
    soCurrent:
      Fposition := Fposition + Offset;
    soEnd:
      Fposition := Fsize - Offset;
  end;
  Result := Fposition;
end;

end.

