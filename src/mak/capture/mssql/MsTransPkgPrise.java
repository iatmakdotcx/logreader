package mak.capture.mssql;

import java.util.ArrayList;
import java.util.HashMap;

import org.apache.log4j.Logger;

import mak.capture.DBLogPriser;
import mak.capture.data.DBOptInsert;
import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;
import mak.tools.HexTool;
import mak.tools.StringUtil;

public class MsTransPkgPrise {
	private static Logger logger = Logger.getLogger(MsTransPkgPrise.class);  
	private MsTransPkg mPkg;
	private MsDict md;
	
	public ArrayList<DBLogPriser> Values= new ArrayList<>();
	private HashMap<String, byte[]> LCX_TEXT_MIX = new HashMap<>();
	public String aJobStr;
	
	
	public MsTransPkgPrise(MsTransPkg mPkg, MsDict md) {
		this.mPkg = mPkg;
		this.md = md;
	}
	
	/**
	 * 开始分解日志二进制
	 */
	public void start(){
		if (mPkg.actions.size() <= 2) {
			return;
		}
		
		for (MsLogRowData mlrd : mPkg.actions) {
			try{
				if (mlrd.operation.equals("LOP_INSERT_ROWS")) {
					if (mlrd.context.equals("LCX_TEXT_MIX")) {
						String Key = mlrd.pageFID +":" + mlrd.pagePID +":" +mlrd.slotid; 
						LCX_TEXT_MIX.put(Key, mlrd.r0);
					}else if (mlrd.context.equals("LCX_HEAP") || mlrd.context.equals("LCX_CLUSTERED")) {
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("解析日志失败！LOP_INSERT_ROWS.obj_id无效 LSN：" + mlrd.LSN);
							return;
						}
						DBOptInsert dbi = PriseInsertLog_LOP_INSERT_ROWS(mlrd);
						System.out.println(dbi.BuildSql());
					}else{
						logger.error("解析日志失败！LOP_INSERT_ROWS未知的context："+mlrd.context+" LSN：" + mlrd.LSN);
						return;
					}
					
				}else if (mlrd.operation.equals("LOP_MODIFY_ROW")) {
					//LOP_MODIFY_ROW的记录 Offset 作更新基准
					if (mlrd.context.equals("LCX_TEXT_MIX")) {
						String Key = mlrd.pageFID +":" + mlrd.pagePID +":" +mlrd.slotid; 
						byte[] olddata = LCX_TEXT_MIX.get(Key);
						byte[] newdata = new byte[mlrd.offset + mlrd.r1.length];
						System.arraycopy(olddata, 0, newdata, 0, mlrd.offset);
						System.arraycopy(mlrd.r1, 0, newdata, mlrd.offset, mlrd.r1.length);	
						LCX_TEXT_MIX.replace(Key, newdata);
					}else if (mlrd.context.equals("LCX_CLUSTERED")) {
						
						
					}else{
						logger.error("解析日志失败！LOP_MODIFY_ROW未知的context："+mlrd.context+" LSN：" + mlrd.LSN);
						return;
					}
				}else if (mlrd.operation.equals("LOP_MODIFY_COLUMNS")) {
					
					
					
				}else if (mlrd.operation.equals("LOP_DELETE_ROWS")) {
					if (mlrd.context.equals("LCX_TEXT_MIX")) {
						//二进制数据，删除
					}else if (mlrd.context.equals("LCX_HEAP") || mlrd.context.equals("LCX_MARK_AS_GHOST")){
						//LOP_DELETE_ROWS	LCX_MARK_AS_GHOST
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("解析日志失败！LOP_INSERT_ROWS.obj_id无效 LSN：" + mlrd.LSN);
							return;
						}
						DBOptInsert dbi = PriseInsertLog_LOP_INSERT_ROWS(mlrd);
						System.out.println(BuildDeleteSql(dbi, mlrd));
						
					}else if (mlrd.context.equals("LCX_MARK_AS_GHOST")){
						
						
					}
					
					
					
				}
			}catch(Exception eee){
				logger.error("解析日志失败！无效 LSN：" + mlrd.LSN, eee);
			}
		}
	}
	private String BuildDeleteSql(DBOptInsert dbi, MsLogRowData mlrd){
		if (dbi == null) {
			return "";
		}
		
		String s2 = "";
//		if (table.PrimaryKey != null) {
//			//如果表有主键，这个就根据主键生成where
//			for (MsColumn msColumn : table.PrimaryKey.Fields) {
//				int idx = Fields.indexOf(msColumn);
//				if (idx == -1) {
//					md.GetOutPut().Warning("日志解析异常：Delete：试图删除NULL主键值！！LSN" + LSN);
//					s2 += " and [" + Fields.get(idx).Name + "]=NULL";
//				}else{
//					s2 += " and " + MsFunc.BuildSegment(Fields.get(idx), Values.get(idx));
//				}
//			}
//		}else
		{
			if (mlrd.table.PrimaryKey != null && mlrd.table.PrimaryKey.Fields != null && mlrd.table.PrimaryKey.Fields.length > 0) {
				for (MsColumn msColumn : mlrd.table.PrimaryKey.Fields) {
					int idx = dbi.Fields.indexOf(msColumn);
					s2 += " and " + MsFunc.BuildSegment(msColumn, dbi.Values.get(idx));
				}
			}
			else{
				//没有主键就根据所有字段生成where
				for (int i = 0; i < dbi.Fields.size(); i++) {
					s2 += " and " + MsFunc.BuildSegment(dbi.Fields.get(i), dbi.Values.get(i));
				}
			}
		}
		s2 = s2.substring(5);
		return String.format("DELETE %s where %s", mlrd.table.GetFullName(), s2);
	}
	
	
	public byte[] get_LCX_TEXT_MIX_DATA(int key1,int key2,int pageFID,int pagePID,int slotid, MsLogRowData mlrd, int dlen) {
		String key = pageFID + ":" + pagePID + ":" + slotid;
		byte[] data = LCX_TEXT_MIX.get(key);
		if (data == null) {
			logger.error("日志解析失败！获取 LCX_TEXT_MIX_DATA 失败 LSN" + mlrd.LSN);
			return null;
		}
		GenericLittleEndianAccessor TEXT_MIX_DATA = new GenericLittleEndianAccessor(data);
		TEXT_MIX_DATA.seek(4, SeekOrigin.soFromBeginning);
		int datakey1 = TEXT_MIX_DATA.readInt();
		int datakey2 = TEXT_MIX_DATA.readInt();
		if (datakey1 == key1 && datakey2 == key2) {
			int dataType = TEXT_MIX_DATA.readShort();
			switch (dataType) {
			case 0:
				//数据长度 + 00 
				int dataLength0 = TEXT_MIX_DATA.readInt();
				int UNKNOWN = TEXT_MIX_DATA.readShort();
				return TEXT_MIX_DATA.read(dataLength0);
			case 3:
				//后面紧跟的全是数据内容
				return TEXT_MIX_DATA.read(dlen);
			case 5:
				//还是目录
				TEXT_MIX_DATA.seek(0x18, SeekOrigin.soFromBeginning);
				int dataLength5 = TEXT_MIX_DATA.readInt();
				
				int datapagePID = TEXT_MIX_DATA.readInt();
				int datapageFID = TEXT_MIX_DATA.readShort();
				int dataslotid = TEXT_MIX_DATA.readShort();
				return get_LCX_TEXT_MIX_DATA(key1,key2,datapageFID,datapagePID,dataslotid,mlrd, dataLength5);
			default:
				throw new UnsupportedOperationException("Not supported yet.");
			}
		}else{
			throw new UnsupportedOperationException("Not supported yet. ERROR Key1 and Key2");
		}
	}
	public byte[] get_LCX_TEXT_MIX_DATA(byte[] idxdata, MsLogRowData mlrd) {
		GenericLittleEndianAccessor TEXT_MIX_IDX = new GenericLittleEndianAccessor(idxdata);
		int key1 = TEXT_MIX_IDX.readInt();
		int key2 = TEXT_MIX_IDX.readInt();
		int pagePID = TEXT_MIX_IDX.readInt();
		int pageFID = TEXT_MIX_IDX.readShort();
		int slotid = TEXT_MIX_IDX.readShort();
		return get_LCX_TEXT_MIX_DATA(key1, key2, pageFID, pagePID, slotid, mlrd, 0);
	}
	
	public DBOptInsert PriseInsertLog_LOP_INSERT_ROWS(MsLogRowData mlrd) {
		// 	   | 30 00  | 08 00 |..............	| 04 00 |	........	| 02 00 | 00 00 |...............|
		//长度   |		4	|	4	|		x		|	4	|		x		|	4	|2*x	|		x		|
		//     |	①	|	②	|		③		|	④	|		⑤		|	⑥ 	|	⑦	|		⑧		|⑨
		// ①:日志类型
		// ②:系统类型值 数据结束位置（④的offset）
		// ③:系统类型值 数据
	    // ④:总列数
		// ⑤:nullMap 每1bit表示1列是否为null
		// ⑥:自定义字段值列数
		// ⑦:每2字节标识一个，自定义字段数据的结束位置
		// ⑧:自定义字段数据
		// ⑨：
		// |||||||
		DBOptInsert res = new DBOptInsert();
		res.obj_id = mlrd.obj_id;
		res.tableName = mlrd.table.GetFullName();
		
		MsColumn[] mcs = mlrd.table.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(mlrd.r0);
		int LogType = glea.readShort();
		if ((LogType&0x06)>0) {
			logger.warn("==================会失败的数据====================");
			logger.warn(HexTool.toString(mlrd.r0));
			return null;
		}
		
		/*if (LogType!=0x30) {
			md.GetOutPut().Error("貌似不是Insert日志："+LSN);
			return false;
		}
		*/
		int inSideDataOffset = glea.readShort();  //系统类型值 数据结尾
		glea.seek(inSideDataOffset, SeekOrigin.soFromBeginning);
		int ColumnCount = glea.readShort();  //当前表列数
		/*if (ColumnCount != mcs.length) {
			//表删除列之后，日志里还是以前的数量
			logger.error("列数与日志不匹配!" + mlrd.LSN);
			return null;
		}*/
		int boolbit = 0;
		int NullMapLength = (ColumnCount + 7) >>> 3;
		byte[] NullMap = glea.read(NullMapLength);
		int ExtDataCount = 0;
		if (glea.available() > 2) {
			ExtDataCount = glea.readShort();  //扩展数据数量
		}
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
					int b = mc.nullmap & 7;
					if((NullMap[a] & (1 << b)) > 0){
						//  cell is null
						continue;
					}
				}

				if (mc.leaf_pos < 0) {
					int idx = 0 - mc.leaf_pos - 1;
					if (idx < ExtDataIdxList.length) {
						int dataBegin;
						if (idx == 0) {
							dataBegin = ExtDataBaseOffset;
						}else{
							dataBegin = ExtDataIdxList[idx - 1] & 0x7FFF;
						}
						int datalen = (ExtDataIdxList[idx] & 0x7FFF) - dataBegin;
						if (datalen <= 0 || datalen > glea.available()) {
							//空字符串
							res.Fields.add(mc);
							res.Values.add(new byte[0]);
						}else{
							glea.seek(dataBegin, SeekOrigin.soFromBeginning);
							byte[] tmp;
							
							if ((ExtDataIdxList[idx] & 0x8000) > 0) {
								//如果最高位是1说明数据在LCX_TEXT_MIX包中
								tmp = glea.read(0x10);
								
								tmp = get_LCX_TEXT_MIX_DATA(tmp, mlrd);								
							}else{
								tmp = glea.read(datalen);
							}
							res.Fields.add(mc);
							res.Values.add(tmp);
						}
					}
				}else{
					if (isSkipColType(mc)) {
						continue;
					}
					//开始读取数据
					glea.seek(mc.leaf_pos, SeekOrigin.soFromBeginning);
					byte[] tmp = glea.read(mc.max_length);
					
					if (mc.type_id == MsTypes.BIT) {
						if (((1 << boolbit) & (tmp[0] & 0xFF)) > 0) {
							tmp[0] = 1;
						}else{
							tmp[0] = 0;
						}										
						boolbit++;
						if (boolbit == 8) {
							boolbit = 0;
						}
					}
					res.Fields.add(mc);
					res.Values.add(tmp);
				}
			}
		}
		return res;
	}
	
	private boolean isSkipColType(MsColumn mc){
		switch (mc.type_id) {
			case MsTypes.UNIQUEIDENTIFIER:
			case MsTypes.HIERARCHYID:
			case MsTypes.GEOMETRY:
			case MsTypes.GEOGRAPHY:
			case MsTypes.TIMESTAMP://这种类型的值不能直接写入数据库
			return true;
		default:
			return false;
		}
	}
}
