package mak.capture;

import java.util.HashMap;

public class RAW_Table {
	public int xType;  //¿‡–Õ
	public DBTable table;
	
	public HashMap<String, RAW_Field> FieldsValue_old = new HashMap<String, RAW_Field>();
	public HashMap<String, RAW_Field> FieldsValue_new = new HashMap<String, RAW_Field>();
	
	
	public String GetTypeDescription(){
		switch (xType) {
			case 0x0030: return "Insert";
	
			default:return "UNKNOWN!!!";
		}
		
	}
}
