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
	public static ConsoleOutput log = new ConsoleOutput();
	
	public static void main(String[] args) {
		// TODO Auto-generated method stub

//		byte[] bb = HexTool.getByteArrayFromHexString("01 F2 00 00 00 00 00 00 00");
//		double dsdd = new MsMain().msConvert_Bytes2Float(bb,4);
//		System.out.println(dsdd);
		
		System.out.println(AesTools.getInstance().Encode("123456"));
		System.out.println(AesTools.getInstance().Decode("KaJznD2QuERU7DWEXsgsWQ=="));
		
		
		//new MsMain().testUpdate();
		//new MsMain().testDelete();
		//new MsMain().testInsert();
		//new MsMain().testUpdate_LOP_MODIFY_ROW();
	}
	
	public static void insertLogPrise() {
		
		MsDatabase _Db = new MsDatabase(log,"192.168.0.61","sa","xxk@20130220","MaktestDB");
		MsDict md = new MsDict(_Db);
		if (md.CheckDBState()){
			md.RefreshDBDict();
		}

		MsTable mt = md.list_MsTable.get(325576198);
		MsColumn[] mcs = mt.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(HexTool.getByteArrayFromHexString("30002C00303030322020202020206B307B30933054302000200020002000200020000101F26911000000000005000001004E00F1E93FE5DEA1A2AACBAADBAAF3AAB4A1A3F1E9D9FEA3ACECEDD9FE"));
		int LogType = glea.readShort();
		int inSideDataOffset = glea.readShort();  //系统类型值 数据结尾
		glea.seek(inSideDataOffset, SeekOrigin.soFromBeginning);
		int ColumnCount = glea.readShort();  //当前表列数
		if (ColumnCount != mcs.length) {
			//FIXME 这里应该重新加载当前表的  MsTable数据
			log.Error("列数与日志不匹配!");
			return;
		}
		
		int NullMapLength = (mcs.length + 7) >>> 3;
		byte[] NullMap = glea.read(NullMapLength);
		int ExtDataCount = glea.readShort();  //扩展数据数量
		short[] ExtDataIdxList = new short[ExtDataCount];
		for (int i = 0; i < ExtDataCount; i++) {
			ExtDataIdxList[i] = glea.readShort();
		}
		int ExtDataBaseOffset = glea.getBytesRead();
		for (int i = 0; i < mcs.length; i++) {
			MsColumn mc = mcs[i];
			if (!mc.IsDefinitionColumn) {
				if (mc.is_nullable) {
					//判断列是否为null
					int a = mc.nullmap >>> 3;
					int b = (mc.nullmap & 7) - 1;
					if((NullMap[a] & (1 << b)) > 0){
						log.Info(mc.Name+":NULL_1");
						continue;
					}
				}

				if (mc.leaf_pos < 0) {
					int idx = 0 - mc.leaf_pos - 1;
					int dataBegin;
					if (idx == 0) {
						dataBegin = ExtDataBaseOffset;
					}else{
						dataBegin = ExtDataIdxList[idx - 1];
					}
					int datalen = ExtDataIdxList[idx] - dataBegin;
					if (datalen <= 0) {
						//data is null
						log.Info(mc.Name+":NULL");
					}else{
						glea.seek(dataBegin, SeekOrigin.soFromBeginning);
						byte[] tmp = glea.read(datalen);
					
						log.Info(mc.Name+':'+HexTool.toString(tmp));
						log.Info(mc.Name+':'+HexTool.toStringFromAscii(tmp,Charset.forName("MS949")));
						log.Info(mc.Name+':'+HexTool.toStringFromUnicode(tmp));
					}
				}else{
					//开始读取数据
					glea.seek(mc.leaf_pos, SeekOrigin.soFromBeginning);
					
					byte[] tmp = glea.read(mc.max_length);
					log.Info(mc.Name+':'+HexTool.toString(tmp));
				}
			}
		}
	}

}
