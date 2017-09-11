unit hexValUtils;

interface

uses
  dbDict, System.SysUtils, Winapi.Windows, p_structDefine;

function Hvu_Hex2Datetime(msec: Int64): TDateTime;

function Hvu_GetFieldStrValue(Field: TdbFieldItem; Value: TBytes): string;

function getShort(Value: TBytes; idx: Integer; len: Integer = 2): word;

function getInt(Value: TBytes; idx: Integer; len: Integer = 4): DWORD;

function getInt64(Value: TBytes; idx: Integer; len: Integer = 8): QWORD;

implementation

uses
  DateUtils, dbFieldTypes, System.Math, Memory_Common;

function Hvu_Hex2Datetime(msec: Int64): TDateTime;
var
  ldate: Cardinal;
begin
  Result := EncodeDateTime(1900, 1, 1, 0, 0, 0, 0);
  Result := Result + msec shr 32;
  ldate := msec and $FFFFFFFF;
  Result := IncSecond(Result, ldate div 300);
  Result := IncMilliSecond(Result, (ldate mod 300) * 1000 div 300);
end;

function getShort(Value: TBytes; idx, len: Integer): Word;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 2);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or (Value[I] shl (I - idx) * 8);
  end;
end;

function getInt(Value: TBytes; idx, len: Integer): DWORD;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 4);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or (Value[I] shl (I - idx) * 8);
  end;
end;

function getInt64(Value: TBytes; idx, len: Integer): QWORD;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 8);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or (Value[I] shl (I - idx) * 8);
  end;
end;

function Hvu_Bytes2DateStr(Value: TBytes): string;
var
  dayCnt: Integer;
  TmpDate: TDate;
begin
  dayCnt := getInt(Value, 0, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
end;

function Hvu_Bytes2TimeStr(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
begin
  MisCnt := getInt64(Value, 0, 5);
  scaleCardinal := Trunc(Power(10, scale));
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal])
end;

function Hvu_Bytes2DateTimeStr(Value: TBytes): string;
var
  tmpLong: QWORD;
begin
  tmpLong := getInt64(Value, 0);
  Result := FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Hvu_Hex2Datetime(tmpLong));
end;

function Hvu_Bytes2DateTime2Str(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  dayCnt: Integer;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
  TmpDate: TDate;
begin
  //Ìì”µ
  dayCnt := getInt(Value, 5, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
  //Ãë”µ
  MisCnt := getInt64(Value, 0, 5);
  scaleCardinal := Trunc(Power(10, scale));
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Result + ' ' + Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal]);
end;

function Hvu_Bytes2DateTimeOffsetStr(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  dayCnt: Integer;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
  TmpDate: TDate;
  fixVal: Integer;
  TimeZoneStr: string;
begin
  fixVal := getShort(Value, 8);
  if fixVal < 0 then
  begin
    TimeZoneStr := Format('-%d:%d', [abs(fixVal) div 60, abs(fixVal) mod 60]);
  end
  else
  begin
    TimeZoneStr := Format('+%d:%d', [abs(fixVal) div 60, abs(fixVal) mod 60]);
  end;
  //Ìì”µ
  dayCnt := getInt(Value, 5, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
  //Ãë”µ
  MisCnt := getInt64(Value, 0, 5);
  scaleCardinal := Trunc(Power(10, scale));
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Result + ' ' + Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal]) + ' ' + TimeZoneStr;
end;

function Hvu_Bytes2smallDatetimeStr(Value: TBytes): string;
var
  ldate, hdate: Integer;
  TmpDate: TDateTime;
