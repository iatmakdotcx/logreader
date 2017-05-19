package mak.capture.mssql;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.TimeZone;

import mak.tools.ArrayUtil;
import mak.tools.HexTool;
import mak.tools.StringUtil;

public class MsFunc {
	private static double msConvert_Bytes2Float(byte[] value, int scale) {
		long tmplong = ArrayUtil.getByteslong(value,1);
		double dd = tmplong * 1.0 / Math.pow(10, scale);
		if (value[0] != 1) {
			dd = 0 - dd;
		}
		return dd;
	}
	
	private static double msConvert_Bytes2Momey(byte[] value, int scale) {
		long tmplong = 0;
		if (value.length == 4) {
			tmplong = ArrayUtil.getBytesInt(value,0);
		}else{
			tmplong = ArrayUtil.getByteslong(value,0);
		}
		double dd = tmplong * 1.0 / Math.pow(10, scale);
		return dd;
	}
	
	private static String msConvert_Bytes2DatetimeStr(byte[] arrby) {
		int ldate = ArrayUtil.getBytesInt(arrby, 0);
		int hdate = ArrayUtil.getBytesInt(arrby, 4);
		Calendar cale = Calendar.getInstance();  
		cale.set(1900, 0, 1, 0, 0, 0);
		cale.add(Calendar.DAY_OF_YEAR, hdate);
		cale.add(Calendar.SECOND, ldate / 300);
		cale.set(Calendar.MILLISECOND, (int)((ldate % 300)/300.0*1000));
		
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");
		return format.format(cale.getTime());
	}
	
	private static String msConvert_Bytes2smallDatetimeStr(byte[] arrby) {
		int ldate = ArrayUtil.getBytesInt(arrby, 0, 2);
		int hdate = ArrayUtil.getBytesInt(arrby, 2, 2);
		Calendar cale = Calendar.getInstance();  
		cale.set(1900, 0, 1, 0, 0, 0);
		cale.add(Calendar.DAY_OF_YEAR, hdate);
		cale.add(Calendar.MINUTE, ldate);
		
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		return format.format(cale.getTime());
	}
	
	private static String msConvert_Bytes2DateTime2Str(byte[] arrby, int scale) {
		//秒数
		long ldate = ArrayUtil.getByteslong(arrby, 0, 5);
		//天数
		int hdate = ArrayUtil.getBytesInt(arrby, 5, 3);
		Calendar cale = Calendar.getInstance();  
		cale.setTimeZone(TimeZone.getTimeZone("GMT"));
		cale.set(0001, 0, 3, 0, 0, 0);
		cale.add(Calendar.DAY_OF_YEAR, hdate);
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		String Result = format.format(cale.getTime());
		
		int scaleCardinal = (int)Math.pow(10, scale);
		int TotalSrcond = (int) (ldate / scaleCardinal);
		int srcond = TotalSrcond % 60;
		int minute = (TotalSrcond / 60)% 60;
		int hours = TotalSrcond / 3600;
		String miSecond = StringUtil.getLeftPaddedStr((ldate % scaleCardinal)+"",'0',scale);
		Result += " "+hours+ ":"+minute+":"+srcond+"."+miSecond;

		return Result + " ";
	}
	
	private static String msConvert_Bytes2DateStr(byte[] arrby) {
		int hdate = ArrayUtil.getBytesInt(arrby, 0, 3);
		Calendar cale = Calendar.getInstance();  
		cale.set(0001, 0, 3, 0, 0, 0);
		cale.add(Calendar.DAY_OF_YEAR, hdate);
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		return format.format(cale.getTime());
	}
	
	private static String msConvert_Bytes2TimeStr(byte[] arrby, int scale) {
		long hdate = ArrayUtil.getByteslong(arrby, 0, 5);
		int scaleCardinal = (int)Math.pow(10, scale);
		int TotalSrcond = (int) (hdate / scaleCardinal);
		int srcond = TotalSrcond % 60;
		int minute = (TotalSrcond / 60)% 60;
		int hours = TotalSrcond / 3600;
		String miSecond = StringUtil.getLeftPaddedStr((hdate % scaleCardinal)+"",'0',scale);
		return  hours+ ":"+minute+":"+srcond+"."+miSecond;
	}
	
