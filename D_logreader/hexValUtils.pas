unit hexValUtils;

interface

uses
  dbDict, System.SysUtils, Winapi.Windows, p_structDefine, I_LogSource;

type
  THexValueHelper = class
  private
    LogSource:TLogSourceBase;
    class function Bytes2AnsiBytesStr(Value: TBytes; CodePage: Integer): string; static;
    class function Bytes2DateStr(Value: TBytes): string; static;
    class function Bytes2DateTime2Str(Value: TBytes; scale: Integer): string; static;
    class function Bytes2DateTimeOffsetStr(Value: TBytes; scale: Integer): string; static;
    class function Bytes2DateTimeStr(Value: TBytes): string; static;
    class function Bytes2DoubleStr(Value: TBytes): string; static;
    class function Bytes2Float(Value: TBytes; scale: Integer): string; static;
    class function Bytes2GUIDStr(Value: TBytes): string; static;
    class function Bytes2Momey(Value: TBytes; scale: Integer): string; static;
    class function Bytes2SingleStr(Value: TBytes): string; static;
    class function Bytes2smallDatetimeStr(Value: TBytes): string; static;
    class function Bytes2TimeStr(Value: TBytes; scale: Integer): string; static;
  public
    constructor Create(_LogSource:TLogSourceBase);
    function GetFieldStrValue(Field: TdbFieldItem; Value: TBytes): string; overload;
    function GetFieldStrValue(Field: TdbFieldItem; Value: TBytes; out needQuote: Boolean): string; overload;
    function GetFieldStrValueWithQuoteIfNeed(Field: TdbFieldItem; Value: TBytes): string;
    class function Hex2Datetime(msec: Int64): TDateTime;
    class function getWord(Value: TBytes; idx: Integer; len: Integer = 2): Word;
    class function getDWORD(Value: TBytes; idx: Integer; len: Integer = 4): DWORD;
    class function getQWORD(Value: TBytes; idx: Integer; len: Integer = 8): QWORD;
    class function getShort(Value: TBytes; idx: Integer; len: Integer = 2): SHORT;
    class function getInt(Value: TBytes; idx: Integer; len: Integer = 4): Integer;
    class function getInt64(Value: TBytes; idx: Integer; len: Integer = 8): Int64;
  end;

implementation

uses
  DateUtils, dbFieldTypes, System.Math, Memory_Common, loglog;

class function THexValueHelper.Hex2Datetime(msec: Int64): TDateTime;
var
  ldate: Cardinal;
begin
  Result := EncodeDateTime(1900, 1, 1, 0, 0, 0, 0);
  Result := Result + msec shr 32;
  ldate := msec and $FFFFFFFF;
  Result := IncSecond(Result, ldate div 300);
  Result := IncMilliSecond(Result, (ldate mod 300) * 1000 div 300);
end;

class function THexValueHelper.getWord(Value: TBytes; idx, len: Integer): Word;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 2);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or (Value[I] shl ((I - idx) * 8));
  end;
end;

class function THexValueHelper.getDWORD(Value: TBytes; idx, len: Integer): DWORD;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 4);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or (Value[I] shl ((I - idx) * 8));
  end;
end;

class function THexValueHelper.getQWORD(Value: TBytes; idx, len: Integer): QWORD;
var
  I: Integer;
  NeedReadByteCnt: Integer;
begin
  Result := 0;
  NeedReadByteCnt := Min(Min(Length(Value), idx + len), idx + 8);
  for I := idx to NeedReadByteCnt - 1 do
  begin
    Result := Result or Qword(Qword(Value[I]) shl Qword((I - idx) * 8));
  end;
end;

class function THexValueHelper.getShort(Value: TBytes; idx: Integer; len: Integer = 2): SHORT;
begin
  if Length(Value) < idx+2 then
  begin
    Result := Value[idx];
  end else begin
    Result := PSHORT(@Value[idx])^;
  end;
end;

class function THexValueHelper.getInt(Value: TBytes; idx: Integer; len: Integer = 4): Integer;
begin
  if Length(Value) < idx+4 then
  begin
    Result := getDWORD(Value, idx, len);
  end else begin
    Result := PINT(@Value[idx])^;
  end;
end;

class function THexValueHelper.getInt64(Value: TBytes; idx: Integer; len: Integer = 8): Int64;
begin
  if Length(Value) < idx+4 then
  begin
    Result := getQWORD(Value, idx, len);
  end else begin
    Result := PINT64(@Value[idx])^;
  end;
end;

class function THexValueHelper.Bytes2DateStr(Value: TBytes): string;
var
  dayCnt: Integer;
  TmpDate: TDate;
begin
  dayCnt := getDWORD(Value, 0, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
end;

class function THexValueHelper.Bytes2TimeStr(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
begin
  MisCnt := getQWORD(Value, 0, 5);
  scaleCardinal := Trunc(Power(10, scale));
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal])
end;

constructor THexValueHelper.Create(_LogSource: TLogSourceBase);
begin
  LogSource := _LogSource;
