package mak.capture.mssql;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.HashMap;

import org.apache.log4j.Logger;

import mak.capture.DBLogPriser;
import mak.capture.data.DBOptInsert;
import mak.capture.data.DBOptUpdate;
import mak.data.input.GenericLittleEndianAccessor;
import mak.data.input.SeekOrigin;
import mak.tools.ArrayUtil;
import mak.tools.HexTool;

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
					}else if (mlrd.context.equals("LCX_HEAP") || mlrd.context.equals("LCX_CLUSTERED")) {
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("������־ʧ�ܣ�LOP_INSERT_ROWS.obj_id��Ч LSN��" + mlrd.LSN);
							return;
						}
						DBOptUpdate dbu = PriseUpdateLog_LOP_MODIFY_ROW(mlrd);
						System.out.println(dbu.BuildSql());
						
					}else{
						logger.error("������־ʧ�ܣ�LOP_MODIFY_ROWδ֪��context��"+mlrd.context+" LSN��" + mlrd.LSN);
						return;
					}
				}else if (mlrd.operation.equals("LOP_MODIFY_COLUMNS")) {
					if (mlrd.context.equals("LCX_CLUSTERED")) {
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("������־ʧ�ܣ�LOP_INSERT_ROWS.obj_id��Ч LSN��" + mlrd.LSN);
							return;
						}
						DBOptUpdate dbu = PriseUpdateLog_LOP_MODIFY_COLUMNS2(mlrd);
						System.out.println(dbu.BuildSql());
					}else{
						logger.error("������־ʧ�ܣ�LOP_MODIFY_COLUMNSδ֪��context��"+mlrd.context+" LSN��" + mlrd.LSN);
						return;
					}
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
						
					}else{
						logger.error("������־ʧ�ܣ�LOP_DELETE_ROWSδ֪��context��"+mlrd.context+" LSN��" + mlrd.LSN);
						return;
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
		if (mlrd.table.PrimaryKey != null && mlrd.table.PrimaryKey.Fields != null && mlrd.table.PrimaryKey.Fields.size() > 0) {
			for (MsColumn msColumn : mlrd.table.PrimaryKey.Fields) {
				int idx = dbi.Fields.indexOf(msColumn);
				s2 += " and " + MsFunc.BuildSegment(msColumn, dbi.Values.get(idx));
			}
		}
		else{
			//û�������͸��������ֶ�����where
			for (int i = 0; i < dbi.Fields.size(); i++) {
				if (canBeWhereSegColType(dbi.Fields.get(i))) {
					s2 += " and " + MsFunc.BuildSegment(dbi.Fields.get(i), dbi.Values.get(i));
				}
			}
		}
		s2 = s2.substring(5);
		return String.format("DELETE %s where %s", mlrd.table.GetFullName(), s2);
	}
	
	private void align4Byte(GenericLittleEndianAccessor glea){
		int position = glea.getBytesRead();
		glea.seek((position+3)&0xFFFFFFFC, SeekOrigin.soFromBeginning);
	}
	/**
	 * ����һ������nullMap������������Update���ݿ�
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  ���ݿ�
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(MsLogRowData mlrd,DBOptUpdate res,boolean isOldValue, int nullMapLength, int ValueStartOffset, byte[] BufBlock)
	{
		//���ǵ�nullMap����
		int OverlapNullMapLen = nullMapLength - (ValueStartOffset - mlrd.table.theFixedLength);
		if (OverlapNullMapLen < 0) {
			//�����������������ô�Ķ����ǵ�fixed������
			md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + mlrd.LSN);
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
				
				PriseValues(mlrd, res, isOldValue, nullMapLength, idxs, glea);
			}
		}
	}
	
	private void PriseValues(MsLogRowData mlrd,DBOptUpdate res,boolean isOldValue, int nullMapLength, short[] ValueIdx, GenericLittleEndianAccessor buf){
		MsColumn msColumn = null;
		//���㿪ʼ���µ��У��������µ��������Ƿŵ�һ�������
		int ColIdx = -1;
		int dataBaseOffset = mlrd.table.theFixedLength + nullMapLength + ValueIdx.length * 2 + 2;
		for (int i = 0; i < ValueIdx.length; i++) {
			int Prv_Datalen = 0;
			if (i == 0) {
				Prv_Datalen = ValueIdx[0] - dataBaseOffset;
			}else{
				Prv_Datalen = ValueIdx[i] - ValueIdx[i - 1];
			}
			if (Prv_Datalen > 0 && ValueIdx[i] > dataBaseOffset) {
				ColIdx = (mlrd.table.getNullMapSorted_Columns().length - mlrd.table.theVarFieldCount) + i;
				if (ColIdx < 0 || ColIdx > mlrd.table.getNullMapSorted_Columns().length) {
					md.GetOutPut().Error("��������ȡʧ�ܣ�����");
					return;
				}
				msColumn = mlrd.table.getNullMapSorted_Columns()[ColIdx];
				byte[] data = buf.read(Prv_Datalen); 
				String TmpStr = MsFunc.BuildSegment(msColumn, data);
				if (isOldValue) {
					res.OldValues.add(TmpStr);
				}else{
					res.NewValues.add(TmpStr);
				}
			}
		}
	}
	
	private DBOptUpdate PriseUpdateLog_LOP_MODIFY_COLUMNS2(MsLogRowData mlrd) {
		DBOptUpdate res = new DBOptUpdate();
		res.tableName = mlrd.table.GetFullName();
		res.obj_id = mlrd.table.id;
		mlrd.table.getNullMapSorted_Columns();
		GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(mlrd.LogRecord);
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
		align4Byte(glea);
		mlrd.r2 = glea.read(elements[2]);  //������
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
		int nullMapLength = (mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3;
		int valIdx = glea.getBytesRead();
		//ָ��var��idx���������ֵ�ģ��Ͳ���ͨ����־��ȡ�����ˣ��������pageҳ��ȡԭʼ���ݣ���
		int varDataIdxOffset = mlrd.table.theFixedLength + 2 + ((mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3);
		
		boolean MustReadPage = false;
		//offsetOfUpdatedCell�ĵ�һ����λ�������Ŀ�ʼ����λ�ã����������0 �Ļ�����ȡ��������ݿ�ֵ
		int OldOverlapIdxStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 0);//һ������£�����ȡ��ֵû���������壬������
		int NewOverlapIdxStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 2);
		if (OldOverlapIdxStartOffset == 0) {
			for (int i = 0; i < UpdateRangeCount; i++) {
				int OldValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
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
					int NewValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 6 + i * 2);	
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

		if (MustReadPage || true) {
			//�����ȡpage���ݣ�����ȫ�ָ��£�����
			if(!getFullUpdateDataByPrimaryKey(mlrd, res)){
				return null;
			}
		}else{
			//lucky�����������Ը�����־����������ǰ���ֵ
			glea.seek(valIdx,SeekOrigin.soFromBeginning);
			for (int i = 0; i < UpdateRangeCount; i++) {

				byte[] oldValue = glea.read(elements[6 + i * 2]);
				align4Byte(glea);
				byte[] newValue = glea.read(elements[6 + i * 2 + 1]);
				align4Byte(glea);
	
				int OldValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
				int NewValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 6 + i * 2);
				
				if (OldOverlapIdxStartOffset == 0) {
					//nullmap����Ϣ��values����
					PriseMixedUpdateBlock(mlrd, res, true, nullMapLength, OldValueStartOffset, oldValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (OldOverlapIdxStartOffset - mlrd.table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//�����������������ô�Ķ����ǵ�fixed������
						md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + mlrd.LSN);
						return null;
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
					PriseValues(mlrd,res, true, OldValueStartOffset, idxs, glea_idx_oldValue);
				}
				if (NewOverlapIdxStartOffset == 0) {
					//nullmap����Ϣ��values����
					PriseMixedUpdateBlock(mlrd,res,  true, nullMapLength, NewValueStartOffset, newValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (NewOverlapIdxStartOffset - mlrd.table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//�����������������ô�Ķ����ǵ�fixed������
						md.GetOutPut().Error("����Update��־���������ǵ�fixed���ݣ�LSN��" + mlrd.LSN);
						return null;
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
					PriseValues(mlrd, res, false, NewValueStartOffset, idxs, glea_idx_newValue);
				}
				
			}
			
			InitUpdatePrimarykey(mlrd, res);
		}
		
		return res;
	}
	
	private DBOptUpdate PriseUpdateLog_LOP_MODIFY_ROW(MsLogRowData mlrd) {
		DBOptUpdate res = new DBOptUpdate();
		res.tableName = mlrd.table.GetFullName();
		res.obj_id = mlrd.table.id;
		if (mlrd.r2==null || mlrd.r2.length==0) {
			//TODO:!!!!!!!!û��������ܳܳܳ
			logger.warn("���ݿ⣺"+md.Db.GetFullDbName()+"����:"+ mlrd.table.GetFullName()+"��������");
			
			
		}else{
			int nullMapLength = (mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3;
			int varDataIdxOffset = mlrd.table.theFixedLength + 2 + nullMapLength;
			if (mlrd.offset > varDataIdxOffset) {
				//���ޤä�����������äƤʤ顣�ꥢ�ǩ`�����i��
				if(!getFullUpdateDataByPrimaryKey(mlrd, res)){
					return null;
				}
			}else if(mlrd.offset < mlrd.table.theFixedLength){
				//�޸ķ�Χ�ǹ̶������ֶ�
			    for (MsColumn mColumn : mlrd.table.getNullMapSorted_Columns()) {
					if (mColumn.leaf_pos > 0) {
						if (mlrd.offset == mColumn.theRealPosition) {
							//�ҵ���
							String TmpStr = MsFunc.BuildSegment(mColumn, mlrd.r0);
							res.OldValues.add(TmpStr);
							TmpStr = MsFunc.BuildSegment(mColumn, mlrd.r1);
							res.NewValues.add(TmpStr);
							
							InitUpdatePrimarykey(mlrd, res);
						}else if (mlrd.offset > mColumn.theRealPosition && mlrd.offset < mColumn.theRealPosition + mColumn.max_length){
						    //����ֵ��Χ�ڣ�����Ҫ�������ݿ������ʵ����
							
							
							
						}
					}
				}
			}else{
				//������nullMap
				PriseMixedUpdateBlock(mlrd, res, true, nullMapLength, mlrd.offset, mlrd.r0);
				PriseMixedUpdateBlock(mlrd, res, false, nullMapLength, mlrd.offset, mlrd.r1);
				
				InitUpdatePrimarykey(mlrd, res);
			}
		}
		return res;
	}
	
	private void InitUpdatePrimarykey(MsLogRowData mlrd, DBOptUpdate res){
		GenericLittleEndianAccessor glea_key = new GenericLittleEndianAccessor(mlrd.r2);
		byte prefix = glea_key.readByte();
		//16���������У�36�䳤������
		if (prefix!=0x16 && prefix!=0x36) {
			logger.error("������־���棺"+mlrd.table.GetFullName()+"r2ǰ׺�쳣����������LSN:" + mlrd.LSN);
		}
		boolean fstbcl = true;
		//TODO:������������Ϊnull��Ϊʲô����nullMap��������
		int nullMapLength = (mlrd.table.getSorted_PrimaryColumns().length + 7) >>> 3;
		short[] idxs = null;
		int varColPosition = 0;
		for (MsColumn mColumn : mlrd.table.getSorted_PrimaryColumns()) {
			byte[] datas;
			if (mColumn.leaf_pos > 0) {
				//������
				datas = glea_key.read(mColumn.max_length);
			}else{
				//�䳤��
				if (fstbcl) {
					fstbcl = false;
					//��һ���䳤��ǰ����и�������
					int columnCount = glea_key.readShort();
					byte[] nullMap = glea_key.read(nullMapLength);
					int idxsCount = glea_key.readShort();
					idxs = new short[idxsCount];
					for (int j = 0; j < idxsCount; j++) {
						idxs[j] = glea_key.readShort();
					}
				}				
				short dataEndOffset = idxs[varColPosition];
				if (dataEndOffset<0) {
					logger.error("������־���棺"+mlrd.table.GetFullName()+"r2ǰ׺�쳣��������LSN:" + mlrd.LSN);
				}
				int datalen = dataEndOffset - glea_key.getBytesRead();
				datas = glea_key.read(datalen);
				varColPosition++;
			}
			String TmpStr = MsFunc.BuildSegment(mColumn, datas);
			res.KeyField.add(TmpStr);
		}
	}
	private String getFullUpdateDataFields(MsTable mTable){
		String res = ""; 
		for (MsColumn msColumn : mTable.GetFields()) {
			if (!isSkipColType(msColumn)) {
				res+= ",["+msColumn.Name+"]";
			}
		}
		if (!res.isEmpty()) {
			return res.substring(1);
		}else 
			return "";
	}
	
	private boolean getFullUpdateDataByPrimaryKey(MsLogRowData mlrd, DBOptUpdate res){
		if (mlrd.r2==null||mlrd.r2.length == 0) {
			logger.error("������־ʧ�ܣ�Updateû��r2ֵ��Ч LSN��" + mlrd.LSN);
			return false;
		}
		InitUpdatePrimarykey(mlrd,res);
		String WhereKey = "";
		for (String string : res.KeyField) {
			WhereKey += " and " + string;
		}
		WhereKey = WhereKey.substring(5);

		try {
			Statement statement = md.Db.conn.createStatement();
			String Sql = String.format("SELECT %s FROM %s WHERE %s", getFullUpdateDataFields(mlrd.table), mlrd.table.GetFullName(), WhereKey);
			ResultSet Rs = statement.executeQuery(Sql);
			if (!Rs.next()) {
				logger.error("��ȡ��������ʧ�ܣ������ݲ����ڣ�LSN:" + mlrd.LSN);
				return false;
			}
			ResultSetMetaData rsmd = Rs.getMetaData();
			for (int i = 1; i <= rsmd.getColumnCount(); i++) {
				String TStr = "["+rsmd.getColumnName(i)+"]=";
				Rs.getObject(i);
				if (Rs.wasNull()) {
					TStr += "NULL";
				}else{
					switch (rsmd.getColumnType(i)) {
					case java.sql.Types.BIT:
					case java.sql.Types.BOOLEAN:
						TStr += Rs.getBoolean(i)?"1":"0";
						break;
					case java.sql.Types.TINYINT:
					case java.sql.Types.SMALLINT:
					case java.sql.Types.INTEGER:
					case java.sql.Types.BIGINT:
						TStr += Rs.getInt(i);
						break;
					case java.sql.Types.FLOAT:
					case java.sql.Types.REAL:
					case java.sql.Types.DOUBLE:
					case java.sql.Types.NUMERIC:
					case java.sql.Types.DECIMAL:
						TStr += Rs.getDouble(i);
						break;
					case java.sql.Types.CHAR:
					case java.sql.Types.VARCHAR:
					case java.sql.Types.LONGVARCHAR:
					case java.sql.Types.NCHAR:
					case java.sql.Types.NVARCHAR:
					case java.sql.Types.LONGNVARCHAR:
						TStr += "'" + Rs.getString(i) + "'";
						break;	
					case java.sql.Types.DATE:
						TStr += "'" + Rs.getDate(i).toString() + "'";
						break;
					case java.sql.Types.TIME:
						TStr += "'" + Rs.getTime(i).toString()+ "'";
						break;
					case java.sql.Types.TIMESTAMP:
						DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS"); 
						TStr += "'" + dateFormat.format(Rs.getTimestamp(i).getTime())+"'";
						break;
					case -155:
						TStr += "'" + Rs.getTimestamp(i).toString();
						int tzo = Rs.getTimestamp(i).getTimezoneOffset();
						if (tzo<0) {
							TStr += " +"+Math.abs(tzo)/60+":"+Math.abs(tzo)%60;
						}else{
							TStr += " -"+Math.abs(tzo)/60+":"+Math.abs(tzo)%60;
						}
						TStr +="'";
						break;
					case java.sql.Types.BINARY:
					case java.sql.Types.VARBINARY:
					case java.sql.Types.LONGVARBINARY:
					case java.sql.Types.NULL:
					case java.sql.Types.OTHER:
					case java.sql.Types.JAVA_OBJECT:
					case java.sql.Types.DISTINCT:
					case java.sql.Types.STRUCT:
					case java.sql.Types.ARRAY:
					case java.sql.Types.BLOB:
					case java.sql.Types.CLOB:
					case java.sql.Types.REF:
					case java.sql.Types.DATALINK:
					case java.sql.Types.ROWID:
					case java.sql.Types.NCLOB:
					case java.sql.Types.SQLXML:
					case java.sql.Types.REF_CURSOR:
					case java.sql.Types.TIME_WITH_TIMEZONE:
					case java.sql.Types.TIMESTAMP_WITH_TIMEZONE:
						TStr += "0x" + HexTool.toString(Rs.getBytes(i)).replace(" ", "");
						break;
					default:
						throw new UnsupportedOperationException("Not supported yet.530");
					}
				}
				res.NewValues.add(TStr);
			}
			
			Rs.close();
			statement.close();
			return true;
		} catch (SQLException e) {
			logger.error("��ȡ���ݿ���־ʧ�ܣ�", e);
		}
		return false;
		
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
			case MsTypes.SQL_VARIANT:
			case MsTypes.XML:
			case MsTypes.TIMESTAMP://�������͵�ֵ����ֱ��д�����ݿ�
			return true;
		default:
			return false;
		}
	}
	
	/**
	 * �ܹ���Ϊwhere�������ֶ�����
	 * @param mc
	 * @return
	 */
	private boolean canBeWhereSegColType(MsColumn mc){
		switch (mc.type_id) {
		case MsTypes.DATE:
		case MsTypes.TIME:
		case MsTypes.DATETIME2:
		case MsTypes.DATETIMEOFFSET:
		case MsTypes.TINYINT:
		case MsTypes.SMALLINT:
		case MsTypes.INT:
		case MsTypes.BIGINT:
		case MsTypes.SMALLDATETIME:
		case MsTypes.DATETIME:
		case MsTypes.BIT:
		case MsTypes.DECIMAL:
		case MsTypes.NUMERIC:
		case MsTypes.MONEY:	
		case MsTypes.SMALLMONEY:
		case MsTypes.VARCHAR:
		case MsTypes.CHAR:
		//case MsTypes.TEXT:  //��Ȼ������Ϊ��������������ֶ����ݱȽ϶࣬����ȫ
		//case MsTypes.NTEXT:
		//case MsTypes.REAL:  //����Ϊ����ȫ�ġ����ơ�ֵ.
		//case MsTypes.FLOAT:	
		case MsTypes.NVARCHAR:
		case MsTypes.NCHAR:
		case MsTypes.SYSNAME:

			return true;
		default:
			return false;
		}
	}
}
