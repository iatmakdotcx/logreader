package mak.capture.data;

import java.util.ArrayList;


public class DBOptUpdate implements DBOpt {
	public int obj_id;
	public String tableName;
	
	public ArrayList<String> OldValues= new ArrayList<String>();
	public ArrayList<String> NewValues = new ArrayList<String>();
	public ArrayList<String> KeyField = new ArrayList<String>();
	
	public String BuildSql(){
		String s2 = "";
		for (String string : NewValues) {
			s2 += "," + string;
		}
		s2 = s2.substring(1);
		
		String s3 = "";
		for (String string : KeyField) {
			s3 += " and " + string;
		}
		s3 = s3.substring(5);
		
		String Result = String.format("UPDATE %s SET %s WHERE %s", tableName,s2,s3);
		return Result;
	}
	
}
