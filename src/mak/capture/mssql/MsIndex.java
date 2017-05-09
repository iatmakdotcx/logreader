package mak.capture.mssql;

public class MsIndex {
    public int id;
    public String Name;
    public MsTable Table;
    public MsColumn[] Fields = new MsColumn[0]; 
    public boolean IsCLUSTERED;
}
