package mak.capture;

import java.nio.charset.Charset;
import java.sql.Connection;

import mak.capture.log.Output;

public abstract class DBDatabase {
	protected boolean Connectioned = false; 
	protected Output output = null;
	public Connection conn = null;
	public Charset charset;	
	
	public abstract DataBaseType dbType();
	
	public abstract String GetFullDbName();
	
	public boolean CheckDBState() {
		if (output == null) {
			return false;
		}
		if (conn == null) {
			output.Error("Miss Connection!");
			return false;
		}
		return true;
	}
	public boolean IsConnectioned(){
		return Connectioned;
	}
}
