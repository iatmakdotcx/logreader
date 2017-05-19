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
	 * ��ʼ�ֽ���־������
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
							logger.error("������־ʧ�ܣ�LOP_INSERT_ROWS.obj_id��Ч LSN��" + mlrd.LSN);
							return;
						}
						DBOptInsert dbi = PriseInsertLog_LOP_INSERT_ROWS(mlrd);
						System.out.println(dbi.BuildSql());
					}else{
						logger.error("������־ʧ�ܣ�LOP_INSERT_ROWSδ֪��context��"+mlrd.context+" LSN��" + mlrd.LSN);
						return;
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
					}else if (mlrd.context.equals("LCX_CLUSTERED")) {
						
						
					}else{
						logger.error("������־ʧ�ܣ�LOP_MODIFY_ROWδ֪��context��"+mlrd.context+" LSN��" + mlrd.LSN);
						return;
					}
				}else if (mlrd.operation.equals("LOP_MODIFY_COLUMNS")) {
					
					
					
				}else if (mlrd.operation.equals("LOP_DELETE_ROWS")) {
					if (mlrd.context.equals("LCX_TEXT_MIX")) {
						//���������ݣ�ɾ��
					}else if (mlrd.context.equals("LCX_HEAP") || mlrd.context.equals("LCX_MARK_AS_GHOST")){
						//LOP_DELETE_ROWS	LCX_MARK_AS_GHOST
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("������־ʧ�ܣ�LOP_INSERT_ROWS.obj_id��Ч LSN��" + mlrd.LSN);
							return;
						}
						DBOptInsert dbi = PriseInsertLog_LOP_INSERT_ROWS(mlrd);
						System.out.println(BuildDeleteSql(dbi, mlrd));
						
					}else if (mlrd.context.equals("LCX_MARK_AS_GHOST")){
						
						
					}
					
					
					
				}
			}catch(Exception eee){
				logger.error("������־ʧ�ܣ���Ч LSN��" + mlrd.LSN, eee);
			}
		}
	}
	private String BuildDeleteSql(DBOptInsert dbi, MsLogRowData mlrd){
		if (dbi == null) {
			return "";
		}
		
		String s2 = "";
//		if (table.PrimaryKey != null) {
//			//�����������������͸�����������where
//			for (MsColumn msColumn : table.PrimaryKey.Fields) {
//				int idx = Fields.indexOf(msColumn);
//				if (idx == -1) {
//					md.GetOutPut().Warning("��־�����쳣��Delete����ͼɾ��NULL����ֵ����LSN" + LSN);
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
				//û�������͸��������ֶ�����where
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
		res.obj_id = mlrd.obj_id;
		res.tableName = mlrd.table.GetFullName();
		
		MsColumn[] mcs = mlrd.table.getNullMapSorted_Columns();
		
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(mlrd.r0);
		int LogType = glea.readShort();
		if ((LogType&0x06)>0) {
			logger.warn("==================��ʧ�ܵ�����====================");
			logger.warn(HexTool.toString(mlrd.r0));
			return null;
		}
		
		/*if (LogType!=0x30) {
			md.GetOutPut().Error("ò�Ʋ���Insert��־��"+LSN);
			return false;
		}
		*/
		int inSideDataOffset = glea.readShort();  //ϵͳ����ֵ ���ݽ�β
		glea.seek(inSideDataOffset, SeekOrigin.soFromBeginning);
		int ColumnCount = glea.readShort();  //��ǰ������
		/*if (ColumnCount != mcs.length) {
			//��ɾ����֮����־�ﻹ����ǰ������
			logger.error("��������־��ƥ��!" + mlrd.LSN);
			return null;
		}*/
		int boolbit = 0;
		int NullMapLength = (ColumnCount + 7) >>> 3;
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
							//���ַ���
							res.Fields.add(mc);
							res.Values.add(new byte[0]);
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
					if (isSkipColType(mc)) {
						continue;
					}
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
	
	private boolean isSkipColType(MsColumn mc){
		switch (mc.type_id) {
			case MsTypes.UNIQUEIDENTIFIER:
			case MsTypes.HIERARCHYID:
			case MsTypes.GEOMETRY:
			case MsTypes.GEOGRAPHY:
			case MsTypes.TIMESTAMP://�������͵�ֵ����ֱ��д�����ݿ�
			return true;
		default:
			return false;
		}
	}
}
