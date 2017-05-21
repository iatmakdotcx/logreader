package mak.server;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;

import mak.capture.log.OutPutMgr;
import mak.capture.mssql.MsDatabase;
import mak.capture.mssql.MsDict;
import mak.capture.mssql.MsLogPicker;
import mak.capture.mssql.MsLogRowData;
import mak.capture.mssql.MsTransPkg;
import mak.capture.mssql.MsTransPkgPrise;
import mak.tools.StringUtil;
import mak.triPart.zk;

public class MssqlSingleJob {
	private static Logger logger = Logger.getLogger(MsLogPicker.class);
	
	public zk zkClient = new zk(); 
	private String jobkey = "";
	private String LSN = "";
	private MsDict md;
	
	public static void main(String[] args) {
		PropertyConfigurator.configure("config/log4j.properties");
		String jobkey = "20170518151930566";
		String LSN = "00000029:000000f7:0003";
		MssqlSingleJob job = new MssqlSingleJob(jobkey, LSN);
		job.run();
		
	}
	MssqlSingleJob(String jobkey, String LSN){
		this.jobkey = jobkey;
		this.LSN = LSN;		
	}
	
	private void doJob(){
		try {
			Statement statement = md.Db.conn.createStatement();
			String SqlStr = "select [Transaction ID],[Transaction Begin],Operation";
			SqlStr += " from ::fn_dblog ('0x"+LSN+"','0x"+LSN+"') ";
			ResultSet Rs = statement.executeQuery(SqlStr);
			if (!Rs.next()) {
				logger.error("读取数据库日志失败！LSN无效");
				return;
			}
			if(!Rs.getString(3).equals("LOP_COMMIT_XACT"))
			{
				logger.error("读取数据库日志失败！LSN不是LOP_COMMIT_XACT");
				return;
			}
			MsLogRowData TransMlrd = new MsLogRowData();
			TransMlrd.LSN = LSN;
			TransMlrd.transId = Rs.getString(1);
			TransMlrd.TransactionBegin = Rs.getString(2);
			
			MsLogPicker logPicker = new MsLogPicker();
			logPicker.init(jobkey, md);
			MsTransPkg mpkg = logPicker.ReadDBLogPkg(TransMlrd);
			
			MsTransPkgPrise MTPP = new MsTransPkgPrise(mpkg, md);			
			MTPP.start();
			
		} catch (SQLException e) {
			logger.error("读取数据库日志失败！", e);
		}
	}
	

	void run(){
		zkClient.initCfg(jobkey);
		String ConStr = zkClient.getConStr();
		if (ConStr.isEmpty()) {
			logger.error("未找到jobkey="+jobkey+"的配置文件！");
			return;
		}
		
	    String srcStr = StringUtil.getXmlValueFromStr(ConStr, "src");
        String srcType = StringUtil.getXmlValueFromStr(srcStr, "type");
        if (srcType.equals("DB")) {
            String DBType = StringUtil.getXmlValueFromStr(srcStr, "subtype");
            if (DBType.equals("mssql")) {
        		String host = StringUtil.getXmlValueFromStr(srcStr, "host");
        		String usrid = StringUtil.getXmlValueFromStr(srcStr, "usrId");
        		String pswd = StringUtil.getXmlValueFromStr(srcStr, "pswd");
        		String dbName = StringUtil.getXmlValueFromStr(srcStr, "dbName");
        		MsDatabase _Db = new MsDatabase(new OutPutMgr(), host, usrid, pswd, dbName);
    			md = new MsDict(_Db);
    			if (md.CheckDBState() && md.RefreshDBDict()){
    				doJob();    				
    			}else{
    				throw new UnsupportedOperationException("数据库初始化失败！");
    			}
            } else {
                throw new UnsupportedOperationException("Not supported yet.");
            }
        } else {
            throw new UnsupportedOperationException("Not supported yet.");
        }
	}
}
