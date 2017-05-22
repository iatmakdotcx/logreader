package mak.capture.mssql;

import java.util.ArrayList;

import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;

public class MsLogUpdate extends MsLogInsert {

	public ArrayList<String> OldValues= new ArrayList<String>();
	public ArrayList<String> NewValues = new ArrayList<String>();
	public ArrayList<String> KeyField = new ArrayList<String>();
	
	public boolean PriseUpdateLog_LOP_MODIFY_COLUMNS2() {
		table.getNullMapSorted_Columns();
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(LogRecord);
		glea.skip(2);
		int NumElementsOffset = glea.readShort();
		glea.seek(NumElementsOffset, SeekOrigin.soFromBeginning);
		
		int NumElements = glea.readShort();
		if (NumElements == 4) {
			//LOP_MODIFY_ROW
		}else if (NumElements == 8) {
			//LOP_MODIFY_COLUMNS 更新一个段
		}else  if (NumElements > 8) {
			//LOP_MODIFY_COLUMNS 更新多个段
		}else{
			//这尼玛就不知道是啥了
		}
		short[] elements = new short[NumElements]; 
		for (int i = 0; i < NumElements; i++) {
			elements[i] = glea.readShort();
		}
		//开始的索引长度一般 = 2+更新区域*2。第一、二位分别是老数据和新数据的nullmap开始位置
		byte[] offsetOfUpdatedCell = glea.read(elements[0]);
		byte[] UNKNOWN = glea.read(elements[1]);
		r2 = glea.read(elements[2]);  //行主键
		align4Byte(glea);
		byte[] TableInfo = glea.read(elements[3]);//更新表的主要信息，如表的Object_id
		align4Byte(glea);
		
		byte[] idxOfcells_Old = glea.read(elements[4]);
		align4Byte(glea);
		byte[] idxOfcells_New = glea.read(elements[5]);
		align4Byte(glea);
		
	
		
		//更新区域数。相邻的字段合并到一个区域
		int UpdateRangeCount = (NumElements - 6) / 2;
		//nullMap长度  (	
		int nullMapLength = (table.getNullMapSorted_Columns().length + 7) >>> 3;
		int valIdx = glea.getBytesRead();
		//指向var列idx（大于这个值的，就不能通过日志获取东西了，必须根据page页获取原始数据！！
		int varDataIdxOffset = table.theFixedLength + 2 + ((table.getNullMapSorted_Columns().length + 7) >>> 3);
		
		boolean MustReadPage = false;
		//offsetOfUpdatedCell的第一、二位是索引的开始覆盖位置，（如果等于0 的话，就取后面的数据块值
		int OldOverlapIdxStartOffset = getBytesShort(offsetOfUpdatedCell, 0);//一般情况下，这里取老值没有明显意义，忽略了
		int NewOverlapIdxStartOffset = getBytesShort(offsetOfUpdatedCell, 2);
		if (OldOverlapIdxStartOffset == 0) {
			for (int i = 0; i < UpdateRangeCount; i++) {
				int OldValueStartOffset = getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
				if (OldValueStartOffset > varDataIdxOffset) {
					MustReadPage = true;
					break;
				}
			}
		}else{
			if (OldOverlapIdxStartOffset > varDataIdxOffset) {
				MustReadPage = true;
			}
		}
		if (MustReadPage == false) {
			if (NewOverlapIdxStartOffset == 0) {
				for (int i = 0; i < UpdateRangeCount; i++) {
					int NewValueStartOffset = getBytesShort(offsetOfUpdatedCell, 6 + i * 2);	
					if (NewValueStartOffset > varDataIdxOffset) {
						MustReadPage = true;
						break;
					}
				}
			}else{
				if (NewOverlapIdxStartOffset > varDataIdxOffset) {
					MustReadPage = true;
				}
			}
		}

		
		
		if (MustReadPage) {
			//必须读取page数据，生成全局更新！！！
			System.out.println("还没搞好！！");
			
		}else{
			//lucky！！！，可以根据日志解析，更新前后的值
			glea.seek(valIdx,SeekOrigin.soFromBeginning);
			for (int i = 0; i < UpdateRangeCount; i++) {

				byte[] oldValue = glea.read(elements[6 + i * 2]);
				align4Byte(glea);
				byte[] newValue = glea.read(elements[6 + i * 2 + 1]);
				align4Byte(glea);
	
				int OldValueStartOffset = getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
				int NewValueStartOffset = getBytesShort(offsetOfUpdatedCell, 6 + i * 2);
				
				if (OldOverlapIdxStartOffset == 0) {
					//nullmap等信息在values里面
					PriseMixedUpdateBlock(true, nullMapLength, OldValueStartOffset, oldValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (OldOverlapIdxStartOffset - table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//！！！有情况，，特么的都覆盖到fixed数据了
						md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + LSN);
						return false;
					}
					
					
					GenericLittleEndianAccessor glea_idx_old = new GenericLittleEndianAccessor(idxOfcells_Old);
					byte[] nullMap = glea_idx_old.read(OverlapNullMapLen);
					
					int idxsCount = glea_idx_old.readShort();
					short[] idxs = new short[idxsCount];
					for (int j = 0; j < idxsCount; j++) {
						idxs[j] = glea_idx_old.readShort();
					}
					
					GenericLittleEndianAccessor glea_idx_oldValue = new GenericLittleEndianAccessor(oldValue);
					PriseValues(true, OldValueStartOffset, idxs, glea_idx_oldValue);
				}
				if (NewOverlapIdxStartOffset == 0) {
					//nullmap等信息在values里面
					PriseMixedUpdateBlock(true, nullMapLength, NewValueStartOffset, newValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (NewOverlapIdxStartOffset - table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//！！！有情况，，特么的都覆盖到fixed数据了
						md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + LSN);
						return false;
					}
					
					GenericLittleEndianAccessor glea_idx_new = new GenericLittleEndianAccessor(idxOfcells_New);
					byte[] nullMap = glea_idx_new.read(OverlapNullMapLen);
					
					int idxsCount = glea_idx_new.readShort();
					short[] idxs = new short[idxsCount];
					for (int j = 0; j < idxsCount; j++) {
						idxs[j] = glea_idx_new.readShort();
					}
					
					GenericLittleEndianAccessor glea_idx_newValue = new GenericLittleEndianAccessor(newValue);
					PriseValues(false, NewValueStartOffset, idxs, glea_idx_newValue);
				}
				
			}
			
			GenericLittleEndianAccessor glea_key = new GenericLittleEndianAccessor(r2);
			byte prefix = glea_key.readByte();
			if (prefix!=0x16) {
				md.GetOutPut().Warning("更新日志警告："+table.GetFullName()+"r2前缀异常！！！！！LSN:" + LSN);
			}
			
			for (MsColumn mColumn : table.PrimaryKey.Fields) {
				byte[] datas = glea_key.read(mColumn.max_length);
				String TmpStr = MsFunc.BuildSegment(mColumn, datas);
				KeyField.add(TmpStr);
			}
		}
		
		return true;
	}
	
