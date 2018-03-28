unit databaseConnection;

interface

uses
  ADODB, Classes, p_structDefine, dbDict, System.SyncObjs;

type
  TdatabaseConnection = class(TObject)
  private
    AdoQCs: TCriticalSection;
    AdoQ: TADOQuery;
    ADOConn: TADOConnection;
    AdoQCsMaster: TCriticalSection;
    AdoQMaster: TADOQuery;
    ADOConnMaster: TADOConnection;
  public
     //�ֶ����ò���
    Host: string;
    user: string;
    PassWd: string;
    dbName: string;
     //���ݿ��ѯ����
     /// <summary>
     /// ���ݿ�id
     /// </summary>
    dbID: Integer;
     /// <summary>
     /// ���ݿ�汾��
     /// </summary>
    dbVer_Major: Integer;
    dbVer_Minor: Integer;
    dbVer_BuildNumber: Integer;
     /// <summary>
     /// ���ݿ�ָ�ģʽ
     /// </summary>
    recovery_model: Integer;
     /// <summary>
     /// ���ݿ����Pid
     /// </summary>
    SvrProcessID: Integer;
     //��ǰ���ݵ���־�ļ���Ϣ
    FlogFileList: TlogFile_List;
     //���ݿ��ȫ����־vlf
    FVLF_List: TVLF_List;

     //���ݿ��ֵ�
    dict: TDbDict;
    constructor Create;
    destructor Destroy; override;
    procedure refreshConnection;
    procedure refreshDict;
    function CheckIsLocalHost: Boolean;
    function getDb_ComputerNamePhysicalNetBIOS: string;
    function getDb_AllDatabases: TStringList;
    procedure getDb_dbInfo(checkLoadedInfo:Boolean = False);
    procedure getDb_allLogFiles;
    procedure getDb_VLFs;
    function GetCodePageFromCollationName(cName: string): string;
    function GetCollationPropertyFromId(id: Integer): string;
    function GetSchemasName(schema_id: Integer): string;
    function GetObjectIdByPartitionid(partition_id: int64): integer;
    /// <summary>
    /// ��Master��ִ��Sql ������ȡִ�н��
    /// </summary>
    /// <param name="aSql">Ҫִ�е�sql</param>
    /// <param name="resDataset">ִ�еķ��ؽ�����������ִ�гɹ���Ӧ���ֶ��ͷŴ˽����</param>
    /// <returns>ִ���Ƿ�ɹ�</returns>
    function ExecSqlOnMaster(aSql: string; out resDataset: TCustomADODataSet;withOpen:Boolean=True): Boolean;
    /// <summary>
    /// �ڵ�ǰʵ������ִ��sql������ȡִ�н��
    /// </summary>
    /// <param name="aSql">Ҫִ�е�sql</param>
    /// <param name="resDataset">ִ�еķ��ؽ�������������ִ�гɹ���Ӧ���ֶ��ͷŴ˽����</param>
    /// <returns>ִ���Ƿ�ɹ�</returns>
    function ExecSql(aSql: string; out resDataset: TCustomADODataSet;withOpen:Boolean=True): Boolean;
    function CheckIsSysadmin:Boolean;
  end;

implementation

uses
  Windows, SysUtils, dbHelper, comm_func, MakCommonfuncs, pluginlog,
  Winapi.ADOInt, System.Variants;

function CloneRecordset(const Data: _Recordset): _Recordset;
var
  newRec: _Recordset;
  stm: Stream;
begin
  newRec := CoRecordset.Create as _Recordset;
  stm := CoStream.Create;
  Data.Save(stm, adPersistADTG);
  newRec.Open(stm, EmptyParam, CursorTypeEnum(adOpenUnspecified), LockTypeEnum(adLockReadOnly), 0);
  Result := newRec;
end;

