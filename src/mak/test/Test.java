package mak.test;

import java.nio.charset.Charset;

import mak.capture.log.ConsoleOutput;
import mak.capture.mssql.MsColumn;
import mak.capture.mssql.MsDict;
import mak.capture.mssql.MsMain;
import mak.capture.mssql.MsDatabase;
import mak.capture.mssql.MsTable;
import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;
import mak.tools.AesTools;
import mak.tools.HexTool;

public class Test {
	public static ConsoleOutput log = ConsoleOutput.getInstance();
	
	public static void main(String[] args) {
		// TODO Auto-generated method stub

		
		
		
		
		
		
//		byte[] bb = HexTool.getByteArrayFromHexString("01 F2 00 00 00 00 00 00 00");
//		double dsdd = new MsMain().msConvert_Bytes2Float(bb,4);
//		System.out.println(dsdd);
		
		//log.Info(AesTools.getInstance().Encode("123456"));
		//log.Error(AesTools.getInstance().Decode("KaJznD2QuERU7DWEXsgsWQ=="));
		
		
		//new MsMain().testUpdate();
		//new MsMain().testDelete();
		//new MsMain().testInsert();
		//new MsMain().testUpdate_LOP_MODIFY_ROW();
	}

}