end;

class function THexValueHelper.Bytes2DateTimeStr(Value: TBytes): string;
var
  tmpLong: QWORD;
begin
  tmpLong := getQWORD(Value, 0);
  Result := FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Hex2Datetime(tmpLong));
end;

class function THexValueHelper.Bytes2DateTime2Str(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  dayCnt: Integer;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
  TmpDate: TDate;
begin
  //�씵
  dayCnt := getDWORD(Value, 5, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
  //�딵
  MisCnt := getQWORD(Value, 0, 5);
  scaleCardinal := Trunc(Power(10, scale));
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Result + ' ' + Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal]);
end;

class function THexValueHelper.Bytes2DateTimeOffsetStr(Value: TBytes; scale: Integer): string;
var
  MisCnt: Int64;
  dayCnt: Integer;
  seconds, minutes, hours: Integer;
  scaleCardinal: Integer;
  TotalSrcond: Cardinal;
  TmpDate: TDate;
  fixVal: Integer;
  TimeZoneStr: string;
  zoneHours, zonMinutes: integer;
begin
  fixVal := getWord(Value, 8);
  zoneHours := abs(fixVal) div 60;
  zonMinutes := abs(fixVal) mod 60;
  if fixVal < 0 then
  begin
    TimeZoneStr := Format('-%.2d:%.2d', [zoneHours, zonMinutes]);
  end
  else
  begin
    TimeZoneStr := Format('+%.2d:%.2d', [zoneHours, zonMinutes]);
  end;
  //�씵
  dayCnt := getDWORD(Value, 5, 3);
  TmpDate := EncodeDateTime(0001, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + dayCnt;
  Result := FormatDateTime('yyyy-MM-dd', TmpDate);
  //�딵
  scaleCardinal := Trunc(Power(10, scale));
  MisCnt := getQWORD(Value, 0, 5) + int64(fixVal) * scaleCardinal * 60;
  TotalSrcond := MisCnt div scaleCardinal;
  seconds := TotalSrcond mod 60;
  minutes := (TotalSrcond div 60) mod 60;
  hours := TotalSrcond div 3600;
  scaleCardinal := MisCnt mod scaleCardinal;
  Result := Result + ' ' + Format('%d:%d:%d.%d', [hours, minutes, seconds, scaleCardinal]) + ' ' + TimeZoneStr;
end;

class function THexValueHelper.Bytes2smallDatetimeStr(Value: TBytes): string;
var
  ldate, hdate: Integer;
  TmpDate: TDateTime;
begin
  ldate := getWord(Value, 0, 2);
  hdate := getWord(Value, 2, 2);
  TmpDate := EncodeDateTime(1900, 1, 1, 0, 0, 0, 0);
  TmpDate := TmpDate + hdate;
  TmpDate := IncMinute(TmpDate, ldate);
  Result := FormatDateTime('yyyy-MM-dd HH:nn:ss', TmpDate);
end;

class function THexValueHelper.Bytes2SingleStr(Value: TBytes): string;
var
  tmpSingle: Single;
begin
  PDWORD(@tmpSingle)^ := getDWORD(Value, 0);
  Result := FloatToStr(tmpSingle);
end;

class function THexValueHelper.Bytes2DoubleStr(Value: TBytes): string;
var
  tmpSingle: Double;
begin
  PQWORD(@tmpSingle)^ := getQWORD(Value, 0);
  Result := FloatToStr(tmpSingle);
end;

class function THexValueHelper.Bytes2Float(Value: TBytes; scale: Integer): string;
var
  tmplong: Int64;
  TmPdouble: Double;
begin
  tmplong := getQWORD(Value, 1);
  TmPdouble := tmplong / Power(10, scale);
  if (Value[0] <> 1) then
  begin
    TmPdouble := -TmPdouble;
  end;
  Result := FloatToStr(TmPdouble);
end;

class function THexValueHelper.Bytes2Momey(Value: TBytes; scale: Integer): string;
var
  tmplong: Int64;
  TmPdouble: Double;
begin
  if Length(Value) = 4 then
  begin
    // smallMoney
    tmplong := getDWORD(Value, 0);
  end
  else
  begin
    //Money
    tmplong := getQWORD(Value, 0);
  end;
  TmPdouble := tmplong / Power(10, scale);
  Result := FloatToStr(TmPdouble);
end;

class function THexValueHelper.Bytes2AnsiBytesStr(Value: TBytes; CodePage: Integer): string;
var
  needSize: Integer;
  pwc: WideString;
begin
  needSize := MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@Value[0]), Length(Value), nil, 0);
  if needSize > 0 then
  begin
    SetLength(pwc, needSize);
    MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@Value[0]), Length(Value), PWideChar(@pwc[1]), needSize);
    Result := pwc;
  end;
end;

class function THexValueHelper.Bytes2GUIDStr(Value: TBytes): string;
var
  pp: PGUID;
begin
  pp := PGUID(@Value[0]);
  Result := GUIDToString(pp^);
