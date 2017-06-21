package mak.capture.mssql;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;

import org.apache.log4j.Logger;

import mak.capture.DBLogPicker;
import mak.capture.log.OutPutMgr;
import mak.tools.StringUtil;
import mak.triPart.KafkaLogDataProducer;
import mak.triPart.zk;

public class MsLogPicker implements DBLogPicker   {
	private static Logger logger = Logger.getLogger(MsLogPicker.class); 
	private volatile boolean flag = false;  	
	private String ConnStr;
	private MsDict md;
	private String LSN = "00000021:00000129:0001";
	private KafkaLogDataProducer logProducer = new KafkaLogDataProducer();
	private zk zkClient = null;
	private String jobKey = "";
	/**
	 * 待完成的集合
	 * 每LOP_BEGIN_XACT创建一个元素，LOP_COMMIT_XACT
	 */
	private HashMap<String, MsTransPkg> TempTransList = new HashMap<>();
	
	public MsLogPicker(zk zkClient){
		this.zkClient = zkClient;
	}
	
	public boolean init(String jobKey, MsDict md){
		this.md = md;
		this.jobKey = jobKey;
		logProducer.init(this.jobKey);
		zkClient.initCfg(this.jobKey);
		return true;
	}
	
	public boolean init(String jobKey){
		this.jobKey = jobKey;
		logProducer.init(this.jobKey);
		zkClient.initCfg(this.jobKey);
		
		ConnStr = zkClient.getConStr();
		String host = StringUtil.getXmlValueFromStr(ConnStr, "host");
		String usrid = StringUtil.getXmlValueFromStr(ConnStr, "usrId");
		String pswd = StringUtil.getXmlValueFromStr(ConnStr, "pswd");
		String dbName = StringUtil.getXmlValueFromStr(ConnStr, "dbName");
		try{
			MsDatabase _Db = new MsDatabase(new OutPutMgr(), host, usrid, pswd, dbName);
			md = new MsDict(_Db);
			return md.CheckDBState();
//			if (md.CheckDBState()){
//				return md.RefreshDBDict();
//			}else{
//				return false;
//			}
		}catch(Exception e){
			e.printStackTrace();
			return false;
		}
	}
	
	private void ProducerTheData(MsTransPkg mPkg){
		//TODO:发送数据到MQ Server
		//logProducer.SendData(mPkg);
		
		MsTransPkgPrise MTPP = new MsTransPkgPrise(mPkg, md);			
		MTPP.start();
	}
	
	public String getLogSql(String start, String end){
		String SqlStr = "Select (Select top 1 object_id from sys.partitions partitions INNER JOIN sys.allocation_units allocunits ON partitions.hobt_id = allocunits.container_id ";
		SqlStr += " where allocunits.allocation_unit_id = [AllocUnitId]) as objid,[RowFlags] as rowflag,[Transaction SID] as sid,[End Time] as transtime, ";
		SqlStr += " [transaction name] as transname,[Transaction ID] as transid,[Current LSN] as lsn,[PAGE ID] as pageid,[Slot ID] as slotid,operation,context, ";
		SqlStr += " (case when (operation in('LOP_MODIFY_HEADER')) then Description else null end) as note,[Offset in Row] as offset, ";
		SqlStr += " [RowLog Contents 0] as r0,[RowLog Contents 1] as r1,[RowLog Contents 2] as r2,[RowLog Contents 3] as r3,[RowLog Contents 4] as r4 , ";
		SqlStr += " (case when (operation in('LOP_MODIFY_COLUMNS')) then [Log Record] else null end) as [log],[Transaction Begin]  ";
		if (end==null|| end.isEmpty()) {
			SqlStr += " from ::fn_dblog ('0x"+start+"',null) ";
		}else{
			SqlStr += " from ::fn_dblog ('0x"+start+"','0x"+end+"') ";
		}
		SqlStr += " where (operation in('LOP_INSERT_ROWS','LOP_DELETE_ROWS','LOP_MODIFY_ROW','LOP_MODIFY_COLUMNS') ";
		SqlStr += " and context in('LCX_HEAP','LCX_CLUSTERED','LCX_MARK_AS_GHOST','LCX_TEXT_MIX','LCX_REMOVE_VERSION_INFO') ";
		SqlStr += " and description <> 'COMPENSATION' ";
		SqlStr += " )or (operation in('LOP_BEGIN_XACT','LOP_COMMIT_XACT','LOP_ABORT_XACT') and context='LCX_NULL')";
		return SqlStr;
	}
	
