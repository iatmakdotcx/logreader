unit Memory_Common;

interface
uses
  Windows, SysUtils, Classes, StrUtils;

function strToBytes(aStr: string): TBytes;
function bytestostr(var rd:array of Byte;OffsetBegin:DWORD = $FFFFFFFF;withAscii:Boolean = True;withLineBreak:Boolean = True):string;overload;
function bytestostr(P:Pointer;zlen:Integer;OffsetBegin:DWORD = $FFFFFFFF;withAscii:Boolean = True;withLineBreak:Boolean = True):string;overload;
function AlignToDword(TmpDWORD: DWORD): Pointer;overload;
function AlignToDword(Ptr: Pointer): Pointer;overload;
function Hex2HexStr(const data, Dest: Pointer;Len:integer):DWORD; stdcall;
function bytestostr_singleHex(var rd:array of Byte):string;
function hexToAnsiiData(aStr:string):string;
function DumpMemory2Str(data:Pointer; dataSize:Integer): string;

function ReadFile_OverLapped(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; Offset: TLargeInteger): BOOL;
function WriteFile_OverLapped(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; Offset: TLargeInteger;Sync:boolean = false): BOOL;

implementation


function ReadFile_OverLapped(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; Offset: TLargeInteger): BOOL;
var
  Flpap: TOverlapped;
begin
  ZeroMemory(@Flpap,SizeOf(TOverlapped));
  Flpap.Offset := Offset and $FFFFFFFF;
  Flpap.OffsetHigh := (Offset shr 32) and $FFFFFFFF;
  Result := ReadFile(hFile, Buffer, nNumberOfBytesToRead, lpNumberOfBytesRead, @Flpap);
  if not Result then
  begin
    if GetLastError = ERROR_IO_PENDING then
    begin
      Result := GetOverlappedResult(hFile, Flpap, lpNumberOfBytesRead, True);
    end;
    if (not Result) and (GetLastError = ERROR_HANDLE_EOF) then
    begin
      Result := True;
    end;
  end;
end;

function WriteFile_OverLapped(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; Offset: TLargeInteger;Sync:boolean = false): BOOL;
var
  Flpap: TOverlapped;
begin
  ZeroMemory(@Flpap,SizeOf(TOverlapped));
  Flpap.Offset := Offset and $FFFFFFFF;
  Flpap.OffsetHigh := (Offset shr 32) and $FFFFFFFF;
  Result := WriteFile(hFile, Buffer, nNumberOfBytesToRead, lpNumberOfBytesRead, @Flpap);
  if Sync and (not Result) then
  begin
    if GetLastError = ERROR_IO_PENDING then
    begin
      Result := GetOverlappedResult(hFile, Flpap, lpNumberOfBytesRead, True);
    end;
  end;
end;