end;

function THexValueHelper.GetFieldStrValue(Field: TdbFieldItem; Value: TBytes): string;
var
  needQuote: Boolean;
begin
  Result := GetFieldStrValue(Field, Value, needQuote);
end;

function THexValueHelper.GetFieldStrValue(Field: TdbFieldItem; Value: TBytes; out needQuote: Boolean): string;
begin
  needQuote := False;
  if Value = nil then
  begin
    case Field.type_id of
      MsTypes.TEXT, MsTypes.CHAR, MsTypes.VARCHAR,
      MsTypes.NTEXT, MsTypes.NVARCHAR, MsTypes.NCHAR:
      begin
        Result := '';
        needQuote := True;
      end;
    else
      Result := 'NULL';
    end;

    exit;
  end;
  if Length(Value) = 0 then
  begin
    Result := '';
    needQuote := True;
    exit;
  end;

  case Field.type_id of
    MsTypes.DATE:
      begin
        Result := Bytes2DateStr(Value);
        needQuote := True;
      end;
    MsTypes.TIME:
      begin
        Result := Bytes2TimeStr(Value, Field.scale);
        needQuote := True;
      end;
    MsTypes.DATETIME2:
      begin
        Result := Bytes2DateTime2Str(Value, Field.scale);
        needQuote := True;
      end;
    MsTypes.DATETIMEOFFSET:
      begin
        Result := Bytes2DateTimeOffsetStr(Value, Field.scale);
        needQuote := True;
      end;
    MsTypes.TINYINT:
      Result := IntToStr(ShortInt(Value[0]));
    MsTypes.SMALLINT:
      Result := IntToStr(getShort(Value, 0));
    MsTypes.INT:
      Result := IntToStr(getInt(Value, 0));
    MsTypes.BIGINT:
      Result := IntToStr(getInt64(Value, 0));
    MsTypes.SMALLDATETIME:
      begin
        Result := Bytes2smallDatetimeStr(Value);
        needQuote := True;
      end;
    MsTypes.REAL:
      Result := Bytes2SingleStr(Value);
    MsTypes.FLOAT:
      Result := Bytes2DoubleStr(Value);
    MsTypes.NUMERIC, MsTypes.DECIMAL:
      Result := Bytes2Float(Value, Field.scale);
    MsTypes.MONEY, MsTypes.SMALLMONEY:
      Result := Bytes2Momey(Value, Field.scale);
    MsTypes.DATETIME:
      begin
        Result := Bytes2DateTimeStr(Value);
        needQuote := True;
      end;

    MsTypes.TEXT, MsTypes.CHAR, MsTypes.VARCHAR:
      begin
        Result := Bytes2AnsiBytesStr(Value, Field.CodePage);
        needQuote := True;
      end;
    MsTypes.NTEXT, MsTypes.NVARCHAR, MsTypes.NCHAR:
      begin
        Result := PWideChar(Value);
        Result := Copy(Result, 0, Length(Value) div 2);
        needQuote := True;
      end;
    MsTypes.BIT:
      if Value[0] = 1 then
        Result := '1'
      else
        Result := '0';
    MsTypes.IMAGE, MsTypes.VARBINARY, MsTypes.BINARY:
      Result := '0x' + bytestostr_singleHex(Value);

    MsTypes.UNIQUEIDENTIFIER:
      begin
        Result := Bytes2GUIDStr(Value);
        needQuote := True;
      end;

    MsTypes.TIMESTAMP:      //SqlServer ��������ʽд��TIMESTAMP�ֶ�
      Result := '0x' + bytestostr_singleHex(Value);

    MsTypes.GEOGRAPHY:
      begin
        LogSource.Loger.add('�ݲ�֧�ֵ�����:%d GEOGRAPHY ������ʹ�ö�����ֵ', [Field.type_id]);
        Result := '0x' + bytestostr_singleHex(Value);
      end;

    MsTypes.XML:
      begin
        //TODO:���� xml
        LogSource.Loger.add('�ݲ�֧�ֵ����ͣ�XML ��ʹ��NULLֵ');
        Result := 'NULL';
      end;
    MsTypes.SQL_VARIANT:
      begin
        //TODO:���� SQL_VARIANT
        LogSource.Loger.add('�ݲ�֧�ֵ����ͣ�SQL_VARIANT ��ʹ��NULLֵ');
        Result := 'NULL';
      end;
  else
    LogSource.Loger.add('�ݲ�֧�ֵ�����:%d ��ʹ�ö�����ֵ', [Field.type_id]);
    Result := '0x' + bytestostr_singleHex(Value);
  end;

end;

function THexValueHelper.GetFieldStrValueWithQuoteIfNeed(Field: TdbFieldItem; Value: TBytes): string;
var
  needQuote: Boolean;
begin
  Result := GetFieldStrValue(Field, Value, needQuote);
  if needQuote then
  begin
    Result := Result.Replace('''','''''');
    Result := QuotedStr(Result);
  end;
end;


end.