	/**
	 * 解析一个包含nullMap和数据索引的Update数据块
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  数据块
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(boolean isOldValue, int nullMapLength, int ValueStartOffset, byte[] BufBlock)
	{
		//覆盖的nullMap长度
		int OverlapNullMapLen = nullMapLength - (ValueStartOffset - table.theFixedLength);
		if (OverlapNullMapLen < 0) {
			//！！！有情况，，特么的都覆盖到fixed数据了
			md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + LSN);
			return;
		}
		
		if (BufBlock != null && BufBlock.length >= OverlapNullMapLen) {
			GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(BufBlock);
			glea.skip(OverlapNullMapLen);//跳过覆盖的nullMap
			if (glea.available()>0) {
				//索引块大小,这个是数据存储的variant字段索引表
				int idxsCount = glea.readShort();
				short[] idxs = new short[idxsCount];
				for (int i = 0; i < idxsCount; i++) {
					idxs[i] = glea.readShort();
				}
				
				PriseValues(isOldValue, ValueStartOffset, idxs, glea);
			}
		}
	}
	
	public boolean PriseUpdateLog_LOP_MODIFY_COLUMNS() {
		table.getNullMapSorted_Columns();
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(LogRecord);
		glea.skip(2);
		int NumElementsOffset = glea.readShort();
		glea.seek(NumElementsOffset, SeekOrigin.soFromBeginning);
		
		int NumElements = glea.readShort();
		if (NumElements == 4) {
			//LOP_MODIFY_ROW
		}else if (NumElements == 8) {
			//LOP_MODIFY_COLUMNS 更新一个段
		}else  if (NumElements > 8) {
			//LOP_MODIFY_COLUMNS 更新多个段
		}else{
			//这尼玛就不知道是啥了
		}
		short[] elements = new short[NumElements]; 
		for (int i = 0; i < NumElements; i++) {
			elements[i] = glea.readShort();
		}
		//开始的索引长度一般 = 2+更新区域*2。第一、二位分别是老数据和新数据的nullmap开始位置
		byte[] offsetOfUpdatedCell = glea.read(elements[0]);
		byte[] UNKNOWN = glea.read(elements[1]);
		r2 = glea.read(elements[2]);  //行主键
		align4Byte(glea);
		byte[] TableInfo = glea.read(elements[3]);//更新表的主要信息，如表的Object_id
		align4Byte(glea);
		
		byte[] idxOfcells_Old = glea.read(elements[4]);
		align4Byte(glea);
		byte[] idxOfcells_New = glea.read(elements[5]);
		align4Byte(glea);
		
			//nullMap长度  (	
		int nullMapLength = (table.getNullMapSorted_Columns().length + 7) >>> 3;	
		
		//更新区域数。相邻的字段合并到一个区域
		int UpdateRangeCount = (NumElements - 6) / 2;
		
		int valIdx = glea.getBytesRead();
		for (int i = 0; i < UpdateRangeCount; i++) {
			
			
			

//			
//			int OldNullMapLength = 0;
//			int NewNullMapLength = 0;
			
			
			
//			int FieldOffset = getBytesShort(offsetOfUpdatedCell, 0);
//			if (FieldOffset == 0){
//				OldNullMapLength = nullMapLength;
//			}else{
//				//减2是因为theVarFieldDataOffset最后两位是var列的数量
//				OldNullMapLength = nullMapLength + (table.theFixedLength - FieldOffset);
//			}
//			FieldOffset = getBytesShort(offsetOfUpdatedCell, 2);
//			if (FieldOffset == 0){
//				NewNullMapLength = nullMapLength;
//			}else{
//				NewNullMapLength = nullMapLength + (table.theFixedLength - FieldOffset);
//			}	
			
			
			
			
			
			byte[] oldValue = glea.read(elements[6 + i * 2]);
			align4Byte(glea);
			byte[] newValue = glea.read(elements[6 + i * 2 + 1]);
			align4Byte(glea);

			int OldValueStartOffset = getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
			int NewValueStartOffset = getBytesShort(offsetOfUpdatedCell, 6 + i * 2);
			
			int OldNullMapLength = nullMapLength - (OldValueStartOffset - table.theFixedLength);
			if (OldNullMapLength > 0) {
				//说明有nullmap被覆盖了
				
			}
			int NewNullMapLength = nullMapLength - (NewValueStartOffset - table.theFixedLength);
			if (OldNullMapLength > 0) {
				//说明有nullmap需要写入
				
			}
			
			 
			if (idxOfcells_Old.length == 1) {
				//nullmap等信息在values里面
				PriseMixedUpdateBlock(true, OldNullMapLength, oldValue, OldValueStartOffset);
			}else{
				GenericLittleEndianAccessor glea_idx_old = new GenericLittleEndianAccessor(idxOfcells_Old);

				byte[] nullMap = glea_idx_old.read(OldNullMapLength);
				
				int idxsCount = glea_idx_old.readShort();
				short[] idxs = new short[idxsCount];
				for (int j = 0; j < idxsCount; j++) {
					idxs[j] = glea_idx_old.readShort();
				}
				
				GenericLittleEndianAccessor glea_idx_oldValue = new GenericLittleEndianAccessor(oldValue);
				PriseValues(true, OldValueStartOffset, idxs, glea_idx_oldValue);
			}
			if (idxOfcells_New.length == 1) {
				//nullmap等信息在values里面
				PriseMixedUpdateBlock(false, NewNullMapLength, newValue, NewValueStartOffset);
			}else{
				GenericLittleEndianAccessor glea_idx_new = new GenericLittleEndianAccessor(idxOfcells_New);
				byte[] nullMap = glea_idx_new.read(NewNullMapLength);
				
				int idxsCount = glea_idx_new.readShort();
				short[] idxs = new short[idxsCount];
				for (int j = 0; j < idxsCount; j++) {
					idxs[j] = glea_idx_new.readShort();
				}
				
				GenericLittleEndianAccessor glea_idx_newValue = new GenericLittleEndianAccessor(newValue);
				PriseValues(false, NewValueStartOffset, idxs, glea_idx_newValue);
			}
		}
		
		GenericLittleEndianAccessor glea_key = new GenericLittleEndianAccessor(r2);
		byte prefix = glea_key.readByte();
		if (prefix!=0x16) {
			md.GetOutPut().Warning("更新日志警告："+table.GetFullName()+"r2前缀异常！！！！！LSN:" + LSN);
		}
		
		for (MsColumn mColumn : table.PrimaryKey.Fields) {
			byte[] datas = glea_key.read(mColumn.max_length);
			String TmpStr = MsFunc.BuildSegment(mColumn, datas);
			KeyField.add(TmpStr);
		}
		return true;
	}
	
	/**
	 * 解析一个包含nullMap和数据索引的Update数据块
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  数据块
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(boolean isOldValue, int nullMapLen, byte[] BufBlock, int ValueStartOffset)
	{
		if (BufBlock != null && BufBlock.length >= nullMapLen) {
			GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(BufBlock);
			byte[] nullMap = glea.read(nullMapLen);
			if (glea.available()>0) {
				//索引块大小,这个是数据存储的variant字段索引表
				int idxsCount = glea.readShort();
				short[] idxs = new short[idxsCount];
				for (int i = 0; i < idxsCount; i++) {
					idxs[i] = glea.readShort();
				}
				
				PriseValues(isOldValue, ValueStartOffset, idxs, glea);
			}
		}
	}
	
	public void PriseValues(boolean isOldValue, int ValueStartOffset, short[] ValueIdx, GenericLittleEndianAccessor buf){
		MsColumn msColumn = null;
		//计算开始更新的列，挨到更新的两个列是放到一块里面的
		int ColIdx = -1;
		for (int i = 0; i < ValueIdx.length; i++) {
			int Prv_Datalen = 0;
			if (i == 0) {
				//第二列
				Prv_Datalen = ValueIdx[0] - ValueStartOffset;
			}else{
				Prv_Datalen = ValueIdx[i] - ValueIdx[i - 1];
			}
			if (Prv_Datalen > 0 && ValueIdx[i] > ValueStartOffset) {
				ColIdx = (table.getNullMapSorted_Columns().length - table.theVarFieldCount) + i;
				if (ColIdx < 0 || ColIdx > table.getNullMapSorted_Columns().length) {
					md.GetOutPut().Error("列索引获取失败！！！");
					return;
				}
				msColumn = table.getNullMapSorted_Columns()[ColIdx];
				byte[] data = buf.read(Prv_Datalen); 
				String TmpStr = MsFunc.BuildSegment(msColumn, data);
				if (isOldValue) {
					OldValues.add(TmpStr);
				}else{
					NewValues.add(TmpStr);
				}
			}
		}
	}
	
	/**
	 * 数据4位对齐
	 * @param glea
	 */
	public void align4Byte(GenericLittleEndianAccessor glea){
		int position = glea.getBytesRead();
		glea.seek((position+3)&0xFFFFFFFC, SeekOrigin.soFromBeginning);
	}
	