function TdatabaseConnection.CheckIsLocalHost: Boolean;
var
  cmpName: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  nSize: DWORD;
  tmpStr: string;
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
  //��ȡ������Ϣ��
  AdoQCs := TCriticalSection.Create;
  ADOConn := TADOConnection.Create(nil);
  ADOConn.LoginPrompt := False;
  ADOConn.KeepConnection := False;

  AdoQ := TADOQuery.Create(nil);
  AdoQ.Connection := ADOConn;
  //Master��չ����ͨѶ��
  AdoQCsMaster := TCriticalSection.Create;
  ADOConnMaster := TADOConnection.Create(nil);
  ADOConnMaster.LoginPrompt := False;
  ADOConnMaster.KeepConnection := False;

  AdoQMaster := TADOQuery.Create(nil);
  AdoQMaster.Connection := ADOConnMaster;

  dict := TDbDict.Create;
end;

destructor TdatabaseConnection.Destroy;
begin
  dict.Free;

  AdoQMaster.Free;
  ADOConnMaster.Free;
  AdoQCsMaster.Free;

  AdoQ.Free;
  ADOConn.Free;
  AdoQCs.Free;
  inherited;
end;

function TdatabaseConnection.getDb_AllDatabases: TStringList;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := TStringList.Create;
  aSql := 'select name from sys.databases order by 1';
  if ExecSql(aSql, rDataset) then
  begin
    rDataset.First;
    while not rDataset.Eof do
    begin
      Result.Add(rDataset.Fields[0].AsString);
      rDataset.Next;
    end;
    rDataset.Free;
  end;
end;

procedure TdatabaseConnection.getDb_allLogFiles;
var
  I: Integer;
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  if dbVer_Major < 10 then
  begin
    aSql := 'SELECT fileid,name,[filename] FROM sysfiles WHERE status & 0x40 = 0x40 ORDER BY fileid';
    if ExecSql(aSql, rDataset) then
    begin
      SetLength(FlogFileList, rDataset.RecordCount);
      for I := 0 to rDataset.RecordCount - 1 do
      begin
        FlogFileList[I].fileId := rDataset.Fields[0].AsInteger;
        FlogFileList[I].fileName := rDataset.Fields[1].AsString;
        FlogFileList[I].fileFullPath := rDataset.Fields[2].AsString;
      end;
      rDataset.Free;
      //2008֮ǰ�İ汾ֻ�ܱ������
      GetldfHandle(SvrProcessID, FlogFileList);
    end;
  end
  else
  begin
    //2008 ֮������ sys.dm_io_virtual_file_stats ����ֱ�ӻ�ȡ�ļ����
    aSql := 'SELECT fileid,name,[filename],Convert(int,file_handle) FROM sysfiles a join sys.dm_io_virtual_file_stats(DB_ID(),null) b on a.fileid=b.file_id  WHERE status & 0x40 = 0x40 ORDER BY fileid';
    if ExecSql(aSql, rDataset) then
    begin
      SetLength(FlogFileList, rDataset.RecordCount);
      for I := 0 to rDataset.RecordCount - 1 do
      begin
        FlogFileList[I].fileId := rDataset.Fields[0].AsInteger;
        FlogFileList[I].fileName := rDataset.Fields[1].AsString;
        FlogFileList[I].fileFullPath := rDataset.Fields[2].AsString;
        FlogFileList[I].Srchandle := rDataset.Fields[3].AsInteger;
        FlogFileList[I].filehandle := DuplicateHandleToCurrentProcesses(SvrProcessID, rDataset.Fields[3].AsInteger);
        rDataset.Next;
      end;
      rDataset.Free;
    end;
  end;
end;

function TdatabaseConnection.getDb_ComputerNamePhysicalNetBIOS: string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  aSql := 'SELECT CONVERT(nvarchar(256), SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''))';
  if ExecSql(aSql, rDataset) then
  begin
    Result := rDataset.Fields[0].AsString;
    rDataset.Free;
  end else begin
    Result := '';
  end;
end;

