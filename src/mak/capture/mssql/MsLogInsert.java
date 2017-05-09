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

	public byte[] LogRecord;  //  LOP_MODIFY_COLUMNS������ȫ����ȡ

	public ArrayList<MsColumn> Fields= new ArrayList<>();
	public ArrayList<byte[]> Values= new ArrayList<>();
	
	public boolean PriseInsertLog_LOP_INSERT_ROWS() {
		// 	   | 30 00  | 08 00 |..............	| 04 00 |	........	| 02 00 | 00 00 |...............|
		//����   |		4	|	4	|		x		|	4	|		x		|	4	|2*x	|		x		|
		//     |	��	|	��	|		��		|	��	|		��		|	�� 	|	��	|		��		|��
		// ��:��־����
		// ��:ϵͳ����ֵ ���ݽ���λ�ã��ܵ�offset��
		// ��:ϵͳ����ֵ ����
	    // ��:������
		// ��:nullMap ÿ1bit��ʾ1���Ƿ�Ϊnull
		// ��:�Զ����ֶ�ֵ����
		// ��:ÿ2�ֽڱ�ʶһ�����Զ����ֶ����ݵĽ���λ��
		// ��:�Զ����ֶ�����
		// �᣺
		// |||||||
		
		MsColumn[] mcs = table.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(r0);
		int LogType = glea.readShort();
		/*if (LogType!=0x30) {
			md.GetOutPut().Error("ò�Ʋ���Insert��־��"+LSN);
			return false;
		}
		*/
		int inSideDataOffset = glea.readShort();  //ϵͳ����ֵ ���ݽ�β
		glea.seek(inSideDataOffset, SeekOrigin.soFromBeginning);
		int ColumnCount = glea.readShort();  //��ǰ������
		if (ColumnCount != mcs.length) {
			//FIXME ����Ӧ�����¼��ص�ǰ���  MsTable����
			md.GetOutPut().Error("��������־��ƥ��!"+LSN);
			return false;
		}
		int boolbit = 0;
		int NullMapLength = (mcs.length + 7) >>> 3;
		byte[] NullMap = glea.read(NullMapLength);
		int ExtDataCount = 0;
		if (glea.available()>2) {
			ExtDataCount = glea.readShort();  //��չ��������
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
					//�ж����Ƿ�Ϊnull
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
								//������λ��1˵��������LCX_TEXT_MIX����
								
								
								
								
							}
							Fields.add(mc);
							Values.add(tmp);
						}
					}
				}else{
					//��ʼ��ȡ����
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
