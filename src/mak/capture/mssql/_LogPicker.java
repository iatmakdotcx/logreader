package mak.capture.mssql;

import mak.capture.log.ConsoleOutput;

public class _LogPicker {
	
	private MsDict md;
	
	public MsMain(){
		MsSqlDatabase _Db = new MsSqlDatabase(new ConsoleOutput(), "192.168.0.61","sa","xxk@20130220","MaktestDB");
		
		md = new MsDict(_Db);
		if (md.CheckDBState()){
			md.RefreshDBDict();
		}
		
	}
	public void init(){
		
	}
}
