package mak.capture.mssql;

import java.io.FileOutputStream;
import java.io.ObjectOutputStream;
import java.io.Serializable;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.LinkedList;

import mak.capture.DBLogPicker;
import mak.capture.log.OutputMgr;
import mak.tools.StringUtil;

public class MsLogPicker implements DBLogPicker   {

	public volatile boolean flag = false;  	
	private String ConnStr;
	private MsDict md;
	public String LSN = "00000021:00000129:0001";
	
	
	/**
	 * 待完成的集合
	 * 每LOP_BEGIN_XACT创建一个元素，LOP_COMMIT_XACT
	 */
	private HashMap<String, MsTransPkg> TempTransList = new HashMap<>();
	/**
	 * 正式的已经打包好的一个事务块
	 */
	private LinkedList<MsTransPkg> TransList = new LinkedList<>();	
	//private BlockingQueue<MsTransPkg> TransList = new ArrayBlockingQueue<>(1);
	
	public MsLogPicker(String ConnStr){
		this.ConnStr = ConnStr;
	}
	
	public boolean init(){
		String host = StringUtil.getXmlValueFromStr(ConnStr, "host");
		String usrid = StringUtil.getXmlValueFromStr(ConnStr, "usrId");
		String pswd = StringUtil.getXmlValueFromStr(ConnStr, "pswd");
		String dbName = StringUtil.getXmlValueFromStr(ConnStr, "dbName");
		String logtype = StringUtil.getXmlValueFromStr(ConnStr, "logtype");
		try{
			MsDatabase _Db = new MsDatabase(new OutputMgr(logtype), host, usrid, pswd, dbName);
			md = new MsDict(_Db);
			if (md.CheckDBState()){
				return md.RefreshDBDict();
			}else{
				return false;
			}
		}catch(Exception e){
			e.printStackTrace();
			return false;
		}
	}

	public synchronized MsTransPkg getTransListItem(){
		if (TransList.isEmpty()) {
			return null;
		}
		return TransList.getFirst();
	}
	
	public void saveAll(){
		try    
        {     
           ObjectOutputStream o = new ObjectOutputStream( new FileOutputStream("logInfo.out"));     
           o.writeObject(TempTransList);   //写入数据  
           o.close();     
        }catch(Exception e) {  
           e.printStackTrace();  
        }  
	}
	
	public void ReadDBLog(){
		try {
			Statement statement = md.Db.conn.createStatement();
			String SqlStr = "Select top 1000 (Select top 1 object_id from sys.partitions partitions INNER JOIN sys.allocation_units allocunits ON partitions.hobt_id = allocunits.container_id ";
			SqlStr += " where allocunits.allocation_unit_id = [AllocUnitId]) as objid,[RowFlags] as rowflag,[Transaction SID] as sid,[End Time] as transtime, ";
			SqlStr += " [transaction name] as transname,[Transaction ID] as transid,[Current LSN] as lsn,[PAGE ID] as pageid,[Slot ID] as slotid,operation,context, ";
			SqlStr += " (case when (operation in('LOP_MODIFY_HEADER')) then Description else null end) as note,[Offset in Row] as offset, ";
			SqlStr += " [RowLog Contents 0] as r0,[RowLog Contents 1] as r1,[RowLog Contents 2] as r2,[RowLog Contents 3] as r3,[RowLog Contents 4] as r4 , ";
			SqlStr += " (case when (operation in('LOP_MODIFY_COLUMNS')) then [Log Record] else null end) as [log]  ";
			SqlStr += " from ::fn_dblog ('0x"+LSN+"',null) ";
			SqlStr += " where (operation in('LOP_INSERT_ROWS','LOP_DELETE_ROWS','LOP_MODIFY_ROW','LOP_MODIFY_COLUMNS') ";
			SqlStr += " and context in('LCX_HEAP','LCX_CLUSTERED','LCX_MARK_AS_GHOST','LCX_TEXT_MIX','LCX_REMOVE_VERSION_INFO') ";
			SqlStr += " and description <> 'COMPENSATION' ";
			SqlStr += " )or (operation in('LOP_BEGIN_XACT','LOP_COMMIT_XACT','LOP_ABORT_XACT') and context='LCX_NULL')";
			ResultSet Rs = statement.executeQuery(SqlStr);
			while (Rs.next()) {
				MsLogRowData mlrd = new MsLogRowData();
				mlrd.obj_id = Rs.getInt(1);
				mlrd.transtime = Rs.getTimestamp(4);
				mlrd.transname = Rs.getString(5);
				mlrd.transId = Rs.getString(6);
				mlrd.LSN = Rs.getString(7);
				mlrd.setPageId(Rs.getString(8));
				mlrd.slotid = Rs.getInt(9);
				mlrd.operation = Rs.getString(10);
				mlrd.context = Rs.getString(11);
				mlrd.offset = Rs.getInt(13);
				mlrd.r0 = Rs.getBytes(14);
				mlrd.r1 = Rs.getBytes(15);
				mlrd.r2 = Rs.getBytes(16);
				mlrd.r3 = Rs.getBytes(17);
				mlrd.r4 = Rs.getBytes(18);
				mlrd.LogRecord = Rs.getBytes(19);
				
				MsTransPkg mtp = TempTransList.get(mlrd.transId);
				if (mtp == null) {
					if (mlrd.operation.equals("LOP_BEGIN_XACT")) {
						mtp = new MsTransPkg();
						TempTransList.put(mlrd.transId, mtp);
					}else{
						//不是事务的开始，且临时列表中不存在
						//TODO:忽略未知开始的数据
						continue;
					}
				}
				mtp.addAction(mlrd);
				
				if (mlrd.operation.equals("LOP_COMMIT_XACT")) {
					TempTransList.remove(mlrd.transId);
					TransList.add(mtp);		
					
					while(TransList.size() > 1000){
						try {
							Thread.sleep(1000);
						} catch (InterruptedException e) {
							
						}
					}
				}
				LSN = mlrd.LSN;
			}
			Rs.close();
			statement.close();

		} catch (SQLException e) {
			e.printStackTrace();
		}
		
	}
	@Override
	public void run() {
		// TODO MsLogPicker running
		md.GetOutPut().Info(" MsLogPicker running......");
		while(!flag){
		
			ReadDBLog();
			try {
				Thread.sleep(1000);
			} catch (InterruptedException e) {
			}
		}
	}

	@Override
	public void Terminate() {
		flag = false;		
	}

	@Override
	public boolean isTerminated() {
		return flag;
	}
}
