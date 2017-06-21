package mak.capture;

import mak.capture.log.Output;

public abstract class DBDict {
	public DBDatabase Db;

	public DBDict(DBDatabase _Db){
		this.Db = _Db;
	}

	public Output GetOutPut(){
		return Db == null ? null : Db.output;
	}
	
	public boolean CheckDBState() {
		 return Db.CheckDBState();
	}
	
	public abstract boolean RefreshDBDict();
}
