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
     * is sys.computed_columns ������
     */
    public boolean IsDefinitionColumn = false;
    /**
     * ֵ���㹫ʽ
     */
    public String definition = "";  //computed-column definition ������   
	
    /**
     * ������ char,varchar���ַ��� 
     */
    public Charset charset = null;

    /**
     * ��ʵ����λ��
     */
    public int theRealPosition = -1; 
    
    
	public MsColumn(int id, String Name) {
		super(id, Name);
	}
	
	public void SetCharSet(int CodePage){
		//TODO: ���ﻹ�Ǵ洢һ�£���Ҫÿ�ζ�forName���û�
		charset = Charset.forName("Cp"+CodePage);
	}
}