begin
  ldate := getShort(Value, 0, 2);
  hdate := getShort(Value, 2, 2);
  TmpDate := EncodeDateTime(1900, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + hdate;
  TmpDate := IncMinute(TmpDate, ldate);
  Result := FormatDateTime('yyyy-MM-dd HH:nn:ss', TmpDate);
end;

function Hvu_Bytes2SingleStr(Value: TBytes): string;
var
  tmpSingle: Single;
begin
  PDWORD(@tmpSingle)^ := getInt(Value, 0);
  Result := FloatToStr(tmpSingle);
end;

function Hvu_Bytes2DoubleStr(Value: TBytes): string;
var
  tmpSingle: Double;
begin
  PQWORD(@tmpSingle)^ := getInt64(Value, 0);
  Result := FloatToStr(tmpSingle);
end;

function Hvu_Bytes2Float(Value: TBytes; scale: Integer): string;
var
  tmplong: Integer;
  TmPdouble: Double;
begin
  tmplong := getInt64(Value, 1);
  TmPdouble := tmplong / Power(10, scale);
  if (Value[0] <> 1) then
  begin
    TmPdouble := -TmPdouble;
  end;
  Result := FloatToStr(TmPdouble);
end;

function Hvu_Bytes2Momey(Value: TBytes; scale: Integer): string;
var
  tmplong: Integer;
  TmPdouble: Double;
begin
  if Length(Value) = 4 then
  begin
    // smallMoney
    tmplong := getInt(Value, 0);
  end
  else
  begin
    //Money
    tmplong := getInt64(Value, 0);
  end;
  TmPdouble := tmplong / Power(10, scale);
  Result := FloatToStr(TmPdouble);
end;

function Hvu_Bytes2AnsiBytesStr(Value: TBytes; CodePage: Integer): string;
var
  needSize: Integer;
begin
  needSize := MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@Value[0]), -1, nil, 0);
  if needSize > 0 then
  begin
    SetLength(Result, needSize);
    MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@Value[0]), -1, PWideChar(@Result[1]), needSize);
  end;
end;

function Hvu_GetFieldStrValue(Field: TdbFieldItem; Value: TBytes): string;
begin
  if Value = nil then
  begin
    Result := 'NULL';
    exit;
  end;
  if Length(Value) = 0 then
  begin
    Result := '''''';
    exit;
  end;

  case Field.type_id of
    MsTypes.DATE:
      Result := Hvu_Bytes2DateStr(Value);
    MsTypes.TIME:
      Result := Hvu_Bytes2TimeStr(Value, Field.scale);
    MsTypes.DATETIME2:
      Result := Hvu_Bytes2DateTime2Str(Value, Field.scale);
    MsTypes.DATETIMEOFFSET:
      Result := Hvu_Bytes2DateTimeOffsetStr(Value, Field.scale);
    MsTypes.TINYINT:
      Result := IntToStr(Value[0]);
    MsTypes.SMALLINT:
      Result := IntToStr(getShort(Value, 0));
    MsTypes.INT:
      Result := IntToStr(getInt(Value, 0));
    MsTypes.BIGINT:
      Result := IntToStr(getInt64(Value, 0));
    MsTypes.SMALLDATETIME:
      Result := Hvu_Bytes2smallDatetimeStr(Value);
    MsTypes.REAL:
      Result := Hvu_Bytes2SingleStr(Value);
    MsTypes.FLOAT:
      Result := Hvu_Bytes2DoubleStr(Value);
    MsTypes.NUMERIC, MsTypes.DECIMAL:
      Result := Hvu_Bytes2Float(Value, Field.scale);
    MsTypes.MONEY, MsTypes.SMALLMONEY:
      Result := Hvu_Bytes2Momey(Value, Field.scale);
    MsTypes.DATETIME:
      Result := Hvu_Bytes2DateTimeStr(Value);
    MsTypes.SQL_VARIANT:
      ;
    MsTypes.TEXT, MsTypes.CHAR, MsTypes.VARCHAR:
      Result := Hvu_Bytes2AnsiBytesStr(Value, Field.CodePage);
    MsTypes.NTEXT, MsTypes.NVARCHAR, MsTypes.NCHAR:
      begin
        Result := PWideChar(Value);
        Result := Copy(Result, Length(Value) div 2);
      end;
    MsTypes.BIT:
      if Value[0] = 1 then
        Result := '1'
      else
        Result := '0';
    MsTypes.XML, MsTypes.IMAGE, MsTypes.VARBINARY, MsTypes.BINARY:
      Result := bytestostr(Value, $FFFFFFFF, False, False);
    MsTypes.UNIQUEIDENTIFIER:
      ;
    MsTypes.GEOGRAPHY:
      ;
    MsTypes.TIMESTAMP:
      ;
  end;

end;

end.

