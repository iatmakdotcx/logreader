package mak.capture.mssql;

import java.util.ArrayList;
import java.util.HashMap;

import mak.capture.DBTable;

public class MsTable extends DBTable {
	private MsColumn[] Fields = null;
    private HashMap<Integer, MsColumn> Fields_id = new HashMap<Integer, MsColumn>();
    private HashMap<String, MsColumn> Fields_Name = new HashMap<String, MsColumn>();
    public MsIndex PrimaryKey = null;
    private MsColumn[] Sorted_PrimaryColumns = null;
    private MsColumn[] nullMapSorted_Columns = null;
    private MsColumn[] Sorted_VariantColumns = null;
    
	public long allocation_unit_id;
	
	/**
	 * 系统固定列临界点  >> 之后的是variant变量(指向NullMap)
	 */
	public int theFixedLength = -1;
    
    /**
     * variant列数量
     */
    public int theVarFieldCount = -1; 
    
    /**
     * variant【数据】的真实位置（）
     */
    //public int theVarFieldDataOffset = -1; 
    

	
	public String GetFullName(){
		return "[" + Owner + "].[" + Name + "]"; 
	}
	
    public MsColumn GetColumnbyId(int n) {
        return (MsColumn)this.Fields_id.get(n);
    }
    public MsColumn GetColumnbyName(String Name) {
        return (MsColumn)this.Fields_Name.get(Name);
    }

    public MsColumn[] GetFields(){
    	if(Fields == null){
    		synchronized (this) {
				if(Fields == null){
					Fields = new MsColumn[Fields_Name.size()];
					Fields_Name.values().toArray(Fields);
				}
    		}
    	}
    	return Fields;
    }
    
    public void AddColumn(MsColumn msColumn) {
        this.Fields_id.put(msColumn.id, msColumn);
        this.Fields_Name.put(msColumn.Name, msColumn);
    }
    
    
    private void calcfldPosition(){
    	int TmpPosi = 0;
		for (int i = 0; i < nullMapSorted_Columns.length; i++) {
			if(nullMapSorted_Columns[i].leaf_pos+1 > TmpPosi){
				TmpPosi = nullMapSorted_Columns[i].leaf_pos + nullMapSorted_Columns[i].max_length;
				nullMapSorted_Columns[i].theRealPosition = nullMapSorted_Columns[i].leaf_pos;
			}
		}
		theVarFieldCount = 0;
		for (int i = 0; i < nullMapSorted_Columns.length; i++) {
			if(nullMapSorted_Columns[i].leaf_pos < 0){
				if (theFixedLength == -1) {
					//2位fixed列数量
					TmpPosi += 2;
					theFixedLength = TmpPosi;
					//+nullmap长度+2位var列数量
					TmpPosi += ((nullMapSorted_Columns.length + 7) >>> 3) + 2;    							
				}
				nullMapSorted_Columns[i].theRealPosition = TmpPosi;
				TmpPosi += 2;
				//variant列数
				theVarFieldCount++;
			}
		}
    }
    
    public MsColumn[] getNullMapSorted_Columns(){
    	if(nullMapSorted_Columns == null){
    		synchronized (this) {
    			if(nullMapSorted_Columns == null){
    				nullMapSorted_Columns = new MsColumn[Fields_Name.size()];
    				Fields_Name.values().toArray(nullMapSorted_Columns);
    				for (int i = 0; i < nullMapSorted_Columns.length; i++) {
						for (int j = i + 1; j < nullMapSorted_Columns.length; j++) {
							if (nullMapSorted_Columns[i].nullmap > nullMapSorted_Columns[j].nullmap) {
								MsColumn tmpMc = nullMapSorted_Columns[i];
								nullMapSorted_Columns[i] = nullMapSorted_Columns[j];
								nullMapSorted_Columns[j] = tmpMc;
							}
						}
					}
    				calcfldPosition();
    			}
			}
    	}
    	return nullMapSorted_Columns;
    }
    
    public MsColumn[] getSorted_PrimaryColumns(){
    	if(Sorted_PrimaryColumns == null && PrimaryKey!=null && PrimaryKey.Fields.size()>0){
    		synchronized (this) {
    			if(Sorted_PrimaryColumns == null){
    				getNullMapSorted_Columns();
    				Sorted_PrimaryColumns = new MsColumn[PrimaryKey.Fields.size()];
    				PrimaryKey.Fields.toArray(Sorted_PrimaryColumns);
    				for (int i = 0; i < Sorted_PrimaryColumns.length; i++) {
						for (int j = i + 1; j < Sorted_PrimaryColumns.length; j++) {
							if (Sorted_PrimaryColumns[i].theRealPosition > Sorted_PrimaryColumns[j].theRealPosition) {
								MsColumn tmpMc = Sorted_PrimaryColumns[i];
								Sorted_PrimaryColumns[i] = Sorted_PrimaryColumns[j];
								Sorted_PrimaryColumns[j] = tmpMc;
							}
						}
					}
    			}
			}
    	}
    	return Sorted_PrimaryColumns;
    }
    
    
    
	public MsColumn[] getSorted_VariantColumns() {
		if (Sorted_VariantColumns == null) {
			synchronized (this) {
				if (Sorted_VariantColumns == null) {
					ArrayList<MsColumn> tmpList = new ArrayList<>();
					for (MsColumn msColumn : getNullMapSorted_Columns()) {
						if (msColumn.leaf_pos < 0) {
							tmpList.add(msColumn);
						}
					}
					Sorted_VariantColumns = tmpList.toArray(new MsColumn[0]);
				}
			}
		}
		return Sorted_VariantColumns;
	}
}
