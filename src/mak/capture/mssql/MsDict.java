package mak.capture.mssql;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;

import mak.capture.DBDict;
import mak.tools.StringUtil;

public class MsDict extends DBDict {

	//    private HashMap list_MsLogin = new HashMap();  //list of MsLogin()
//    private HashMap list_MsUser = new HashMap();  //list of MsUser()
//    private HashMap list_MsRole = new HashMap();  //MsRole()
//    private HashMap list_MsSchema = new HashMap();  //MsSchema()
//    private HashMap list_MsSRPrivs = new HashMap();  //MsSRPrivs()
	public HashMap<Integer, MsTable> list_MsTable = new HashMap<Integer, MsTable>();  //MsTable  
//    private HashMap list_MsSyn = new HashMap();  //MsSyn() 同义词
//    private HashMap list_MsDBView = new HashMap();  //dBView() 视图
	
	
	public MsDict(MsDatabase _Db) {
		super(_Db);
	}
	
	public MsDatabase getDB(){
		return (MsDatabase)this.Db;
	}
	
    public boolean CheckDBState() {
    	if (!super.CheckDBState()) {
			return false;
    	}
        try {
            Statement statement = this.Db.conn.createStatement();
            String string = "select Convert(varchar(max),serverproperty('productversion')), Convert(varchar(max),@@version) ";
            ResultSet resultSet = statement.executeQuery(string);
            if (!resultSet.next()) {
                GetOutPut().Error("读取" + this.Db.GetFullDbName() + "版本信息失败");
                resultSet.close();
                statement.close();
                return false;
            }
            getDB().setdbVersion(resultSet.getString(1));
            String DBVersionStr = resultSet.getString(2);	        
	    this.GetOutPut().Info("数据库版本: " + DBVersionStr);
	    resultSet.close();
	        
            String string2 = "select recovery_model_desc,[COLLATION_NAME],compatibility_level,Convert(int,COLLATIONPROPERTY([COLLATION_NAME], 'CodePage')) from sys.databases where UPPER(name) = '" + this.getDB().dbName.toUpperCase() + "'";
            resultSet = statement.executeQuery(string2);
            if (!resultSet.next()) {
                this.GetOutPut().Error("读取" + this.getDB().GetFullDbName() + "日志恢复模型失败");
                resultSet.close();
                statement.close();
                return false;
            }
            boolean bl = resultSet.getString(1).equals("FULL");
            if (!bl) {
            	this.GetOutPut().Error("日志恢复模式必须为完整");
            }
            int DBCodePage = resultSet.getInt(4);
            this.GetOutPut().Info("排序规则: " + resultSet.getString(2));
            this.GetOutPut().Info("兼容级别: " + resultSet.getString(3));
            this.GetOutPut().Info("DBCodePage: " + DBCodePage);
            getDB().SetCharSet(DBCodePage);
            resultSet.close();
            statement.close();
            return bl;
        }
        catch (Exception var2_3) {
        	this.GetOutPut().Error("读取" + this.Db.GetFullDbName() + "日志恢复模型异常:" + StringUtil.getStackTrace(var2_3));
            return false;
        }
    }