	public MsTransPkg ReadDBLogPkg(MsLogRowData TransMlrd){
		try {
			Statement statement = md.Db.conn.createStatement();
			ResultSet Rs = statement.executeQuery(getLogSql(TransMlrd.TransactionBegin, TransMlrd.LSN));
			MsTransPkg mtp = new MsTransPkg();
			while (Rs.next()) {
				String transId = Rs.getString(6);
				if (transId.equals(TransMlrd.transId)) {
					MsLogRowData mlrd = new MsLogRowData();
					mlrd.obj_id = Rs.getInt(1);
					mlrd.transtime = Rs.getString(4);
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
					mlrd.TransactionBegin = Rs.getString(20);
					if ("LOP_BEGIN_XACT".equals(mlrd.operation)) {
						mtp.BeginLSN = mlrd.LSN;
						mtp.TransName = mlrd.transname;	
					} else if ("LOP_COMMIT_XACT".equals(mlrd.operation)) {			
						mtp.EndLSN = mlrd.LSN;
					}
					mtp.actions.add(mlrd);
				}
			}
			Rs.close();
			statement.close();
			return mtp;
		} catch (SQLException e) {
			logger.error("读取数据库日志失败！", e);
		}
		return null;
	}

	public void ReadDBLog(){
		try {
			if (LSN.equals("")) {
				LSN = zkClient.getLSN();
			}  
			Statement statement = md.Db.conn.createStatement();
			ResultSet Rs = statement.executeQuery(getLogSql(LSN, null));
			Rs.next();
			while (Rs.next()) {
				MsLogRowData mlrd = new MsLogRowData();
				mlrd.obj_id = Rs.getInt(1);
				mlrd.transtime = Rs.getString(4);
				mlrd.transname = Rs.getString(5);
				mlrd.transId = Rs.getString(6);
				mlrd.LSN = Rs.getString(7);
				mlrd.setPageId(Rs.getString(8));
				mlrd.slotid = Rs.getInt(9);
				mlrd.operation = Rs.getString(10);
				mlrd.context = Rs.getString(11);
				mlrd.offset = Rs.getInt(13);
				mlrd.TransactionBegin = Rs.getString(20);
				
				MsTransPkg mtp = TempTransList.get(mlrd.transId);
				if (mtp == null) {
					if ("LOP_BEGIN_XACT".equals(mlrd.operation)) {
						mtp = new MsTransPkg();
						mtp.BeginLSN = mlrd.LSN;
						mtp.TransName = mlrd.transname;
						TempTransList.put(mlrd.transId, mtp);
					}else{
						//不是事务的开始，且临时列表中不存在
						//忽略未知开始的数据,根据最后的LOP_COMMIT_XACT修改数据
						if ("LOP_COMMIT_XACT".equals(mlrd.operation)) {
							//，如果需要追踪可以根据 LOP_COMMIT_XACT的 transbegin lsn取值
							MsTransPkg mPkg = ReadDBLogPkg(mlrd);
							ProducerTheData(mPkg);
							zkClient.setLSN(mlrd.LSN);	
						}
						continue;
					}
				}
				mlrd.r0 = Rs.getBytes(14);
				mlrd.r1 = Rs.getBytes(15);
				mlrd.r2 = Rs.getBytes(16);
				mlrd.r3 = Rs.getBytes(17);
				mlrd.r4 = Rs.getBytes(18);
				mlrd.LogRecord = Rs.getBytes(19);
				mtp.addAction(mlrd);
				
				if ("LOP_COMMIT_XACT".equals(mlrd.operation)) {
					TempTransList.remove(mlrd.transId);					
					mtp.EndLSN = mlrd.LSN;
					 
					ProducerTheData(mtp);
					//在zookeeper上保存lsn
					zkClient.setLSN(mlrd.LSN);			
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
