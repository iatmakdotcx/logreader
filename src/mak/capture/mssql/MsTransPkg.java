package mak.capture.mssql;

import java.io.Serializable;
import java.util.ArrayList;

public class MsTransPkg implements Serializable  {
	/**
	 * 
	 */
	private static final long serialVersionUID = -6594154317364711611L;
	public ArrayList<MsLogRowData> actions = new ArrayList<>();
	
	public void addAction(MsLogRowData aAction){
		actions.add(aAction);
	}
}