	@Override
	public boolean RefreshDBDict() {
		try {
			Statement statement = this.Db.conn.createStatement();
			String SqlStr = "select s.name,a.object_id, a.name,au.allocation_unit_id from sys.all_objects a, sys.schemas s,sys.allocation_units au ,sys.partitions partitions where (a.type = 'U' or a.type = 'S') and a.schema_id = s.schema_id and partitions.index_id <= 1 and partitions.object_id = a.object_id and partitions.hobt_id = au.container_id";
			ResultSet Rs = statement.executeQuery(SqlStr);
            while (Rs.next()) {
                String TableOwner = Rs.getString(1);
                int object_id = Rs.getInt(2);
                String TableName = Rs.getString(3);
                long allocation_unit_id = Rs.getLong(4);
                if (!isIgnoreTable(TableOwner, TableName)){
	                MsTable msTable = new MsTable();
	                msTable.id = object_id;
	                msTable.Owner = TableOwner;
	                msTable.Name = TableName;
	                msTable.allocation_unit_id = allocation_unit_id;
	                this.list_MsTable.put(object_id, msTable);
                }
            }
            Rs.close();
	       
            SqlStr = "select cols.object_id,cols.column_id,cols.system_type_id,cols.user_type_id,cols.max_length,cols.precision,cols.scale,cols.is_nullable,cols.collation_name,cols.name,p_cols.leaf_null_bit nullmap,p_cols.leaf_offset leaf_pos,Convert(int,COLLATIONPROPERTY(cols.collation_name, 'CodePage')) from sys.all_columns cols,sys.system_internals_partition_columns p_cols where p_cols.leaf_null_bit > 0 and cols.column_id = p_cols.partition_column_id and p_cols.partition_id in (Select partitions.partition_id from sys.partitions partitions where partitions.index_id <= 1 and partitions.object_id=cols.object_id) order by cols.object_id,cols.column_id";
            Rs = statement.executeQuery(SqlStr);
            MsTable msTable = null;
            while (Rs.next()) {
                int object_id = Rs.getInt(1);
                int column_id = Rs.getInt(2);
                short system_type_id = Rs.getShort(3);
                short user_type_id = Rs.getShort(4);
                if (system_type_id == 240) {
                	system_type_id = user_type_id;
                }
                short max_length = Rs.getShort(5);
                short precision = Rs.getShort(6);
                short scale = Rs.getShort(7);
                short is_nullable = Rs.getShort(8);
                String collation_name = Rs.getString(9);
                if (collation_name == null) {
                	collation_name = "";
                }
                String ColumnName = Rs.getString(10);
                int nullmap = Rs.getInt(11);
                int leaf_pos = Rs.getInt(12);
                if (msTable == null || msTable.id != object_id) {
                	msTable = (MsTable)this.list_MsTable.get(object_id);
				}
            	if (msTable == null || msTable.GetColumnbyId(column_id) != null) {
					continue;
				}
                MsColumn msColumn = new MsColumn(column_id, ColumnName);
                msColumn.type_id = user_type_id;
                msColumn.max_length = max_length;
                msColumn.precision = precision;
                msColumn.scale = scale;
                msColumn.is_nullable = is_nullable == 1;
                msColumn.collation_Id = GetCollationId(collation_name);
                msColumn.nullmap = nullmap - 1;
                msColumn.leaf_pos = leaf_pos;
                int Codepage = Rs.getInt(13);
                if (!Rs.wasNull()) {
                	msColumn.SetCharSet(Codepage);
				}else{
					msColumn.charset = getDB().charset;
				}
                msTable.AddColumn(msColumn);
            }
            Rs.close();
            SqlStr = "select cc.object_id,cc.column_id,cc.definition from sys.computed_columns cc order by cc.object_id,cc.column_id";
            Rs = statement.executeQuery(SqlStr);
            while (Rs.next()) {
                int object_id = Rs.getInt(1);
                int column_id = Rs.getInt(2);
                String definition = Rs.getString(3);
                msTable = (MsTable)this.list_MsTable.get(object_id);
                if (msTable != null){
                	MsColumn msColumn = (MsColumn)msTable.GetColumnbyId(column_id);
                	if (msColumn!=null) {
                		msColumn.definition = definition;
                		msColumn.IsDefinitionColumn = true;
					}
                }
            }
            Rs.close();

            SqlStr = "SELECT i.object_id,i.index_id,i.name,ic.column_id,type_desc,ic.key_ordinal FROM sys.indexes AS i INNER JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id AND [type]=1 order by i.object_id,ic.key_ordinal";
            Rs = statement.executeQuery(SqlStr);
            while (Rs.next()) {
                int Table_Id = Rs.getInt(1);
                int PKobject_id = Rs.getInt(2);
                String PK_Name = Rs.getString(3);
                int Column_Id = Rs.getInt(4);
                String string4 = Rs.getString(5);
                msTable = (MsTable)this.list_MsTable.get(Table_Id);
                if (msTable != null){
                	MsColumn msColumn = msTable.GetColumnbyId(Column_Id);
                	if (msColumn != null) {
	                	if (msTable.PrimaryKey == null) {
							msTable.PrimaryKey = new MsIndex();
							msTable.PrimaryKey.id = PKobject_id;
							msTable.PrimaryKey.Name = PK_Name;
							msTable.PrimaryKey.Table = msTable;
							msTable.PrimaryKey.IsCLUSTERED = "CLUSTERED".equals(string4);
	                	}
	                	msTable.PrimaryKey.Fields.add(msColumn);
                	}
		        }
            }
            Rs.close();
            statement.close();
            
            return true;
		} catch (SQLException e) {
			this.GetOutPut().Error("读取" + this.Db.GetFullDbName() + "结构数据异常:" + StringUtil.getStackTrace(e));
		}

		return false;
	}
	
	public int GetCollationId(String collation_name){
		//TODO:方式待修改
    	int i1 = 0;
        if (collation_name.equals("Chinese_PRC_CI_AS")) {
          i1 = 16420;
        } else if (collation_name.equals("Chinese_PRC_CS_AS")) {
          i1 = 16420;
        } else if (collation_name.equals("Chinese_PRC_CS_AS_WS")) {
          i1 = 16420;
        } else if (collation_name.equals("Latin1_General_CI_AS")) {
          i1 = 873;
        } else if (collation_name.equals("Latin1_General_CI_AS_KS_WS")) {
          i1 = 873;
        } else if (collation_name.equals("Chinese_PRC_Stroke_CS_AS_WS")) {
          i1 = 16430;
        } else if (collation_name.equals("Chinese_PRC_Stroke_CI_AS")) {
          i1 = 16420;
        } else if (collation_name.equals("Chinese_PRC_Stroke_CS_AS")) {
          i1 = 16420;
        } else if (collation_name.equals("SQL_Latin1_General_CP1_CS_AS")) {
          i1 = 31;
        } else if (!collation_name.equals("Chinese_PRC_BIN")) {
          i1 = 65572;
        } else {
          i1 = 16420;
        }
        return i1;
	}
	
	
	public boolean isIgnoreTable(String Owner, String TableName){
		// https://msdn.microsoft.com/zh-cn/library/ms179503
		return !(!Owner.equalsIgnoreCase("sys") || 
				TableName.equalsIgnoreCase("sysowners") || 
				TableName.equalsIgnoreCase("sysschobjs") ||
				TableName.equalsIgnoreCase("syscolpars") ||
				TableName.equalsIgnoreCase("sysobjvalues") || 
				TableName.equalsIgnoreCase("sysidxstats") || 
				TableName.equalsIgnoreCase("sysiscols") || 
				TableName.equalsIgnoreCase("sysrscols") || 
				TableName.equalsIgnoreCase("syshobtcolumns") || 
				TableName.equalsIgnoreCase("sysrowsetcolumns") || 
				TableName.equalsIgnoreCase("sysallocunits") || 
				TableName.equalsIgnoreCase("sysrowsets") || 
				TableName.equalsIgnoreCase("syssingleobjrefs") || 
				TableName.equalsIgnoreCase("sysmultiobjrefs") || 
				TableName.equalsIgnoreCase("sysprivs") || 
				TableName.equalsIgnoreCase("sysclsobjs"));
	}    
}
