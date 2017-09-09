unit hexValUtils;

interface

function Hvu_Hex2Datetime(msec:Int64):TDateTime;

implementation
uses
  DateUtils;

function Hvu_Hex2Datetime(msec:Int64):TDateTime;
var
  ldate:Cardinal;
begin
  Result := EncodeDateTime(1900,1,1,0,0,0,0);
  Result := Result + msec shr 32;
  ldate := msec and $FFFFFFFF;
  Result:= IncSecond(Result,ldate div 300);
  Result:= IncMilliSecond(Result,(ldate mod 300)*1000 div 300);
end;

end.
