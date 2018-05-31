unit blockReader;

interface

uses
  System.Types;

type
  TblockReader = class(Tobject)
  private
    _FileHandle: THandle;
    _buf: Pointer;
    basepnt: Cardinal;
    RealPnt: Cardinal;
    Posi: Cardinal;
    nSize: Cardinal;
  public
    constructor Create(IdxFileHandle: THandle);
    destructor Destroy; override;
    procedure init(Offset: Cardinal);
    procedure reflush;
    function available: Cardinal;
    function CurrRealOffset: Cardinal;
    function Read_1: Byte;
    function Read_2: Word;
    function Read_4: DWord;
    function Read_8: UInt64;
    function Read_n(n: Cardinal; OutBuf: Pointer): Boolean;
    procedure skip(sCnt: Cardinal);
  end;

implementation

uses
  Winapi.Windows, System.Classes;



{ TblockReader }

constructor TblockReader.Create(IdxFileHandle: THandle);
begin
  _FileHandle := IdxFileHandle;
  _buf := AllocMem($2000);
  basepnt := 0;
  RealPnt := 0;
  nsize := 0;
  posi := 0;
end;

function TblockReader.CurrRealOffset: Cardinal;
begin
  Result := RealPnt + posi;
end;

destructor TblockReader.Destroy;
begin
  FreeMem(_buf);
  inherited;
end;

procedure TblockReader.init(Offset: Cardinal);
begin
  basepnt := Offset;
  RealPnt := basepnt;
  posi := 0;

  reflush;
end;

procedure TblockReader.reflush;
begin
  RealPnt := RealPnt + posi;
  SetFilePointer(_FileHandle, RealPnt, nil, soFromBeginning);
  ReadFile(_FileHandle, _buf^, $2000, nsize, nil);
  posi := 0;
end;

function TblockReader.available: Cardinal;
begin
  Result := nsize - posi;
end;

procedure TblockReader.skip(sCnt: Cardinal);
begin
  posi := posi + sCnt;
end;

function TblockReader.Read_1: Byte;
begin
  if available < 1 then
    reflush;

  if available >= 1 then
  begin
    Result := Pbyte(Uint_ptr(_buf) + posi)^;
    posi := posi + 1;
  end
  else
    Result := 0;
end;

function TblockReader.Read_2: Word;
begin
  if available < 2 then
    reflush;
  if available >= 2 then
  begin
    Result := PWord(Uint_ptr(_buf) + posi)^;
    posi := posi + 2;
  end
  else
    Result := 0;
end;

function TblockReader.Read_4: DWord;
begin
  if available < 4 then
    reflush;
  if available >= 4 then
  begin
    Result := PDword(Uint_ptr(_buf) + posi)^;
    posi := posi + 4;
  end
  else
    Result := 0;
end;

function TblockReader.Read_8: UInt64;
begin
  if available < 8 then
    reflush;
  if available >= 8 then
  begin
    Result := Puint64(Uint_ptr(_buf) + posi)^;
    posi := posi + 8;
  end
  else
    Result := 0;
end;

function TblockReader.Read_n(n: Cardinal; OutBuf: Pointer): Boolean;
begin
  if available < n then
    reflush;

  if available >= n then
  begin
    Move(Pointer(Uint_ptr(_buf) + posi)^, OutBuf^, n);
    posi := posi + n;
    Result := True;
  end
  else
    Result := False;
end;

end.