	private static String msConvert_Bytes2DateTimeOffsetStr(byte[] arrby, int scale) {
		String TimeZoneStr;
		int fixVal = ArrayUtil.getBytesShort(arrby, 8);
		
		if (fixVal<0) {
			TimeZoneStr = "-" + Math.abs(fixVal)/60 + ":" + Math.abs(fixVal)%60;
		}else{
			TimeZoneStr = "+" + Math.abs(fixVal)/60 + ":" + Math.abs(fixVal)%60;;
		}
		//秒数
		long ldate = ArrayUtil.getByteslong(arrby, 0, 5);
		//天数
		int hdate = ArrayUtil.getBytesInt(arrby, 5, 3);
		Calendar cale = Calendar.getInstance();  
		cale.setTimeZone(TimeZone.getTimeZone("GMT"));
		cale.set(0001, 0, 3, 0, 0, 0);
		cale.add(Calendar.DAY_OF_YEAR, hdate);
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		String Result = format.format(cale.getTime());
		
		int scaleCardinal = (int)Math.pow(10, scale);
		int TotalSrcond = (int) (ldate / scaleCardinal)+(fixVal*60);
		int srcond = TotalSrcond % 60;
		int minute = (TotalSrcond / 60)% 60;
		int hours = TotalSrcond / 3600;
		String miSecond = StringUtil.getLeftPaddedStr((ldate % scaleCardinal)+"",'0',scale);
		Result += " "+hours+ ":"+minute+":"+srcond+"."+miSecond;

		return Result + " " + TimeZoneStr;
	}
	

	
	public static String BuildSegment(MsColumn msColumn, byte[] value){
		String Result = "[" + msColumn.Name + "]=" + BuildSegmentValue(msColumn, value);
		return Result;
	}
	
	public static String BuildSegmentValue(MsColumn msColumn, byte[] value){
		if (value == null) {
			return "NULL";
		}
		if (value.length == 0) {
			//空字符串
			return "''";
		}
		String Result = "";
		switch (msColumn.type_id) {
			case MsTypes.DATE:
				Result += "'" + msConvert_Bytes2DateStr(value) + "'" ;
				break;
			case MsTypes.TIME:
				Result += "'" + msConvert_Bytes2TimeStr(value, msColumn.scale) + "'" ;
				break;
			case MsTypes.DATETIME2:
				Result += "'" + msConvert_Bytes2DateTime2Str(value, msColumn.scale) + "'" ;
				break;
			case MsTypes.DATETIMEOFFSET:
				Result += "'" + msConvert_Bytes2DateTimeOffsetStr(value, msColumn.scale) + "'" ;
				break;
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
			case MsTypes.SMALLDATETIME:
				Result += "'" + msConvert_Bytes2smallDatetimeStr(value) + "'" ;
				break;
			case MsTypes.DATETIME:
				Result += "'" + msConvert_Bytes2DatetimeStr(value) + "'" ;
				break;
			case MsTypes.BIT:
				Result += value[0] == 0 ? "0" : "1";
				break;
			case MsTypes.REAL:
				Result += Float.intBitsToFloat(ArrayUtil.getBytesInt(value, 0));
				break;
			case MsTypes.FLOAT:	
				Result += Double.longBitsToDouble(ArrayUtil.getByteslong(value, 0));
				break;
			case MsTypes.DECIMAL:
			case MsTypes.NUMERIC:
				Result += msConvert_Bytes2Float(value, msColumn.scale);
				break;
			case MsTypes.MONEY:	
			case MsTypes.SMALLMONEY:
				Result += msConvert_Bytes2Momey(value, msColumn.scale);
				break;
			case MsTypes.SQL_VARIANT:
				String TmpSqlStr;
				if (value.length >= 8) {
					byte[] sqlbytes = new byte[value.length - 8];
					System.arraycopy(value, 8, sqlbytes, 0, sqlbytes.length);
					TmpSqlStr = new String(sqlbytes, msColumn.charset);
				}else{
					TmpSqlStr = new String(value, msColumn.charset);
				}
				Result += "'" + TmpSqlStr + "'";
				break;	
			case MsTypes.VARCHAR:
			case MsTypes.CHAR:
			case MsTypes.TEXT:
				String TmpStr = new String(value, msColumn.charset);
				Result += "'" + TmpStr + "'";
				break;
			case MsTypes.NVARCHAR:
			case MsTypes.NCHAR:
			case MsTypes.SYSNAME:
			case MsTypes.NTEXT:
				Result += "'" + HexTool.toStringFromUnicode(value) + "'";
				break;
			case MsTypes.XML:
			case MsTypes.IMAGE:
			case MsTypes.BINARY:
			case MsTypes.VARBINARY:
				Result += "0x"+HexTool.toString(value).replace(" ", "");
				break;
			case MsTypes.UNIQUEIDENTIFIER:throw new UnsupportedOperationException("Not supported yet.");
			case MsTypes.HIERARCHYID:throw new UnsupportedOperationException("Not supported yet.");
			case MsTypes.GEOMETRY:throw new UnsupportedOperationException("Not supported yet.");
			case MsTypes.GEOGRAPHY:throw new UnsupportedOperationException("Not supported yet.");
			case MsTypes.TIMESTAMP:
				//TIMESTAMP的不能显示的insert值
				throw new UnsupportedOperationException("Not supported yet.");
		default:
			break;
		}
		
		return Result;
	}
	
}
