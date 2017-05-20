package mak.capture.mssql;

import java.util.ArrayList;

public class MsIndex {
    public int id;
    public String Name;
    public MsTable Table;
    public ArrayList<MsColumn> Fields = new ArrayList<>(); 
    public boolean IsCLUSTERED;
}
