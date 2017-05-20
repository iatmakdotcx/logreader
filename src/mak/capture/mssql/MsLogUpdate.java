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
			//LOP_MODIFY_COLUMNS ����һ����
		}else  if (NumElements > 8) {
			//LOP_MODIFY_COLUMNS ���¶����
		}else{
			//������Ͳ�֪����ɶ��
		}
		short[] elements = new short[NumElements]; 
		for (int i = 0; i < NumElements; i++) {
			elements[i] = glea.readShort();
		}
		//��ʼ����������һ�� = 2+��������*2����һ����λ�ֱ��������ݺ������ݵ�nullmap��ʼλ��
		byte[] offsetOfUpdatedCell = glea.read(elements[0]);
		byte[] UNKNOWN = glea.read(elements[1]);
		r2 = glea.read(elements[2]);  //������
		align4Byte(glea);
		byte[] TableInfo = glea.read(elements[3]);//���±����Ҫ��Ϣ������Object_id
		align4Byte(glea);
		
		byte[] idxOfcells_Old = glea.read(elements[4]);
		align4Byte(glea);
		byte[] idxOfcells_New = glea.read(elements[5]);
		align4Byte(glea);
		
	
		
		//���������������ڵ��ֶκϲ���һ������
		int UpdateRangeCount = (NumElements - 6) / 2;
		//nullMap����  (	
		int nullMapLength = (table.getNullMapSorted_Columns().length + 7) >>> 3;
		int valIdx = glea.getBytesRead();
		//ָ��var��idx���������ֵ�ģ��Ͳ���ͨ����־��ȡ�����ˣ��������pageҳ��ȡԭʼ���ݣ���
		int varDataIdxOffset = table.theFixedLength + 2 + ((table.getNullMapSorted_Columns().length + 7) >>> 3);
		
		boolean MustReadPage = false;
		//offsetOfUpdatedCell�ĵ�һ����λ�������Ŀ�ʼ����λ�ã����������0 �Ļ�����ȡ��������ݿ�ֵ
		int OldOverlapIdxStartOffset = getBytesShort(offsetOfUpdatedCell, 0);//һ������£�����ȡ��ֵû���������壬������
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
			//�����ȡpage���ݣ�����ȫ�ָ��£�����
			System.out.println("��û��ã���");
			
		}else{
			//lucky�����������Ը�����־����������ǰ���ֵ
			glea.seek(valIdx,SeekOrigin.soFromBeginning);
			for (int i = 0; i < UpdateRangeCount; i++) {

				byte[] oldValue = glea.read(elements[6 + i * 2]);
				align4Byte(glea);
				byte[] newValue = glea.read(elements[6 + i * 2 + 1]);
				align4Byte(glea);
	
				int OldValueStartOffset = getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
				int NewValueStartOffset = getBytesShort(offsetOfUpdatedCell, 6 + i * 2);
				
				if (OldOverlapIdxStartOffset == 0) {
					//nullmap����Ϣ��values����
					PriseMixedUpdateBlock(true, nullMapLength, OldValueStartOffset, oldValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (OldOverlapIdxStartOffset - table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//�����������������ô�Ķ����ǵ�fixed������
						md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + LSN);
						return false;
					}
					
					
					GenericLittleEndianAccessor glea_idx_old = new GenericLittleEndianAccessor(idxOfcells_Old);
					glea_idx_old.PaddingZeroOnEof = true;
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
					//nullmap����Ϣ��values����
					PriseMixedUpdateBlock(true, nullMapLength, NewValueStartOffset, newValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (NewOverlapIdxStartOffset - table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//�����������������ô�Ķ����ǵ�fixed������
						md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + LSN);
						return false;
					}
					
					GenericLittleEndianAccessor glea_idx_new = new GenericLittleEndianAccessor(idxOfcells_New);
					glea_idx_new.PaddingZeroOnEof = true;
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
				md.GetOutPut().Warning("������־���棺"+table.GetFullName()+"r2ǰ׺�쳣����������LSN:" + LSN);
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
	 * ����һ������nullMap������������Update���ݿ�
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  ���ݿ�
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(boolean isOldValue, int nullMapLength, int ValueStartOffset, byte[] BufBlock)
	{
		//���ǵ�nullMap����
		int OverlapNullMapLen = nullMapLength - (ValueStartOffset - table.theFixedLength);
		if (OverlapNullMapLen < 0) {
			//�����������������ô�Ķ����ǵ�fixed������
			md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + LSN);
			return;
		}
		
		if (BufBlock != null && BufBlock.length >= OverlapNullMapLen) {
			GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(BufBlock);
			glea.PaddingZeroOnEof = true;
			glea.skip(OverlapNullMapLen);//�������ǵ�nullMap
			if (glea.available()>0) {
				//�������С,��������ݴ洢��variant�ֶ�������
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
			//LOP_MODIFY_COLUMNS ����һ����
		}else  if (NumElements > 8) {
			//LOP_MODIFY_COLUMNS ���¶����
		}else{
			//������Ͳ�֪����ɶ��
		}
		short[] elements = new short[NumElements]; 
		for (int i = 0; i < NumElements; i++) {
			elements[i] = glea.readShort();
		}
		//��ʼ����������һ�� = 2+��������*2����һ����λ�ֱ��������ݺ������ݵ�nullmap��ʼλ��
		byte[] offsetOfUpdatedCell = glea.read(elements[0]);
		byte[] UNKNOWN = glea.read(elements[1]);
		r2 = glea.read(elements[2]);  //������
		align4Byte(glea);
		byte[] TableInfo = glea.read(elements[3]);//���±����Ҫ��Ϣ������Object_id
		align4Byte(glea);
		
		byte[] idxOfcells_Old = glea.read(elements[4]);
		align4Byte(glea);
		byte[] idxOfcells_New = glea.read(elements[5]);
		align4Byte(glea);
		
			//nullMap����  (	
		int nullMapLength = (table.getNullMapSorted_Columns().length + 7) >>> 3;	
		
		//���������������ڵ��ֶκϲ���һ������
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
//				//��2����ΪtheVarFieldDataOffset�����λ��var�е�����
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
				//˵����nullmap��������
				
			}
			int NewNullMapLength = nullMapLength - (NewValueStartOffset - table.theFixedLength);
			if (OldNullMapLength > 0) {
				//˵����nullmap��Ҫд��
				
			}
			
			 
			if (idxOfcells_Old.length == 1) {
				//nullmap����Ϣ��values����
				PriseMixedUpdateBlock(true, OldNullMapLength, oldValue, OldValueStartOffset);
			}else{
				GenericLittleEndianAccessor glea_idx_old = new GenericLittleEndianAccessor(idxOfcells_Old);
				glea_idx_old.PaddingZeroOnEof = true;
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
				//nullmap����Ϣ��values����
				PriseMixedUpdateBlock(false, NewNullMapLength, newValue, NewValueStartOffset);
			}else{
				GenericLittleEndianAccessor glea_idx_new = new GenericLittleEndianAccessor(idxOfcells_New);
				glea_idx_new.PaddingZeroOnEof = true;
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
			md.GetOutPut().Warning("������־���棺"+table.GetFullName()+"r2ǰ׺�쳣����������LSN:" + LSN);
		}
		
		for (MsColumn mColumn : table.PrimaryKey.Fields) {
			byte[] datas = glea_key.read(mColumn.max_length);
			String TmpStr = MsFunc.BuildSegment(mColumn, datas);
			KeyField.add(TmpStr);
		}
		return true;
	}
	
	/**
	 * ����һ������nullMap������������Update���ݿ�
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  ���ݿ�
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(boolean isOldValue, int nullMapLen, byte[] BufBlock, int ValueStartOffset)
	{
		if (BufBlock != null && BufBlock.length >= nullMapLen) {
			GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(BufBlock);
			glea.PaddingZeroOnEof = true;
			byte[] nullMap = glea.read(nullMapLen);
			if (glea.available()>0) {
				//�������С,��������ݴ洢��variant�ֶ�������
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
		//���㿪ʼ���µ��У��������µ��������Ƿŵ�һ�������
		int ColIdx = -1;
		for (int i = 0; i < ValueIdx.length; i++) {
			int Prv_Datalen = 0;
			if (i == 0) {
				//�ڶ���
				Prv_Datalen = ValueIdx[0] - ValueStartOffset;
			}else{
				Prv_Datalen = ValueIdx[i] - ValueIdx[i - 1];
			}
			if (Prv_Datalen > 0 && ValueIdx[i] > ValueStartOffset) {
				ColIdx = (table.getNullMapSorted_Columns().length - table.theVarFieldCount) + i;
				if (ColIdx < 0 || ColIdx > table.getNullMapSorted_Columns().length) {
					md.GetOutPut().Error("��������ȡʧ�ܣ�����");
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
	 * ����4λ����
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
		//ֻ����һ��������������ϵͳ�̶���������ʱ�����ɵ���LOP_MODIFY_ROW��־��������LOP_MODIFY_COLUMNS��־
		if (!operation.equals("LOP_MODIFY_ROW")) {
			md.GetOutPut().Info("��LOP_MODIFY_ROW��־��");
			return false;
		}
		
		if (table.PrimaryKey == null){
			md.GetOutPut().Error("������־�쳣��"+table.GetFullName()+"��PrimaryKey��ȴʹ����LOP_MODIFY_ROW���£�������LSN:" + LSN);
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
			md.GetOutPut().Error("������־�쳣��"+table.GetFullName()+"��Offset_in_Row��Ч");
			return false;
		}
		String oldVals = MsFunc.BuildSegment(UpdateField, r0);
		OldValues.add(oldVals);
		String newVals = MsFunc.BuildSegment(UpdateField, r1);
		NewValues.add(newVals);
		
		
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(r2);
		byte prefix = glea.readByte();
		if (prefix!=0x16) {
			md.GetOutPut().Warning("������־���棺"+table.GetFullName()+"r2ǰ׺�쳣����������LSN:" + LSN);
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
