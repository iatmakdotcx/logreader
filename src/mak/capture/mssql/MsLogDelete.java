package mak.capture.mssql;


public class MsLogDelete extends MsLogInsert {
	//delete的数据会在r0中存放原始的值，格式和insert一样，所以这个继承insert
	
	@Override
	public String BuildSql(){
		if (Fields.isEmpty()) {
			if (!PriseInsertLog_LOP_INSERT_ROWS()) {
				return "";
			}
		}
		String s2 = "";
		if (table.PrimaryKey != null) {
			//如果表有主键，这个就根据主键生成where
			for (MsColumn msColumn : table.PrimaryKey.Fields) {
				int idx = Fields.indexOf(msColumn);
				if (idx == -1) {
					md.GetOutPut().Warning("日志解析异常：Delete：试图删除NULL主键值！！LSN" + LSN);
					s2 += " and [" + Fields.get(idx).Name + "]=NULL";
				}else{
					s2 += " and " + MsFunc.BuildSegment(Fields.get(idx), Values.get(idx));
				}
			}
		}else{
			//没有主键就根据所有字段生成where
			for (int i = 0; i < Fields.size(); i++) {
				s2 += " and " + MsFunc.BuildSegment(Fields.get(i), Values.get(i));
			}
			s2 = s2.substring(5);
		}
		
		String result = String.format("DELETE %s where %s", table.GetFullName(), s2);
		return result;
	}
}
