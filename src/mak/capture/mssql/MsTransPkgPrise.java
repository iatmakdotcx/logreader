package mak.capture.mssql;

import java.util.ArrayList;
import java.util.HashMap;

import org.apache.log4j.Logger;

import mak.capture.DBLogPriser;
import mak.capture.data.DBOptInsert;
import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;

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
	 * ��ʼ�ֽ���־������
	 */
	public void start(){
		if (mPkg.actions.size() <= 2) {
			return;
		}
		
		for (MsLogRowData mlrd : mPkg.actions) {
			if (mlrd.operation.equals("LOP_INSERT_ROWS")) {
				if (mlrd.context.equals("LCX_TEXT_MIX")) {
					String Key = mlrd.pageFID +":" + mlrd.pagePID +":" +mlrd.slotid; 
					LCX_TEXT_MIX.put(Key, mlrd.r0);
				}else if (mlrd.context.equals("LCX_HEAP")) {
					mlrd.table = md.list_MsTable.get(mlrd.obj_id);
					if (mlrd.table == null) {
						logger.error("������־ʧ�ܣ�LOP_INSERT_ROWS.obj_id��Ч LSN��" + mlrd.LSN);
					}
					
				}
				
			}else if (mlrd.operation.equals("LOP_MODIFY_ROW")) {
				//LOP_MODIFY_ROW�ļ�¼ Offset �����»�׼
				if (mlrd.context.equals("LCX_TEXT_MIX")) {
					String Key = mlrd.pageFID +":" + mlrd.pagePID +":" +mlrd.slotid; 
					byte[] olddata = LCX_TEXT_MIX.get(Key);
					byte[] newdata = new byte[mlrd.offset + mlrd.r1.length];
					System.arraycopy(olddata, 0, newdata, 0, mlrd.offset);
					System.arraycopy(mlrd.r1, 0, newdata, mlrd.offset, mlrd.r1.length);	
					LCX_TEXT_MIX.replace(Key, newdata);
				}
				
				
			}else if (mlrd.operation.equals("LOP_MODIFY_COLUMNS")) {
				
				
				
			}else if (mlrd.operation.equals("LOP_DELETE_ROWS")) {
				
				
				
			}
		}
	}
	public byte[] get_LCX_TEXT_MIX_DATA(int key1,int key2,int pageFID,int pagePID,int slotid, MsLogRowData mlrd, int dlen) {
		String key = pageFID + ":" + pagePID + ":" + slotid;
		byte[] data = LCX_TEXT_MIX.get(key);
		if (data == null) {
			logger.error("��־����ʧ�ܣ���ȡ LCX_TEXT_MIX_DATA ʧ�� LSN" + mlrd.LSN);
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
				//���ݳ��� + 00 
				int dataLength0 = TEXT_MIX_DATA.readInt();
				int UNKNOWN = TEXT_MIX_DATA.readShort();
				return TEXT_MIX_DATA.read(dataLength0);
			case 3:
				//���������ȫ����������
				return TEXT_MIX_DATA.read(dlen);
			case 5:
				//����Ŀ¼
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
		DBOptInsert res = new DBOptInsert();
		
		MsColumn[] mcs = mlrd.table.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(mlrd.r0);
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
			logger.error("��������־��ƥ��!" + mlrd.LSN);
			return null;
		}
		int boolbit = 0;
		int NullMapLength = (mcs.length + 7) >>> 3;
		byte[] NullMap = glea.read(NullMapLength);
		int ExtDataCount = 0;
		if (glea.available() > 2) {
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
							byte[] tmp;
							
							if ((ExtDataIdxList[idx] & 0x8000) > 0) {
								//������λ��1˵��������LCX_TEXT_MIX����
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
					res.Fields.add(mc);
					res.Values.add(tmp);
				}
			}
		}
		return res;
	}
	
	
}
