package mak.capture.mssql;

import java.util.Date;

public class MsLogRowData {
	public MsDict md;
	public MsTable table;
	
	public int obj_id;
	public Date transtime;
	public String transname;
	public String transId;
	
	public String LSN;
	
	public int pageFID = -1;
	public int pagePID = -1;
	public int slotid = -1;
	
	public String operation;
	public String context;
	
	public int Offset_in_Row = 0;	
	
	public int offset = -1;
	
	public byte[] r0;  //  old value
	public byte[] r1;  //  new Value
	public byte[] r2;  //  PrimaryKey
	public byte[] r3;  
	public byte[] r4;  
	
	public byte[] LogRecord;  //  LOP_MODIFY_COLUMNS的数据全从这取
	
	public void setPageId(String pageId) {
		if (pageId != null && !pageId.isEmpty()) {
			String[] PageIdarr = pageId.split(":");
			if (PageIdarr.length == 2) {
				pageFID = Integer.parseInt(PageIdarr[0], 16);
				pagePID = Integer.parseInt(PageIdarr[1], 16);
			}
		}
	}
}