procedure TdatabaseConnection.getDb_dbInfo(checkLoadedInfo:Boolean);
var
  microsoftversion: Integer;
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  aSql := 'SELECT DB_ID(),recovery_model,@@microsoftversion,SERVERPROPERTY(''ProcessID'') FROM sys.databases WHERE database_id = DB_ID()';
  if ExecSql(aSql, rDataset) then
  begin
    recovery_model := rDataset.Fields[1].AsInteger;
    microsoftversion := rDataset.Fields[2].AsInteger;
    SvrProcessID := rDataset.Fields[3].AsInteger;
    if checkLoadedInfo then
    begin
      if dbID <> rDataset.Fields[0].AsInteger then
      begin
        Loger.Add('���ݿ�id�����ò�ƥ�䣡���������á�', LOG_ERROR);

      end;
      if dbVer_Major <> (microsoftversion shr 24) and $FF then
      begin

      end;
      if dbVer_Minor <> (microsoftversion shr 16) and $FF then
      begin

      end;
      if dbVer_BuildNumber <> microsoftversion and $FFFF then
      begin

      end;
    end else begin
      dbID := rDataset.Fields[0].AsInteger;
      dbVer_Major := (microsoftversion shr 24) and $FF;
      dbVer_Minor := (microsoftversion shr 16) and $FF;
      dbVer_BuildNumber := microsoftversion and $FFFF;
    end;
    rDataset.Free;
  end;
end;

procedure TdatabaseConnection.getDb_VLFs;
var
  I: Integer;
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  //��ѯȫ����vlfs
  aSql := 'dbcc loginfo';
  if ExecSql(aSql, rDataset) then
  begin
    SetLength(FVLF_List, rDataset.RecordCount);
    rDataset.First;
    for I := 0 to rDataset.RecordCount - 1 do
    begin
      FVLF_List[I].fileId := rDataset.FieldByName('FileId').AsInteger;
      FVLF_List[I].SeqNo := rDataset.FieldByName('FSeqNo').AsInteger;
      FVLF_List[I].VLFSize := rDataset.FieldByName('FileSize').AsInteger;
      FVLF_List[I].VLFOffset := rDataset.FieldByName('StartOffset').AsInteger;
      FVLF_List[I].state := rDataset.FieldByName('Status').AsInteger;
      rDataset.Next;
    end;
    rDataset.Free;
  end;
end;

procedure TdatabaseConnection.refreshConnection;
begin
  AdoQCs.Enter;
  try
    if dbName = '' then
      dbName := 'master';
    ADOConn.ConnectionString := getConnectionString(Host, user, PassWd, dbName);
  finally
    AdoQCs.Leave
  end;

  AdoQCsMaster.Enter;
  try
    ADOConnMaster.ConnectionString := getConnectionString(Host, user, PassWd, 'master');
  finally
    AdoQCsMaster.Leave
  end;
end;

function TdatabaseConnection.ExecSqlOnMaster(aSql:string;out resDataset:TCustomADODataSet;withOpen:Boolean=True):Boolean;
begin
  Result := False;
  AdoQCsMaster.Enter;
  try
    resDataset := nil;
    try
      AdoQMaster.Close;
      AdoQMaster.SQL.Text := aSql;
      if withOpen then
      begin
        AdoQMaster.Open;
        resDataset := TCustomADODataSet.Create(nil);
        resDataset.Recordset := CloneRecordset(AdoQMaster.Recordset);
      end else begin
        AdoQMaster.ExecSQL;
      end;
      AdoQMaster.Close;
      AdoQMaster.Connection.Connected := False;
      Result := True;
    except
      on e: Exception do
      begin
        Loger.Add(' ExecSqlOnMaster fail��%s,[%s]', [e.Message, aSql], LOG_ERROR);
        resDataset.Free;
      end;
    end;
  finally
    AdoQCsMaster.Leave;
  end;
end;

