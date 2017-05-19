package mak.capture.data;

import java.util.ArrayList;

import mak.capture.mssql.MsColumn;
import mak.capture.mssql.MsFunc;

public class DBOptInsert implements DBOpt {
	public int obj_id;
	public String tableName;
	
	public ArrayList<MsColumn> Fields= new ArrayList<>();
	public ArrayList<byte[]> Values= new ArrayList<>();
	
	public String BuildSql(){
		String s1 = "";
		String s2 = "";
		
		for (int i = 0; i < Fields.size(); i++) {
			s1 += ",[" + Fields.get(i).Name + "]";
			s2 += "," + MsFunc.BuildSegmentValue(Fields.get(i), Values.get(i));
		}
		if (s1.isEmpty()||s2.isEmpty()) {
			return "";
		}
		s1 = s1.substring(1);
		s2 = s2.substring(1);
		String result = String.format("INSERT into %s(%s) values(%s)", tableName, s1, s2);
		return result;
	}
}
