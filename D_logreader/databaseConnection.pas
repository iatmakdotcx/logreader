unit databaseConnection;

interface

uses
  ADODB, Classes, p_structDefine, dbDict;

type
  TdatabaseConnection = class(TObject)
  private
    AdoQ:TADOQuery;
    ADOConn: TADOConnection;
  public
     //手动设置部分
     Host:string;
     user:string;
     PassWd:string;
     dbName:string;
     //数据库查询部分
     /// <summary>
     /// 数据库id
     /// </summary>
     dbID:Integer;
     /// <summary>
     /// 数据库版本号
     /// </summary>
     dbVer_Major: Integer;
     dbVer_Minor: Integer;
     dbVer_BuildNumber: Integer;
     /// <summary>
     /// 数据库恢复模式
     /// </summary>
     recovery_model:Integer;
     /// <summary>
     /// 数据库进程Pid
     /// </summary>
     SvrProcessID:Integer;
     //当前数据的日志文件信息
     FlogFileList:TlogFile_List;
     //数据库的全部日志vlf
     FVLF_List :TVLF_List;

     //数据库字典
     dict:TDbDict;

     constructor Create;
     destructor Destroy;override;
     procedure refreshConnection;
     procedure refreshDict;

     function CheckIsLocalHost: Boolean;
     function getDb_ComputerNamePhysicalNetBIOS:string;
     function getDb_AllDatabases:TStringList;
     procedure getDb_dbInfo;
     procedure getDb_allLogFiles;
     procedure getDb_VLFs;
  end;

implementation

uses
  Windows, SysUtils, dbHelper, comm_func, MakCommonfuncs;

function TdatabaseConnection.CheckIsLocalHost: Boolean;
var
  cmpName:array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  nSize:DWORD;
  tmpStr:string;
begin
  nSize := MAX_COMPUTERNAME_LENGTH;
  GetComputerName(@cmpName, nSize);
  Host := LowerCase(Host);
  tmpStr := cmpName;
  if (Host = '.') or (Host = '127.0.0.1') or (Host = 'localhost') or (Host = tmpStr) or (Host = getDb_ComputerNamePhysicalNetBIOS) then
  begin
    Result := True;
  end
  else
  begin
    Result := false;
  end;
end;

constructor TdatabaseConnection.Create;
begin
  ADOConn := TADOConnection.Create(nil);
  ADOConn.LoginPrompt := False;
  ADOConn.KeepConnection := False;
  

  AdoQ := TADOQuery.Create(nil);
  AdoQ.Connection := ADOConn;

  dict := TDbDict.Create;
end;

destructor TdatabaseConnection.Destroy;
begin
  dict.Free;

  AdoQ.Free;
  ADOConn.Free;
  inherited;
end;

function TdatabaseConnection.getDb_AllDatabases: TStringList;
begin
  Result := TStringList.Create;
  AdoQ.sql.Text := 'select name from sys.databases order by 1';
  AdoQ.Open;
  while not AdoQ.Eof do
  begin
    Result.Add(AdoQ.Fields[0].AsString);
    AdoQ.Next;
  end;
  AdoQ.Close;
  AdoQ.Connection.Connected := False;
end;

procedure TdatabaseConnection.getDb_allLogFiles;
var
  I: Integer;
begin
  if dbVer_Major < 10 then
  begin
    AdoQ.sql.Text := 'SELECT fileid,name,[filename] FROM sysfiles WHERE status & 0x40 = 0x40 ORDER BY fileid';
    AdoQ.Open;
    SetLength(FlogFileList, AdoQ.RecordCount);
    for I := 0 to AdoQ.RecordCount - 1 do
    begin
      FlogFileList[I].fileId := AdoQ.Fields[0].AsInteger;
      FlogFileList[I].fileName := AdoQ.Fields[1].AsString;
      FlogFileList[I].fileFullPath := AdoQ.Fields[2].AsString;
    end;
    AdoQ.Close;
    //2008之前的版本只能遍历句柄
    GetldfHandle(SvrProcessID, FlogFileList);
  end else begin
    //2008 之后有了 sys.dm_io_virtual_file_stats 可以直接获取文件句柄
    AdoQ.sql.Text := 'SELECT fileid,name,[filename],Convert(int,file_handle) FROM sysfiles a join sys.dm_io_virtual_file_stats(DB_ID(),null) b on a.fileid=b.file_id  WHERE status & 0x40 = 0x40 ORDER BY fileid';
    AdoQ.Open;
    SetLength(FlogFileList, AdoQ.RecordCount);
    for I := 0 to AdoQ.RecordCount - 1 do
    begin
      FlogFileList[I].fileId := AdoQ.Fields[0].AsInteger;
      FlogFileList[I].fileName := AdoQ.Fields[1].AsString;
      FlogFileList[I].fileFullPath := AdoQ.Fields[2].AsString;
      FlogFileList[I].Srchandle := AdoQ.Fields[3].AsInteger;
      FlogFileList[I].filehandle := DuplicateHandleToCurrentProcesses(SvrProcessID, AdoQ.Fields[3].AsInteger);
      AdoQ.Next;
    end;
    AdoQ.Close;
  end;
  AdoQ.Connection.Connected := False;
