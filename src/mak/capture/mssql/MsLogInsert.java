package mak.capture.mssql;

import java.util.ArrayList;
import mak.capture.DBLogPriser;

import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;

public class MsLogInsert implements DBLogPriser {
	public MsDict md;
	public MsTable table;
	public String LSN;
	
	public String operation;
	public String context;
	
	public byte[] r0;  //  old value
	public byte[] r1;  //  new Value
	public byte[] r2;  //  Paramkey
	public int Offset_in_Row = 0;	

	public byte[] LogRecord;  //  LOP_MODIFY_COLUMNS的数据全从这取

	public ArrayList<MsColumn> Fields= new ArrayList<>();
	public ArrayList<byte[]> Values= new ArrayList<>();
	
	public boolean PriseInsertLog_LOP_INSERT_ROWS() {
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
		
		MsColumn[] mcs = table.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(r0);
		int LogType = glea.readShort();
		/*if (LogType!=0x30) {
			md.GetOutPut().Error("貌似不是Insert日志："+LSN);
			return false;
		}
		*/
		int inSideDataOffset = glea.readShort();  //系统类型值 数据结尾
		glea.seek(inSideDataOffset, SeekOrigin.soFromBeginning);
		int ColumnCount = glea.readShort();  //当前表列数
		if (ColumnCount != mcs.length) {
			//FIXME 这里应该重新加载当前表的  MsTable数据
			md.GetOutPut().Error("列数与日志不匹配!"+LSN);
			return false;
		}
		int boolbit = 0;
		int NullMapLength = (mcs.length + 7) >>> 3;
		byte[] NullMap = glea.read(NullMapLength);
		int ExtDataCount = 0;
		if (glea.available()>2) {
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
					int b = (mc.nullmap & 7) - 1;
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
							//data is null
						}else{
							glea.seek(dataBegin, SeekOrigin.soFromBeginning);
							byte[] tmp = glea.read(datalen);
							
							if ((ExtDataIdxList[idx] & 0x8000) > 0) {
								//如果最高位是1说明数据在LCX_TEXT_MIX包中
								
								
								
								
							}
							Fields.add(mc);
							Values.add(tmp);
						}
					}
				}else{
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
					Fields.add(mc);
					Values.add(tmp);
				}
			}
		}
		return true;
	}
	
	public String BuildSql(){
		if (Fields.isEmpty()) {
			if (!PriseInsertLog_LOP_INSERT_ROWS()) {
				return "";
			}
		}
		
		String s1 = "";
		String s2 = "";
		
		for (int i = 0; i < Fields.size(); i++) {
			s1 += ",[" + Fields.get(i).Name + "]";
			s2 += "," + MsFunc.BuildSegmentValue(Fields.get(i), Values.get(i));
		}
		s1 = s1.substring(1);
		s2 = s2.substring(1);
		String result = String.format("INSERT into %s(%s) values(%s)", table.GetFullName(), s1, s2);
		return result;
	}

    @Override
    public boolean Prepare() {
        if (Fields.isEmpty()) {
            if (!PriseInsertLog_LOP_INSERT_ROWS()) {
                    return false;
            }
	}
        return true;
    }
}