function TdatabaseConnection.ExecSql(aSql:string;out resDataset:TCustomADODataSet;withOpen:Boolean=True):Boolean;
begin
  Result := False;
  AdoQCs.Enter;
  try
    resDataset := nil;
    try
      AdoQ.Close;
      AdoQ.SQL.Text := aSql;
      if withOpen then
      begin
        AdoQ.Open;
        resDataset := TCustomADODataSet.Create(nil);
        resDataset.Recordset := CloneRecordset(AdoQ.Recordset);
      end else begin
        AdoQ.ExecSQL;
      end;
      AdoQ.Close;
      AdoQ.Connection.Connected := False;
      Result := True;
    except
      on e: Exception do
      begin
        Loger.Add(' ExecSql fail��%s,[%s]', [e.Message, aSql], LOG_ERROR);
        if resDataset<>nil then
          resDataset.Free;
      end;
    end;
  finally
    AdoQCs.Leave;
  end;
end;

function TdatabaseConnection.CheckIsSysadmin: Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := False;
  aSql := 'select IS_SRVROLEMEMBER(''sysadmin'')';
  if ExecSql(aSql, rDataset) then
  begin
    if rDataset.Fields[0].AsString = '1' then
      Result := True;
    rDataset.Free;
  end;
end;

function TdatabaseConnection.GetCollationPropertyFromId(id: Integer): string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  aSql := Format('SELECT COLLATIONPROPERTYFROMID(%d,''Name'')', [id]);
  if ExecSql(aSql, rDataset) then
  begin
    Result := rDataset.Fields[0].AsString;
    rDataset.Free;
  end else begin
    Result := '';
  end;
end;

function TdatabaseConnection.GetCodePageFromCollationName(cName: string): string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  aSql := Format('SELECT COLLATIONPROPERTY(''%s'',''CodePage'')', [cName]);
  if ExecSql(aSql, rDataset) then
  begin
    Result := rDataset.Fields[0].AsString;
    rDataset.Free;
  end else begin
    Result := '';
  end;
end;

function TdatabaseConnection.GetSchemasName(schema_id: Integer): string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := '';
  aSql := Format('select name from sys.schemas where schema_id=%d', [schema_id]);
  if ExecSql(aSql, rDataset) then
  begin
    if not rDataset.Eof then
      Result := rDataset.Fields[0].AsString;

    rDataset.Free;
  end else begin
    Result := '';
  end;
end;

function TdatabaseConnection.GetObjectIdByPartitionid(partition_id: int64): integer;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := 0;
  aSql := Format('select object_id from sys.partitions where partition_id=%d', [partition_id]);
  if ExecSql(aSql, rDataset) then
  begin
    if not rDataset.Eof then
      Result := rDataset.Fields[0].AsInteger;
    rDataset.Free;
  end;
end;

procedure TdatabaseConnection.refreshDict;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  //ˢ�±���Ϣ
  aSql := 'select s.name,a.object_id, a.name from sys.objects a, sys.schemas s where (a.type = ''U'' or a.type = ''S'') and a.schema_id = s.schema_id';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTables(rDataset);
    rDataset.Free;
  end;
  //ˢ������Ϣ
  aSql := 'select cols.object_id,cols.column_id,cols.system_type_id,cols.max_length,cols.precision,cols.scale,cols.is_nullable,cols.name, ' +
      ' p_cols.leaf_null_bit nullmap,p_cols.leaf_offset leaf_pos,cols.collation_name,Convert(int,COLLATIONPROPERTY(cols.collation_name, ''CodePage'')) cp  ' +
      ' from sys.all_columns cols,sys.system_internals_partition_columns p_cols ' +
      ' where p_cols.leaf_null_bit > 0 and cols.column_id = p_cols.partition_column_id and ' +
      ' p_cols.partition_id in (Select partitions.partition_id from sys.partitions partitions where partitions.index_id <= 1 and partitions.object_id=cols.object_id) ' +
      ' order by cols.object_id,cols.column_id ';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTablesFields(rDataset);
    rDataset.Free;
  end;
  //ˢ��Ψһ����Ϣ
  aSql := 'select a.id,a.colid from sysindexkeys a join (select object_id,min(index_id) idxid from sys.indexes where is_unique=1 group by object_id) b on a.id=b.object_id and a.indid=b.idxid order by a.id,keyno ';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTablesUniqueKey(rDataset);
    rDataset.Free;
  end;
end;


end.