	public short getBytesShort(byte[] byf,int idx){
		if (idx > byf.length) {
			return 0;
		}else if (idx > byf.length + 1) {
			return (short)(byf[idx] & 0xFF);
		}else
			return (short)((byf[idx] & 0xFF) | (byf[idx + 1]<<8));
	}
	
	public boolean PriseUpdateLog_LOP_MODIFY_ROW() {
		//只更新一列且数据类型是系统固定长度类型时，生成的是LOP_MODIFY_ROW日志，否者是LOP_MODIFY_COLUMNS日志
		if (!operation.equals("LOP_MODIFY_ROW")) {
			md.GetOutPut().Info("非LOP_MODIFY_ROW日志！");
			return false;
		}
		
		if (table.PrimaryKey == null){
			md.GetOutPut().Error("更新日志异常："+table.GetFullName()+"无PrimaryKey，却使用了LOP_MODIFY_ROW更新！！！！LSN:" + LSN);
			return false;
		}
		MsColumn UpdateField = null;
		for (MsColumn mc : table.GetFields()) {
			if (mc.theRealPosition == offset) {
				UpdateField = mc;
				break;
			}
		}
		if (UpdateField == null) {
			md.GetOutPut().Error("更新日志异常："+table.GetFullName()+"。Offset_in_Row无效");
			return false;
		}
		String oldVals = MsFunc.BuildSegment(UpdateField, r0);
		OldValues.add(oldVals);
		String newVals = MsFunc.BuildSegment(UpdateField, r1);
		NewValues.add(newVals);
		
		
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(r2);
		byte prefix = glea.readByte();
		if (prefix!=0x16) {
			md.GetOutPut().Warning("更新日志警告："+table.GetFullName()+"r2前缀异常！！！！！LSN:" + LSN);
		}
		
		for (MsColumn mColumn : table.PrimaryKey.Fields) {
			byte[] datas = glea.read(mColumn.max_length);
			String TmpStr = MsFunc.BuildSegment(mColumn, datas);
			KeyField.add(TmpStr);
		}
		return true;
	}
	
	
	private void ReadFullDataFromDbccPage(GenericLittleEndianAccessor glea){
		glea.seek(0x18, SeekOrigin.soFromBeginning);
		int pageFID = glea.readInt(); 
		int pagePID = glea.readShort();
		
		
	}
	
	@Override
	public String BuildSql(){
		if (KeyField.isEmpty()) {
			if (!PriseUpdateLog_LOP_MODIFY_COLUMNS2()) {
				return "";
			}
		}
		
		String s2 = "";
		for (String string : NewValues) {
			s2 += "," + string;
		}
		s2 = s2.substring(1);
		
		String s3 = "";
		for (String string : KeyField) {
			s3 += " and " + string;
		}
		s3 = s3.substring(5);
		
		String Result = String.format("UPDATE %s SET %s WHERE %s", table.GetFullName(),s2,s3);
		return Result;
	}
}
