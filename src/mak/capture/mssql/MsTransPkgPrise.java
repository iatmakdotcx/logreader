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
					}else if (mlrd.context.equals("LCX_HEAP") || mlrd.context.equals("LCX_CLUSTERED")) {
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("解析日志失败！LOP_INSERT_ROWS.obj_id无效 LSN：" + mlrd.LSN);
							return;
						}
						DBOptUpdate dbu = PriseUpdateLog_LOP_MODIFY_ROW(mlrd);
						System.out.println(dbu.BuildSql());
						
					}else{
						logger.error("解析日志失败！LOP_MODIFY_ROW未知的context："+mlrd.context+" LSN：" + mlrd.LSN);
						return;
					}
				}else if (mlrd.operation.equals("LOP_MODIFY_COLUMNS")) {
					if (mlrd.context.equals("LCX_CLUSTERED")) {
						mlrd.table = md.list_MsTable.get(mlrd.obj_id);
						if (mlrd.table == null) {
							logger.error("解析日志失败！LOP_INSERT_ROWS.obj_id无效 LSN：" + mlrd.LSN);
							return;
						}
						DBOptUpdate dbu = PriseUpdateLog_LOP_MODIFY_COLUMNS2(mlrd);
						System.out.println(dbu.BuildSql());
					}else{
						logger.error("解析日志失败！LOP_MODIFY_COLUMNS未知的context："+mlrd.context+" LSN：" + mlrd.LSN);
						return;
					}
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
						
					}else{
						logger.error("解析日志失败！LOP_DELETE_ROWS未知的context："+mlrd.context+" LSN：" + mlrd.LSN);
						return;
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
		if (mlrd.table.PrimaryKey != null && mlrd.table.PrimaryKey.Fields != null && mlrd.table.PrimaryKey.Fields.size() > 0) {
			for (MsColumn msColumn : mlrd.table.PrimaryKey.Fields) {
				int idx = dbi.Fields.indexOf(msColumn);
				s2 += " and " + MsFunc.BuildSegment(msColumn, dbi.Values.get(idx));
			}
		}
		else{
			//没有主键就根据所有字段生成where
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
	 * 解析一个包含nullMap和数据索引的Update数据块
	 * @param isOldValue  
	 * @param nullMapLen  
	 * @param BufBlock  数据块
	 * @param ValueStartOffset
	 */
	public void PriseMixedUpdateBlock(MsLogRowData mlrd,DBOptUpdate res,boolean isOldValue, int nullMapLength, int ValueStartOffset, byte[] BufBlock)
	{
		//覆盖的nullMap长度
		int OverlapNullMapLen = nullMapLength - (ValueStartOffset - mlrd.table.theFixedLength);
		if (OverlapNullMapLen < 0) {
			//！！！有情况，，特么的都覆盖到fixed数据了
			md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + mlrd.LSN);
			return;
		}
		
		if (BufBlock != null && BufBlock.length >= OverlapNullMapLen) {
			GenericLittleEndianAccessor glea = new GenericLittleEndianAccessor(BufBlock);
			glea.PaddingZeroOnEof = true;
			glea.skip(OverlapNullMapLen);//跳过覆盖的nullMap
			if (glea.available()>0) {
				//索引块大小,这个是数据存储的variant字段索引表
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
		//计算开始更新的列，挨到更新的两个列是放到一块里面的
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
					md.GetOutPut().Error("列索引获取失败！！！");
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
		align4Byte(glea);
		mlrd.r2 = glea.read(elements[2]);  //行主键
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
		int nullMapLength = (mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3;
		int valIdx = glea.getBytesRead();
		//指向var列idx（大于这个值的，就不能通过日志获取东西了，必须根据page页获取原始数据！！
		int varDataIdxOffset = mlrd.table.theFixedLength + 2 + ((mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3);
		
		boolean MustReadPage = false;
		//offsetOfUpdatedCell的第一、二位是索引的开始覆盖位置，（如果等于0 的话，就取后面的数据块值
		int OldOverlapIdxStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 0);//一般情况下，这里取老值没有明显意义，忽略了
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

		if (MustReadPage) {
			//必须读取原始行数据，生成全局更新！！！
			if(!getFullUpdateDataByPrimaryKey(mlrd, res, null, false)){
				return null;
			}
		}else{
			//lucky！！！，可以根据日志解析，更新前后的值
			glea.seek(valIdx,SeekOrigin.soFromBeginning);
			for (int i = 0; i < UpdateRangeCount; i++) {

				byte[] oldValue = glea.read(elements[6 + i * 2]);
				align4Byte(glea);
				byte[] newValue = glea.read(elements[6 + i * 2 + 1]);
				align4Byte(glea);
	
				int OldValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 4 + i * 2);
				int NewValueStartOffset = ArrayUtil.getBytesShort(offsetOfUpdatedCell, 6 + i * 2);
				
				if (OldOverlapIdxStartOffset == 0) {
					//nullmap等信息在values里面
					PriseMixedUpdateBlock(mlrd, res, true, nullMapLength, OldValueStartOffset, oldValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (OldOverlapIdxStartOffset - mlrd.table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//！！！有情况，，特么的都覆盖到fixed数据了
						md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + mlrd.LSN);
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
					//nullmap等信息在values里面
					PriseMixedUpdateBlock(mlrd,res,  true, nullMapLength, NewValueStartOffset, newValue);
				}else{
					int OverlapNullMapLen = nullMapLength - (NewOverlapIdxStartOffset - mlrd.table.theFixedLength);
					if (OverlapNullMapLen < 0) {
						//！！！有情况，，特么的都覆盖到fixed数据了
						md.GetOutPut().Error("解析Update日志出错！！覆盖到fixed数据：LSN：" + mlrd.LSN);
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
			//TODO:!!!!!!!!没有主键，艹艹艹
			logger.warn("数据库："+md.Db.GetFullDbName()+"，表:"+ mlrd.table.GetFullName()+"无主键！更新操作取消！！！！");
			return null;
		}else{
			int nullMapLength = (mlrd.table.getNullMapSorted_Columns().length + 7) >>> 3;
			int varDataIdxOffset = mlrd.table.theFixedLength + 2 + nullMapLength;
			if (mlrd.offset > varDataIdxOffset) {
				//しまった、ここに入ってなら。リアデータを読む
				if(!getFullUpdateDataByPrimaryKey(mlrd, res, null, true)){
					return null;
				}
			}else if(mlrd.offset < mlrd.table.theFixedLength){
				//修改范围是固定长度字段
			    for (MsColumn mColumn : mlrd.table.getNullMapSorted_Columns()) {
					if (mColumn.leaf_pos > 0) {
						if (mlrd.offset == mColumn.theRealPosition) {
							//找到列
							String TmpStr = MsFunc.BuildSegment(mColumn, mlrd.r0);
							res.OldValues.add(TmpStr);
							TmpStr = MsFunc.BuildSegment(mColumn, mlrd.r1);
							res.NewValues.add(TmpStr);
							
							InitUpdatePrimarykey(mlrd, res);
						}else if (mlrd.offset > mColumn.theRealPosition && mlrd.offset < mColumn.theRealPosition + mColumn.max_length){
						    //在列值范围内！，需要访问数据库查找真实数据
							if(!getFullUpdateDataByPrimaryKey(mlrd, res, mColumn, false)){
								return null;
							}
							break;
						}
					}
				}
			}else{
				//覆盖了nullMap
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
		//16定长主键列，36变长主键列
		if (prefix!=0x16 && prefix!=0x36) {
			logger.error("更新日志警告："+mlrd.table.GetFullName()+"r2前缀异常！！！！！LSN:" + mlrd.LSN);
		}
		boolean fstbcl = true;
		//TODO:主键分明不能为null，为什么还有nullMap？？？？
		int nullMapLength = (mlrd.table.getSorted_PrimaryColumns().length + 7) >>> 3;
		short[] idxs = null;
		int varColPosition = 0;
		for (MsColumn mColumn : mlrd.table.getSorted_PrimaryColumns()) {
			byte[] datas;
			if (mColumn.leaf_pos > 0) {
				//定长列
				datas = glea_key.read(mColumn.max_length);
			}else{
				//变长列
				if (fstbcl) {
					fstbcl = false;
					//第一个变长列前面会有附加数据
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
					logger.error("更新日志警告："+mlrd.table.GetFullName()+"r2前缀异常！！！！LSN:" + mlrd.LSN);
				}
				int datalen = dataEndOffset - glea_key.getBytesRead();
				datas = glea_key.read(datalen);
				varColPosition++;
			}
			String TmpStr = MsFunc.BuildSegment(mColumn, datas);
			res.KeyField.add(TmpStr);
		}
	}
	private String getFullUpdateDataFields(MsTable mTable, boolean JustVarColumn){
		String res = ""; 
		for (MsColumn msColumn : mTable.GetFields()) {
			if (!isSkipColType(msColumn)) {
				if (!JustVarColumn || msColumn.leaf_pos < 0) {
					res+= ",["+msColumn.Name+"]";
				}
			}
		}
		if (!res.isEmpty()) {
			return res.substring(1);
		}else 
			return "";
	}
	
	@SuppressWarnings("unused")
	@Deprecated
	private boolean getRowDataFromDbcc(MsLogRowData mlrd) {
		//!!!不能通过dbcc去获取原始数据!!!!
		//已知3种情况会得到错误数据
		//1.如果原始行被删除，获取的将是其它行数据
		//2.如果写入了聚合列，Slot将被重新排序，得到的也会是错误值！
		//3.如果表被重建.......数据可能会被分配到其它页
		
//		try {
//			Statement statement = md.Db.conn.createStatement();
//			String Sql = String.format("dbcc page (%s,%d,%d,1)with tableresults", md.getDB().dbName, mlrd.pageFID, mlrd.pagePID);
//			ResultSet Rs = statement.executeQuery(Sql);
//			while (Rs.next()) {
//			}
//			Rs.close();
//			statement.close();
//			return true;
//		} catch (SQLException e) {
//			logger.error("读取数据库原始数据失败！" + mlrd.LSN, e);
//		}
		return false;
	}
	
	private String getrsColValueString(ResultSetMetaData rsmd, ResultSet Rs, int i) throws SQLException{
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
		return TStr;
	}
	
	private boolean getFullUpdateDataByPrimaryKey(MsLogRowData mlrd, DBOptUpdate res, MsColumn mColumn, boolean JustVarColumn){
		InitUpdatePrimarykey(mlrd,res);
		String WhereKey = "";
		for (String string : res.KeyField) {
			WhereKey += " and " + string;
		}
		WhereKey = WhereKey.substring(5);
		
		String SelectFields;
		if (mColumn == null) {
			SelectFields = getFullUpdateDataFields(mlrd.table, JustVarColumn);
		}else{
			SelectFields = mColumn.getSafeName();
		}
		
		try {
			Statement statement = md.Db.conn.createStatement();
			String Sql = String.format("SELECT %s FROM %s WHERE %s", SelectFields, mlrd.table.GetFullName(), WhereKey);
			ResultSet Rs = statement.executeQuery(Sql);
			if (!Rs.next()) {
				logger.error("获取更新数据失败！行数据不存在！LSN:" + mlrd.LSN);
				return false;
			}
			ResultSetMetaData rsmd = Rs.getMetaData();
			for (int i = 1; i <= rsmd.getColumnCount(); i++) {
				String TStr = getrsColValueString(rsmd, Rs, i);
				res.NewValues.add(TStr);
			}
			Rs.close();
			statement.close();
			return true;
		} catch (SQLException e) {
			logger.error("读取数据库日志失败！", e);
		}
		return false;
		
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
			case MsTypes.SQL_VARIANT:
			case MsTypes.XML:
			case MsTypes.TIMESTAMP://这种类型的值不能直接写入数据库
			return true;
		default:
			return false;
		}
	}
	
	/**
	 * 能够作为where条件的字段类型
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
		//case MsTypes.TEXT:  //虽然可以作为条件，但是这个字段内容比较多，不安全
		//case MsTypes.NTEXT:
		//case MsTypes.REAL:  //内容为不安全的“近似”值.
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
