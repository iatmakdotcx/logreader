package mak.capture.data;

import java.util.ArrayList;

import mak.capture.mssql.MsColumn;
import mak.capture.mssql.MsFunc;
import mak.capture.mssql.MsLogRowData;

public class DBOptDelete implements DBOpt {
	public int obj_id;
	public String tableName;
	
	public ArrayList<MsColumn> Fields= new ArrayList<>();
	public ArrayList<byte[]> Values= new ArrayList<>();

	public String BuildDeleteSql(MsLogRowData mlrd){
		String s2 = "";
		if (mlrd.table.PrimaryKey != null && mlrd.table.PrimaryKey.Fields != null && mlrd.table.PrimaryKey.Fields.size() > 0) {
			for (MsColumn msColumn : mlrd.table.PrimaryKey.Fields) {
				int idx = Fields.indexOf(msColumn);
				s2 += " and " + MsFunc.BuildSegment(msColumn, Values.get(idx));
			}
		}
		else{
			//没有主键就根据所有字段生成where
			for (int i = 0; i < Fields.size(); i++) {
				if (MsFunc.canBeWhereSegColType(Fields.get(i))) {
					s2 += " and " + MsFunc.BuildSegment(Fields.get(i), Values.get(i));
				}
			}
		}
		s2 = s2.substring(5);
		return String.format("DELETE %s where %s", tableName, s2);
	}
	
}
