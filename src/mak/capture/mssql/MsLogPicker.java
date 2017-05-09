package mak.capture.mssql;

import mak.capture.log.ConsoleOutput;

public class MsLogPicker {
	
	private MsDict md;
	
	public MsLogPicker(){
		MsDatabase _Db = new MsDatabase(new ConsoleOutput(), "192.168.0.61","sa","xxk@20130220","MaktestDB");
		
		md = new MsDict(_Db);
		if (md.CheckDBState()){
			md.RefreshDBDict();
		}
		
	}
	
	public void init(){
		
	}
}
