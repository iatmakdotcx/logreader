unit dbFieldTypes;

interface

type
  MsTypes = class
    const
      IMAGE = 34;
      TEXT = 35;
      UNIQUEIDENTIFIER = 36;
      DATE = 40;
      TIME = 41;
      DATETIME2 = 42;
      DATETIMEOFFSET = 43;
      TINYINT = 48;
      SMALLINT = 52;
      INT = 56;
      SMALLDATETIME = 58;
      REAL = 59;
      MONEY = 60;
      DATETIME = 61;
      FLOAT = 62;
      SQL_VARIANT = 98;
      NTEXT = 99;
      BIT = 104;
      DECIMAL = 106;
      NUMERIC = 108;
      SMALLMONEY = 122;
      BIGINT = 127;
      VARBINARY = 165;
      VARCHAR = 167;
      BINARY = 173;
      CHAR = 175;
      TIMESTAMP = 189;
      NVARCHAR = 231;
      NCHAR = 239;
      GEOGRAPHY = 240;
      XML = 241;
  end;

function getSingleDataTypeStr(type_id: Integer): string;

implementation


function getSingleDataTypeStr(type_id: Integer): string;
begin
  case type_id of
    MsTypes.TINYINT,
    MsTypes.SMALLINT,
    MsTypes.INT,
    MsTypes.BIGINT:
      Result := 'int';
    MsTypes.REAL,
    MsTypes.MONEY,
    MsTypes.FLOAT,
    MsTypes.DECIMAL,
    MsTypes.NUMERIC,
    MsTypes.SMALLMONEY:
      Result := 'float';
    MsTypes.UNIQUEIDENTIFIER,
    MsTypes.TEXT,
    MsTypes.NTEXT,
    MsTypes.NVARCHAR,
    MsTypes.NCHAR,
    MsTypes.CHAR,
    MsTypes.VARCHAR:
      Result := 'string';
    MsTypes.BIT:
      Result := 'bool';
    MsTypes.DATE,
    MsTypes.TIME,
    MsTypes.DATETIME2,
    MsTypes.DATETIMEOFFSET,
    MsTypes.SMALLDATETIME,
    MsTypes.DATETIME:
      Result := 'datetime';
    MsTypes.IMAGE,
    MsTypes.SQL_VARIANT,
    MsTypes.VARBINARY,
    MsTypes.BINARY,
    MsTypes.TIMESTAMP,
    MsTypes.GEOGRAPHY,
    MsTypes.XML:
      Result := 'bin';
  end;
end;

end.

