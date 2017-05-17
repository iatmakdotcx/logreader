package mak.capture.data;

import java.util.ArrayList;

import mak.capture.mssql.MsColumn;

public class DBOptInsert implements DBOpt {
	public ArrayList<MsColumn> Fields= new ArrayList<>();
	public ArrayList<byte[]> Values= new ArrayList<>();
}
