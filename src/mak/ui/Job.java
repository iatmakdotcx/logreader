package mak.ui;

import mak.capture.DBLogPicker;
import mak.capture.mssql.MsLogPicker;
import mak.tools.StringUtil;

public class Job {
	public String aJobStr; 
	
	private DBLogPicker Logpicker = null;
	
	public Job(String aJobStr){
		this.aJobStr = aJobStr;
		CreateSrc();
		CreateDst();
	}
	
	public boolean CreateSrc() {
		String srcStr = StringUtil.getXmlValueFromStr(aJobStr, "src"); 
		String srcType = StringUtil.getXmlValueFromStr(srcStr, "type"); 
		if (srcType.equals("DB")) {
			String DBType = StringUtil.getXmlValueFromStr(srcStr, "subtype");
			if (DBType.equals("mssql")) {
				Logpicker = new MsLogPicker(srcStr);
			}else if (DBType.equals("mysql")) {
				//TODO:  mysql picker
				throw new UnsupportedOperationException("Not supported yet."); 
			}else if (DBType.equals("oracle")) {
				//TODO:  oracle picker
				throw new UnsupportedOperationException("Not supported yet."); 
			}else{
				throw new UnsupportedOperationException("Not supported yet."); 
			}
			
		}else if (srcType.equals("kafka")) {
			//TODO:Read From Kafka
			throw new UnsupportedOperationException("Not supported yet."); 
		}else{
			throw new UnsupportedOperationException("Not supported yet."); 
		}
		
		return true;
	}
	
	public boolean CreateDst() {
		String dstStr = StringUtil.getXmlValueFromStr(aJobStr, "dst"); 
		String dstType = StringUtil.getXmlValueFromStr(dstStr, "type"); 
		if (dstType.equals("log")) {
			String logType = StringUtil.getXmlValueFromStr(dstStr, "subtype");
			if (logType.equals("sql")) {
				
			}else if (logType.equals("bin")){
				throw new UnsupportedOperationException("Not supported yet."); 
			}
		}else if (dstType.equals("kafka")){ 
			String logType = StringUtil.getXmlValueFromStr(dstStr, "subtype");
			//TODO:Write to Kafka
			if (logType.equals("sql")) {
				throw new UnsupportedOperationException("Not supported yet."); 
			}else if (logType.equals("bin")){
				throw new UnsupportedOperationException("Not supported yet."); 
			}
		}else{
			throw new UnsupportedOperationException("Not supported yet."); 
		}
		
		
		return true;
	}
	
	
	public void Stop(){
		Logpicker.Terminate();		
	}
	
	public boolean Start() {
		if(Logpicker.init()){
			Thread thread = new Thread(Logpicker, "Logpicker");  
			thread.start();
		}
		
		return true;
	}
	
}
