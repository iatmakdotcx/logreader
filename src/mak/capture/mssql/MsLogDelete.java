package mak.capture.mssql;


public class MsLogDelete extends MsLogInsert {
	//delete�����ݻ���r0�д��ԭʼ��ֵ����ʽ��insertһ������������̳�insert
	
	@Override
	public String BuildSql(){
		if (Fields.isEmpty()) {
			if (!PriseInsertLog_LOP_INSERT_ROWS()) {
				return "";
			}
		}
		String s2 = "";
		if (table.PrimaryKey != null) {
			//�����������������͸�����������where
			for (MsColumn msColumn : table.PrimaryKey.Fields) {
				int idx = Fields.indexOf(msColumn);
				if (idx == -1) {
					md.GetOutPut().Warning("��־�����쳣��Delete����ͼɾ��NULL����ֵ����LSN" + LSN);
					s2 += " and [" + Fields.get(idx).Name + "]=NULL";
				}else{
					s2 += " and " + MsFunc.BuildSegment(Fields.get(idx), Values.get(idx));
				}
			}
		}else{
			//û�������͸��������ֶ�����where
			for (int i = 0; i < Fields.size(); i++) {
				s2 += " and " + MsFunc.BuildSegment(Fields.get(i), Values.get(i));
			}
			s2 = s2.substring(5);
		}
		
		String result = String.format("DELETE %s where %s", table.GetFullName(), s2);
		return result;
	}
}
