unit LdfLogProvider;

interface

uses
  I_LogProvider, Classes;

type
  TLdfLogProvider = class(TLogProvider)
  private
    Fposition:Int64;
    Fsize:Int64;
    fileHandle: THandle;
    fBuffer:Pointer;
    fBufferStartOffsetOfFile:Integer;
    fBufferSize:Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function init(fileName: string): Boolean;
    function Read(var Buffer; Count: Longint): Longint;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
  end;

implementation

uses
  Windows, SysUtils;

{ TLdfLogProvider }

constructor TLdfLogProvider.Create;
begin
  inherited;
  fileHandle := 0;
  Fposition := 0;
  Fsize := 0;
  fBufferStartOffsetOfFile := 0;
  fBufferSize := 0;
  fBuffer := nil;
end;

destructor TLdfLogProvider.Destroy;
begin
  if fileHandle>0 then
  begin
    CloseHandle(fileHandle)
  end;
  if fBuffer<>nil then
  begin
    FreeMem(fBuffer);
  end;

  inherited;
end;

function TLdfLogProvider.init(fileName: string): Boolean;
var
  hSize:Cardinal;
begin
  fileHandle := CreateFile(PChar(fileName), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if fileHandle = INVALID_HANDLE_VALUE then
  begin
    Result := False;
    raise exception.Create('³¢ÊÔ´ò¿ª%sÊ§°Ü£¡' + #$D#$A + SysErrorMessage(getlastError));
  end;
  Fsize := GetFileSize(fileHandle, @hSize);
  Fsize := Fsize or (hSize shl 32);
  Result := True;
end;

function TLdfLogProvider.Read(var Buffer; Count: Integer): Longint;
var
  setpt_L,setpt_H:Cardinal;
begin
  if (Count > 0) and (fileHandle > 0) then
  begin
    if fBuffer = nil then
    begin
      GetMem(fBuffer, $10000);
      fBufferStartOffsetOfFile := -1;
      fBufferSize := 0;
    end;
    if Fposition + Count > Fsize then
    begin
      Count := Fsize - Fposition;
    end;
    if (Count < 1 ) or (Fposition > Fsize) or (Fposition < 0) then
    begin
      Result := 0;
      Exit;
    end;

    if (Fposition > fBufferStartOffsetOfFile) and
       (Fposition + Count < fBufferStartOffsetOfFile + fBufferSize) then
    begin
      //in range

    end else begin
      //not in range
      setpt_L := Fposition and $FFFFFFFF;
      setpt_H := (Fposition shr 32) and $FFFFFFFF;
      SetFilePointer(fileHandle, setpt_L, @setpt_H, soFromBeginning);
      if not ReadFile(fileHandle, fBuffer^, $10000, LongWord(Result), nil) then
      begin
        Result := 0;
        Exit;
      end else begin
        fBufferStartOffsetOfFile := Fposition;
        fBufferSize := Result;

        if Count > Result then
        begin
          Count := Result;
        end;
      end;
    end;
    Move(Pointer(Cardinal(fBuffer) + (fBufferStartOffsetOfFile - Fposition))^, Buffer, Count);
    Fposition := Fposition + Count;
  end;
end;

function TLdfLogProvider.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: Fposition := Offset;
    soCurrent: Fposition := Fposition + Offset;
    soEnd: Fposition := Fsize - Offset;
  end;
  Result := Fposition;
end;

end.