function DumpMemory2Str(data:Pointer; dataSize:Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to dataSize-1 do
  begin
    Result := Result + IntToHex(Pbyte(UINT_PTR(data)+I)^,2);
  end;
end;

function bytestostr(var rd:array of Byte; OffsetBegin:DWORD = $FFFFFFFF;withAscii:Boolean = True;withLineBreak:Boolean = True):string;
var
  I: Integer;
  tmp:string;
  Asciitmp:string;
begin
  tmp := '';
  Asciitmp := '';
  if OffsetBegin<>$FFFFFFFF then
  begin
    tmp := Format('%.8X: ', [OffsetBegin]);
  end;
  for I := 0 to Length(rd) - 1 do begin
    tmp := tmp + IntToHex(RD[i],2) + ' ';
    if withAscii then
    begin
  //    if RD[i]=$FF then
  //    begin
  //      Asciitmp := Asciitmp + '.';
  //    end else
      if RD[i]>=$20 then
      begin
        Asciitmp := Asciitmp + Chr(RD[i]);
      end else
      begin
        Asciitmp := Asciitmp + '.';
      end;
    end;

    if ((i+1) mod $4) = 0 then begin
      tmp := tmp + ' ';
    end;

    if withLineBreak then
    begin
      if ((i+1) mod $10) = 0 then begin
        tmp := tmp + Asciitmp + #$20#13#10;
        if OffsetBegin<>$FFFFFFFF then
        begin
          OffsetBegin := OffsetBegin + $10;
          tmp := tmp + Format('%.8X: ', [OffsetBegin]);
        end;
        Asciitmp := '';
      end;
    end;
  end;
  for I := 0 to $10 - (Length(rd) mod $10) - 1 do
  begin
    tmp := tmp + '   ';
    if ((i+1) mod $4) = 0 then begin
      tmp := tmp + ' ';
    end;
  end;
  if withAscii then
  begin
    Result := tmp + Asciitmp;
  end
  else
  begin
    Result := tmp;
  end;
end;

function bytestostr_singleHex(var rd:array of Byte):string;
begin
  Result := DumpMemory2Str(@rd[0],Length(rd));
end;

function Hex2HexStr(const data, Dest: Pointer;Len:integer):DWORD; stdcall;
asm
{$if SizeOf(Pointer) = 4}
  pushad
  mov esi,data
  mov edi,dest
  xor ecx,ecx
  Xor edx,edx

  @loop:
  cmp ecx,len
  jae @Exit
    mov al,byte ptr[esi+ecx]
    shr al,4
    add al,$90
    DAA
    ADC AL,$40
    DAA
    
    mov byte ptr[edi+edx],al
    inc edx
    
    mov al,byte ptr[esi+ecx]
    and al,$F
    add al,$90
    DAA
    ADC AL,$40
    DAA

    mov byte ptr[edi+edx],al
    inc edx

    mov al,' '
    mov byte ptr[edi+edx],al
    inc edx

    inc ecx

    TEST ecx,$F
    jnz @InsertEol
      mov ax,$0A0D
      mov Word ptr[edi+edx],ax
      add edx,2
    @InsertEol:


  jmp @loop
  @Exit:
  mov len,edx
  popad
  mov eax,len
{$IFEND}
end;

function bytestostr(P:Pointer;zlen:Integer;OffsetBegin:DWORD = $FFFFFFFF;withAscii:Boolean = True;withLineBreak:Boolean = True):string;
var
  arr:array of Byte;
begin
  SetLength(arr, zlen);
  CopyMemory(@arr[0],P,zlen);
  result := bytestostr(arr, OffsetBegin, withAscii, withLineBreak);
end;

function AlignToDword(TmpDWORD: DWORD): Pointer;
begin
  if TmpDWORD and $3 > 0 then
    TmpDWORD := ((TmpDWORD shr 2) + 1) shl 2;
  Result := Pointer(TmpDWORD);
end;
function AlignToDword(Ptr: Pointer): Pointer;
begin
  Result := AlignToDword(uint_Ptr(Ptr));
end;

function strToBytes(aStr: string): TBytes;
var
  tmpByte: TBytes;
  tmpByteLen: Integer;
  Tmpstr: string;
  I: Integer;
  ichar:AnsiChar;
  TmpAnsiString:AnsiString;
begin
  tmpByteLen := 0;
  SetLength(tmpByte, 1024); //Max 1024
  i := 0;
  Tmpstr := '';
  TmpAnsiString := AnsiString(aStr);
  while i < Length(aStr) do
  begin
    i := i + 1;
    ichar := TmpAnsiString[i];
    if not (ichar in ['0'..'9', 'a'..'z', 'A'..'Z']) then
      Continue;

    Tmpstr := Tmpstr + string(ichar);
    if Length(Tmpstr) = 2 then
    begin
      tmpByte[tmpByteLen] := StrToInt('$' + Tmpstr);
      tmpByteLen := tmpByteLen + 1;
      Tmpstr := '';
    end;
  end;
  SetLength(Result, tmpByteLen);
  for I := 0 to tmpByteLen - 1 do
  begin
    Result[i] := tmpByte[i];
  end;
  SetLength(tmpByte, 0);
end;

function hexToAnsiiData(aStr:string):string;
var
  I: Integer;
  Tmpstr:string;
  ichar:AnsiChar;
begin
  if StartsText('0x',aStr) then
  begin
    Delete(aStr, 1, 2);
  end;
  i := 0;
  Tmpstr := '';
  Result := '';
  while i < Length(aStr) do
  begin
    i := i + 1;
    ichar := AnsiString(aStr)[i];
    if not (ichar in ['0'..'9', 'a'..'z', 'A'..'Z']) then
      Continue;

    Tmpstr := Tmpstr + string(ichar);
    if Length(Tmpstr) = 2 then
    begin
      Result:= Result + Char(StrToInt('$' + Tmpstr));
      Tmpstr := '';
    end;
  end;
end;

end.
