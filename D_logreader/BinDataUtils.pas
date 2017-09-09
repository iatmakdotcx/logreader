unit BinDataUtils;

interface

uses
  System.Classes, p_structDefine, Winapi.Windows, System.SysUtils;

type
  SeekOrigin = (soBeginning, soCurrent, soEnd);

type
  TbinDataReader = class(TObject)
  private
//    FBufBase: Pointer;
    FBufBase: Pointer;
    FBufSize: Cardinal;
    FRangeL: Cardinal;  //·¶Î§¿ªÊ¼
    FRangeH: Cardinal;  //·¶Î§½áÊø
    FPosition: Cardinal;
  public
    constructor Create(mm: TMemory_data);
    destructor Destroy; override;
    procedure alignTo4;
    function seek(Offset: Integer; so: SeekOrigin): Cardinal;
    procedure SetRange(Offset: Cardinal; Length: Cardinal);
    procedure skip(Offset: Integer);
    function readByte: Byte;
    function readWord: Word;
    function readDWORD: DWORD;
    function readQWORD: QWORD;
    function readSInt: ShortInt;
    function readShort: SHORT;
    function readInt: Integer;
    function readInt64: Int64;
    function readBytes(aLen: Cardinal): TBytes;
    property Position: Cardinal read FPosition;
  end;

implementation

{ TbinDataReader }

constructor TbinDataReader.Create(mm: TMemory_data);
begin
  FBufBase := mm.data;
  FBufSize := mm.dataSize;
  //Ä¬ÈÏ¶ÁÈ¡·¶Î§ÊÇÄ©Î²
  FRangeL := 0;
  FRangeH := FBufSize;
end;

destructor TbinDataReader.Destroy;
begin

  inherited;
end;

procedure TbinDataReader.alignTo4;
begin
  FPosition := (FPosition + 3) and $FFFFFFFC;
end;

function TbinDataReader.seek(Offset: Integer; so: SeekOrigin): Cardinal;
begin
  case so of
    soBeginning:
      FPosition := integer(FRangeL) + Offset;
    soCurrent:
      FPosition := Integer(FPosition) + Offset;
    soEnd:
      FPosition := Integer(FRangeH) + Offset;
  end;
  if FPosition > FRangeH then
    FPosition := FRangeH;
  if FPosition < FRangeL then
    FPosition := FRangeL;

  Result := FPosition;
end;

procedure TbinDataReader.SetRange(Offset, Length: Cardinal);
begin
  FRangeL := Offset;
  FRangeH := Offset + Length;
  FPosition := Offset;
end;

procedure TbinDataReader.skip(Offset: Integer);
begin
  seek(Offset, soCurrent);
end;

function TbinDataReader.readByte: Byte;
begin
  if FPosition < FRangeH then
  begin
    Result := Pbyte(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 1;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readSInt: ShortInt;
begin
  if FPosition < FRangeH then
  begin
    Result := PShortInt(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 1;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readDWORD: DWORD;
begin
  if FPosition + 3 < FRangeH then
  begin
    Result := PDword(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 4;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readInt: Integer;
begin
  if FPosition + 3 < FRangeH then
  begin
    Result := Pinteger(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 4;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readInt64: Int64;
begin
  if FPosition + 7 < FRangeH then
  begin
    Result := PInt64(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 8;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readQWORD: QWORD;
begin
  if FPosition + 7 < FRangeH then
  begin
    Result := PQword(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 8;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readShort: SHORT;
begin
  if FPosition + 1 < FRangeH then
  begin
    Result := Pshort(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 2;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readWord: Word;
begin
  if FPosition + 1 < FRangeH then
  begin
    Result := PWord(Cardinal(FBufBase) + FPosition)^;
    FPosition := FPosition + 2;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

function TbinDataReader.readBytes(aLen: Cardinal): TBytes;
begin
  if FPosition + aLen - 1 < FRangeH then
  begin
    SetLength(Result, aLen);
    Move(Pointer(Cardinal(FBufBase) + FPosition)^, Result[0], aLen);
    FPosition := FPosition + aLen;
  end
  else
  begin
    raise Exception.Create('EOF');
  end;
end;

end.

