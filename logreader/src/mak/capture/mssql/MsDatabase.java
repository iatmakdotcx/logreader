package mak.capture.mssql;

import java.nio.charset.Charset;
import java.sql.DriverManager;

import mak.capture.DBDatabase;
import mak.capture.DataBaseType;
import mak.capture.log.Output;
import mak.tools.StringUtil;

public class MsDatabase extends DBDatabase {
	public static final String driver = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
	public int dbVersion = 0;
	public int dbSubVersion = 0;  //  <>0则是R2版本
	public String host;
	public String user;
	public String Pwd;
	public String dbName;
	
	public MsDatabase(Output output, String Host, String UserId, String PassWd, String DbName){
		this.output = output;
		this.host = Host;
		this.user = UserId;
		this.Pwd = PassWd;
		this.dbName = DbName;
		InitConnection();
	}	
	
	@Override
	public DataBaseType dbType() {
		return DataBaseType.MSSQL;
	}

	@Override
	public String GetFullDbName(){
		return host + "<" + dbName + ">";
	}
	
	public boolean InitConnection(){
		if (IsConnectioned()) {
			return true;
		}
		String url = String.format("jdbc:sqlserver://%s;databaseName=%s", host, dbName);
		try {
            Class.forName(driver);
            conn = DriverManager.getConnection(url, user, Pwd);
            Connectioned = true;
            return IsConnectioned();
        } catch (Exception e) {
        	output.Error("初始化数据库连接失败！"+StringUtil.getStackTrace(e));
        	return false;
        }
	}	
	public void setdbVersion(String verStr){
		if (verStr == null) {
			return;
		}	
		String[] VerArr = verStr.split("."); 
		if (VerArr.length < 2) {
			return;
		}
		try{
			dbVersion = Integer.parseInt(VerArr[0]);
			dbSubVersion = Integer.parseInt(VerArr[1]);
		}catch(Exception e){
		}
	}
	
	public void SetCharSet(int CodePage){
		charset = Charset.forName("Cp"+CodePage);
	}
	
}