end;

function TdatabaseConnection.getDb_ComputerNamePhysicalNetBIOS: string;
begin
  AdoQ.sql.Text := 'SELECT CONVERT(nvarchar(256), SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''))';
  AdoQ.Open;
  Result := AdoQ.Fields[0].AsString;
  AdoQ.Close;
  AdoQ.Connection.Connected := False;
end;

procedure TdatabaseConnection.getDb_dbInfo;
var
  microsoftversion:Integer;
begin
  AdoQ.sql.Text := 'SELECT DB_ID(),recovery_model,@@microsoftversion,SERVERPROPERTY(''ProcessID'') FROM sys.databases WHERE database_id = DB_ID()';
  AdoQ.Open;
  dbID := AdoQ.Fields[0].AsInteger;
  recovery_model := AdoQ.Fields[1].AsInteger;
  microsoftversion := AdoQ.Fields[2].AsInteger;
  SvrProcessID  := AdoQ.Fields[3].AsInteger;
  dbVer_Major := (microsoftversion shr 24) and $FF;
  dbVer_Minor := (microsoftversion shr 16) and $FF;
  dbVer_BuildNumber := microsoftversion and $FFFF;
  AdoQ.Close;
  AdoQ.Connection.Connected := False;
end;

procedure TdatabaseConnection.getDb_VLFs;
var
  I:Integer;
begin
  //查询全部的vlfs
  AdoQ.sql.Text := 'dbcc loginfo';
  AdoQ.Open;
  SetLength(FVLF_List, AdoQ.RecordCount);
  for I := 0 to AdoQ.RecordCount - 1 do
  begin
    FVLF_List[I].fileId := AdoQ.FieldByName('FileId').AsInteger;
    FVLF_List[I].SeqNo := AdoQ.FieldByName('FSeqNo').AsInteger;
    FVLF_List[I].VLFSize := AdoQ.FieldByName('FileSize').AsInteger;
    FVLF_List[I].VLFOffset := AdoQ.FieldByName('StartOffset').AsInteger;
    FVLF_List[I].state := AdoQ.FieldByName('Status').AsInteger;
    AdoQ.Next;
  end;
  AdoQ.Close;
  AdoQ.Connection.Connected := False;
end;

procedure TdatabaseConnection.refreshConnection;
begin
  if dbName = '' then
    dbName := 'master';
  ADOConn.ConnectionString := getConnectionString(Host, user, PassWd, dbName);
end;

procedure TdatabaseConnection.refreshDict;
begin
  //全部Table
//  AdoQ.sql.Text := 'select s.name,a.object_id, a.name,au.allocation_unit_id from sys.all_objects a, sys.schemas s,sys.allocation_units au ,sys.partitions partitions '+
//   ' where (a.type = ''U'' or a.type = ''S'') and a.schema_id = s.schema_id and partitions.index_id <= 1 and partitions.object_id = a.object_id and partitions.hobt_id = au.container_id order by object_id';
  AdoQ.sql.Text := 'select s.name,a.object_id, a.name from sys.objects a, sys.schemas s where (a.type = ''U'' or a.type = ''S'') and a.schema_id = s.schema_id ';
  AdoQ.Open;
  dict.RefreshTables(AdoQ);
  AdoQ.sql.Text := 'select cols.object_id,cols.column_id,cols.system_type_id,cols.max_length,cols.precision,cols.scale,cols.is_nullable,cols.name, '+
    ' p_cols.leaf_null_bit nullmap,p_cols.leaf_offset leaf_pos,cols.collation_name,Convert(int,COLLATIONPROPERTY(cols.collation_name, ''CodePage'')) cp  '+
    ' from sys.all_columns cols,sys.system_internals_partition_columns p_cols '+
    ' where p_cols.leaf_null_bit > 0 and cols.column_id = p_cols.partition_column_id and '+
    ' p_cols.partition_id in (Select partitions.partition_id from sys.partitions partitions where partitions.index_id <= 1 and partitions.object_id=cols.object_id) '+
    ' order by cols.object_id,cols.column_id ';
  AdoQ.Open;
  dict.RefreshTablesFields(AdoQ);


end;

end.
