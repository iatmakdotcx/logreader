package mak.capture.mssql;

import mak.tools.HexTool;

public class MsFunc {
	public static double msConvert_Bytes2Float(byte[] value, int scale) {
		long tmplong = 0;
		for (int i = 0; i < 8; i++) {
			tmplong = (tmplong | ((value[i + 1] & 0xFF) << (i * 8)));
		}
		double dd = tmplong * 1.0 / Math.pow(10, scale);
		if (value[0] != 1) {
			dd = 0 - dd;
		}
		return dd;
	}
	
	public static String BuildSegment(MsColumn msColumn, byte[] value){
		String Result = "[" + msColumn.Name + "]=" + BuildSegmentValue(msColumn, value);
		return Result;
	}
	
	public static String BuildSegmentValue(MsColumn msColumn, byte[] value){
		String Result = "";
		
		if (value==null|| value.length==0) {
			Result += "NULL";
			return Result;
		}
		
		switch (msColumn.type_id) {
			case MsTypes.IMAGE:break;
			case MsTypes.TEXT:break;
			case MsTypes.UNIQUEIDENTIFIER:break;
			case MsTypes.DATE:break;
			case MsTypes.TIME:break;
			case MsTypes.DATETIME2:break;
			case MsTypes.DATETIMEOFFSET:break;
			case MsTypes.TINYINT:
				Result += value[0];
				break;
			case MsTypes.SMALLINT:
				short tmpShort = 0;
				for (int i = 0; i < Math.min(2, value.length); i++) {
					tmpShort = (short)(tmpShort | ((value[i]&0xFF) << (i*8)));
				}
				Result += tmpShort;
				break;
			case MsTypes.INT:
				int tmpInt = 0;
				for (int i = 0; i < Math.min(4, value.length); i++) {
					tmpInt = (tmpInt | ((value[i]&0xFF) << (i*8)));
				}
				Result += tmpInt;
				break;
			case MsTypes.BIGINT:
				long tmpLong = 0;
				for (int i = 0; i < Math.min(8, value.length); i++) {
					tmpLong = (tmpLong | ((value[i]&0xFF) << (i*8)));
				}
				Result += tmpLong;
				break;
			case MsTypes.SMALLDATETIME:break;
			case MsTypes.DATETIME:break;
			case MsTypes.SQL_VARIANT:break;
			case MsTypes.NTEXT:break;
			case MsTypes.BIT:
				Result += value[0] == 0 ? "0" : "1";
				break;
			case MsTypes.REAL:
			case MsTypes.MONEY:	
			case MsTypes.FLOAT:	
			case MsTypes.DECIMAL:
			case MsTypes.NUMERIC:
				Result += msConvert_Bytes2Float(value, msColumn.scale);
				break;
			case MsTypes.SMALLMONEY:break;
			case MsTypes.HIERARCHYID:break;
			case MsTypes.GEOMETRY:break;
			case MsTypes.GEOGRAPHY:break;
			case MsTypes.VARBINARY:break;
			case MsTypes.BINARY:break;
			case MsTypes.TIMESTAMP:break;
			case MsTypes.VARCHAR:
			case MsTypes.CHAR:
				String TmpStr = new String(value, msColumn.charset);
				Result += "'" + TmpStr + "'";
				break;
			case MsTypes.NVARCHAR:
			case MsTypes.NCHAR:
			case MsTypes.SYSNAME:
				Result += "'" + HexTool.toStringFromUnicode(value) + "'";
				break;
			case MsTypes.XML:break;
		default:
			break;
		}
		
		return Result;
	}
	
}
