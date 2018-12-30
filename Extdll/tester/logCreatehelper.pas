unit logCreatehelper;

interface

uses
  Winapi.Windows;

type
  TLSN = packed record
    lsn_1: DWORD;
    lsn_2: DWORD;
    lsn_3: WORD;
  end;

  PlogRecdItem = ^TlogRecdItem;

  TlogRecdItem = packed record
    n: PlogRecdItem;
    TranID_1: DWORD;
    TranID_2: WORD;
    lsn: TLSN;
    length: DWORD;
    dbId: Word;
    val: Pointer;
  end;


var
  ____PaddingData: Pointer = nil;
  function Str2LSN(lsnStr:string): TLSN;

implementation
uses
  System.SysUtils;


function Str2LSN(lsnStr:string): TLSN;
var
  s1,s2,s3:string;
  i1,i2,i3:Integer;
begin
  if lsnStr.StartsWith('0x') then
  begin
    Delete(lsnStr,1,2);
  end;
  s1 := lsnStr.Substring(0,8);
  s2 := lsnStr.Substring(9,8);
  s3 := lsnStr.Substring(18,4);
  if TryStrToInt('$'+s1, i1) and TryStrToInt('$'+s2, i2) and TryStrToInt('$'+s3, i3) then
  begin
    Result.LSN_1 := i1;
    Result.LSN_2 := i2;
    Result.LSN_3 := i3;
  end
  else
  begin
    Result.LSN_1 := 0;
    Result.LSN_2 := 0;
    Result.LSN_3 := 0;
  end;
end;

end.
