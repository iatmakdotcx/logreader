package mak.capture.mssql;

import java.nio.charset.Charset;

import mak.capture.DBColumn;

public class MsColumn extends DBColumn {
    public int nullmap;
    public short max_length;
    public short precision;
    public short scale;
    public boolean is_nullable; 
    public int collation_Id;
    public int leaf_pos;
    /**
     * is sys.computed_columns 计算列
     */
    public boolean IsDefinitionColumn = false;
    /**
     * 值计算公式
     */
    public String definition = "";  //computed-column definition 计算列   
	
    /**
     * 仅用于 char,varchar的字符集 
     */
    public Charset charset = null;

    /**
     * 真实的列位置
     */
    public int theRealPosition = -1; 
    
    
	public MsColumn(int id, String Name) {
		super(id, Name);
	}
	
	public void SetCharSet(int CodePage){
		//TODO: 这里还是存储一下，不要每次都forName慢得慌
		charset = Charset.forName("Cp"+CodePage);
	}
}
