unit databaseConnection;

interface

uses
  ADODB, Classes, p_structDefine, dbDict, System.SyncObjs;

type
  TdatabaseConnection = class(TObject)
  private
    FdBConfigOK:Boolean;
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

    //���ݿ��Ƿ���64λ�汾
    dbIs64bit:Boolean;

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
    function getDb_dbInfo(checkLoadedInfo:Boolean):Boolean;
    procedure getDb_allLogFiles;
    procedure getDb_VLFs;
    function GetCodePageFromCollationName(cName: string): string;
    function GetCollationPropertyFromId(id: Integer): string;
    function GetSchemasName(schema_id: Integer): string;
    function GetObjectIdByPartitionid(partition_id: int64): integer;
    function GetLastBackupInfo(var lsn: Tlog_LSN;  var backupTime: TDateTime): Boolean;
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
    function getUpdateSQLfromSelect(table:TdbTableItem; wherekey: string): string;
    property dbok:Boolean read FdBConfigOK;
    /// <summary>
    /// �����ݿ�Ա��ֵ����
    /// </summary>
    /// <returns></returns>
    function CompareDict:string;
  end;

implementation

uses
  Windows, SysUtils, dbHelper, comm_func, MakCommonfuncs, loglog,
  Winapi.ADOInt, System.Variants, Data.DB, dbFieldTypes, Memory_Common, math;

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
  FdBConfigOK := False;
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
  if ExecSqlOnMaster(aSql, rDataset) then
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
    //2008֮ǰ�İ汾ֻ�ܱ������
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
  if ExecSqlOnMaster(aSql, rDataset) then
  begin
    Result := rDataset.Fields[0].AsString;
    rDataset.Free;
  end else begin
    Result := '';
  end;
end;

function TdatabaseConnection.getDb_dbInfo(checkLoadedInfo:Boolean):Boolean;
var
  microsoftversion: Integer;
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := False;
  aSql := 'SELECT DB_ID(),recovery_model,@@microsoftversion,SERVERPROPERTY(''ProcessID''),charindex(''64'',cast(SERVERPROPERTY(''Edition'')as varchar(100))) FROM sys.databases WHERE database_id = DB_ID()';
  if ExecSql(aSql, rDataset) then
  begin
    try
      recovery_model := rDataset.Fields[1].AsInteger;
      microsoftversion := rDataset.Fields[2].AsInteger;
      SvrProcessID := rDataset.Fields[3].AsInteger;
      dbIs64bit := rDataset.Fields[4].AsInteger>1;
      if checkLoadedInfo then
      begin
        if dbID <> rDataset.Fields[0].AsInteger then
        begin
          Loger.Add('���ݿ�id�����ò�ƥ�䣡���������á�', LOG_ERROR);
          Exit;
        end;
        if dbVer_Major <> (microsoftversion shr 24) and $FF then
        begin
          Loger.Add('���ݿ�汾�����ò�ƥ�䣡���������á�', LOG_ERROR);
          Exit;
        end;
        if dbVer_Minor <> (microsoftversion shr 16) and $FF then
        begin
          Loger.Add('���ݿ�汾�����ò�ƥ�䣡���������á�', LOG_ERROR);
          Exit;
        end;
        if dbVer_BuildNumber <> microsoftversion and $FFFF then
        begin
          Loger.Add('���ݿ�汾�����ò�ƥ�䣡���������á�', LOG_ERROR);
          Exit;
        end;
      end else begin
        dbID := rDataset.Fields[0].AsInteger;
        dbVer_Major := (microsoftversion shr 24) and $FF;
        dbVer_Minor := (microsoftversion shr 16) and $FF;
        dbVer_BuildNumber := microsoftversion and $FFFF;
      end;
      Result := True;
    finally
      rDataset.Free;
    end;
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
  FdBConfigOK := True;
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

function TdatabaseConnection.getUpdateSQLfromSelect(table:TdbTableItem; wherekey:string): string;

function getfieldValueAsString(field: TField): string;
var
  ddSize: Integer;
  blobData: TBytes;
  Buffer: TValueBuffer;
begin
  if field.IsNull then
  begin
    Result := 'NULL';
    Exit;
  end;

  case field.DataType of
      //int
    ftSingle,
    ftByte,
    ftExtended,
    ftSmallint,
    ftInteger,
    ftWord,
    ftFloat,
    ftCurrency,
    ftBCD,
    ftFMTBcd,
    ftAutoInc,
    ftLargeint,
    ftLongWord,
    ftShortint:
      begin
        Result := field.AsString;
      end;
      //string
    ftFixedChar,
    ftString,
    ftDate,
    ftTime,
    ftDateTime,
    ftMemo,
    ftWideString,
    ftFixedWideChar,
    ftFmtMemo,
    ftWideMemo,
    ftGuid:
      begin
        Result := field.AsString.QuotedString;
      end;
      //bool
    ftBoolean:
      begin
        if field.AsBoolean then
        begin
          Result := '1';
        end
        else
        begin
          Result := '0';
        end;
      end;
      //varbinary
    ftVarBytes:
      begin
        ddSize := field.DataSize;
        if ddSize = 0 then
        begin
          Result := 'NULL';
          Exit;
        end;
        SetLength(Buffer, ddSize);
        if field.GetData(Buffer) then
        begin
          ddSize := Pword(@Buffer[0])^;
          Result := '0x' + DumpMemory2Str(@Buffer[2], ddSize);
        end;
        SetLength(Buffer, 0);
      end;
    ftVariant:
      begin
        //TODO:��ʱ��֧�ִ�����
        Result := 'NULL';
      end
  else    //bin
    if field.IsBlob then
    begin
      blobData := TBlobField(field).Value;
      if Length(blobData) = 0 then
      begin
        Result := 'NULL';
        Exit;
      end;
      Result := '0x' + DumpMemory2Str(@blobData[0], Length(blobData));
      SetLength(blobData, 0);
    end
    else
    begin
      ddSize := field.DataSize;
      if ddSize = 0 then
      begin
        Result := 'NULL';
        Exit;
      end;
      SetLength(Buffer, ddSize);
      if field.GetData(Buffer) then
      begin
        Result := '0x' + DumpMemory2Str(@Buffer[0], Length(Buffer));
      end;
      SetLength(blobData, 0);
    end;
//     ftUnknown: ;
//     ftBytes: ;
//     ftBlob: ;
//     ftGraphic: ;
//     ftParadoxOle: ;
//     ftDBaseOle: ;
//     ftTypedBinary: ;
//     ftCursor: ;
//     ftADT: ;
//     ftArray: ;
//     ftReference: ;
//     ftDataSet: ;
//     ftOraBlob: ;
//     ftOraClob: ;
//     ftInterface: ;
//     ftIDispatch: ;
//     ftTimeStamp: ;
//     ftOraTimeStamp: ;
//     ftOraInterval: ;
//     ftConnection: ;
//     ftParams: ;
//     ftStream: ;
//     ftTimeStampOffset: ;
//     ftObject: ;
  end;
end;

var
  rDataset:TCustomADODataSet;
  aSql:string;
  I,J: Integer;
  fieldsStr:string;
  tmpbool:Boolean;
  field:TdbFieldItem;
begin
  Result := '';
  fieldsStr := '';
  for I := 0 to table.Fields.Count -1 do
  begin
    field := table.Fields[i];
    case field.type_id of
      //��������
      MsTypes.TIMESTAMP,
      MsTypes.GEOGRAPHY,
      MsTypes.XML,
      MsTypes.SQL_VARIANT:
      Continue;
    else
      //���Ծۺ�(������¾ۺϿ��ܵ����������ؽ�(DELETE+INSERT)
      tmpbool := False;
      for J := 0 to table.UniqueClusteredKeys.Count-1 do
      begin
        if field.Col_id=TdbFieldItem(table.UniqueClusteredKeys[j]).Col_id then
        begin
          tmpbool := True;
          Break;
        end;
      end;
      if not tmpbool then
        fieldsStr := fieldsStr + ',[' + field.ColName + ']';
    end
  end;
  if fieldsStr.Length>2 then
  begin
    Delete(fieldsStr,1,1);
    aSql := 'select ' + fieldsStr + ' from ' + table.TableNmae + ' where ' + wherekey;
    if ExecSql(aSql, rDataset) then
    begin
      if rDataset.RecordCount > 0 then
      begin
        for I := 0 to rDataset.Fields.Count -1 do
        begin
          Result := Result + ',['+rDataset.Fields[i].FieldName+']=' + getfieldValueAsString(rDataset.Fields[i]);
        end;
        Delete(Result,1,1);
      end;
      rDataset.Free;
    end;
  end
end;

function TdatabaseConnection.GetCollationPropertyFromId(id: Integer): string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  aSql := Format('SELECT cast(COLLATIONPROPERTYFROMID(%d,''Name'') as varchar(100))', [id]);
  if (id >0) and ExecSql(aSql, rDataset) then
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
  aSql := Format('SELECT cast(COLLATIONPROPERTY(''%s'',''CodePage'') as varchar(100))', [cName]);
  if (cName<>'') and ExecSql(aSql, rDataset) then
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
  end;
end;

function TdatabaseConnection.GetLastBackupInfo(var lsn:Tlog_LSN; var backupTime :TDateTime): boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
  lsnStr:string;
begin
  Result := False;
  //aSql := Format('SELECT differential_base_lsn,differential_base_time FROM sys.master_files WHERE database_id = %d AND [type]=0', [dbid]);
  aSql := Format('select top 1 database_backup_lsn,backup_finish_date from msdb..backupset where database_name=''%s'' order by backup_finish_date desc', [dbName]);
  if ExecSql(aSql, rDataset) then
  begin
    if not rDataset.Eof then
    begin
      lsnStr := rDataset.Fields[0].AsString;
      if Length(lsnStr) >= 16 then
      begin
        lsnStr := lsnStr.PadLeft(25, '0');
        try
          lsn.LSN_1 := StrToInt(Copy(lsnStr, 1, 10));
          lsn.LSN_2 := StrToInt(Copy(lsnStr, 11, 10));
          lsn.LSN_3 := StrToInt(Copy(lsnStr, 22, 5));
          backupTime := rDataset.Fields[1].AsDateTime;
          Result := True;
        except
        end;
      end;
    end;
    rDataset.Free;
  end;
end;

function TdatabaseConnection.GetObjectIdByPartitionid(partition_id: int64): integer;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := 0;
  aSql := Format('select object_id from sys.partitions where index_id<=1 and partition_id=%d', [partition_id]);
  if ExecSql(aSql, rDataset) then
  begin
    if not rDataset.Eof then
      Result := rDataset.Fields[0].AsInteger;
    rDataset.Free;
  end;
end;

function TdatabaseConnection.CompareDict: string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
  I,J:Integer;
  object_id:Integer;
  object_name:string;
  DiffStr:TStringList;
  tableItem:TdbTableItem;
var
  tti: TdbTableItem;
  tblId: Integer;
  field: TdbFieldItem;
  Col_id: Integer;
  ColName: string;
  type_id: Word;
  nullMap: Integer;
  Max_length: Word;
  procision: Integer;
  scale: Integer;
  is_nullable: Boolean;
  leaf_pos: Integer;
  collation_name: string;  //�ַ���
  CodePage: Integer;

  tmpStr,tmpStr2:string;
  idxxxxs:TList;
begin
  DiffStr := TStringList.Create;
  try
    aSql := 'select s.name,a.object_id, a.name,partition_id '+
             'from sys.objects a join sys.schemas s on a.schema_id = s.schema_id '+
             'left join (select partition_id,object_id from sys.partitions where partitions.index_id <= 1) p on a.object_id=p.object_id '+
             'where (a.type = ''U'' or a.type = ''S'') ';
    if ExecSql(aSql, rDataset) then
    begin
      rDataset.First;
      while not rDataset.eof do
      begin
        if rDataset.Fields[0].AsString<>'sys' then
        begin
          object_id := rDataset.Fields[1].AsInteger;
          object_name := rDataset.Fields[2].AsString;
          tableItem := dict.tables.GetItemById(object_id);
          if tableItem = nil then
          begin
            DiffStr.Add(Format('���ݿ� + %d,%s', [object_id, object_name]));
          end else begin
            if LowerCase(tableItem.TableNmae) <> LowerCase(object_name) then
            begin
              DiffStr.Add(Format('������ͬ x %s => %s', [object_name, tableItem.TableNmae]));
            end;
          end;
        end;
        rDataset.Next;
      end;

      for I := 0 to dict.tables.Count-1 do
      begin
        tableItem := dict.tables[i];
        if not rDataset.Locate('object_id', tableItem.TableId, []) then
        begin
          DiffStr.Add(Format('���ݿ� - %d,%s', [tableItem.TableId, tableItem.TableNmae]));
        end;
      end;
      rDataset.Free;
    end;

    aSql := 'select cols.object_id,cols.column_id,cols.system_type_id,cols.max_length,cols.precision,cols.scale,cols.is_nullable,cols.name, ' +
        ' p_cols.leaf_null_bit nullmap,p_cols.leaf_offset leaf_pos,cols.collation_name,Convert(int,COLLATIONPROPERTY(cols.collation_name, ''CodePage'')) cp  ' +
        ' from sys.all_columns cols,sys.system_internals_partition_columns p_cols ' +
        ' where p_cols.leaf_null_bit > 0 and cols.column_id = p_cols.partition_column_id and ' +
        ' p_cols.partition_id in (Select partitions.partition_id from sys.partitions partitions where partitions.index_id <= 1 and partitions.object_id=cols.object_id) ' +
        ' order by cols.object_id,cols.column_id ';
    if ExecSql(aSql, rDataset) then
    begin
      rDataset.First;
      tblId := 0;
      tti := nil;
      while not rDataset.Eof do
      begin
        if tblId <> rDataset.Fields[0].AsInteger then
        begin
          tblId := rDataset.Fields[0].AsInteger;
          tti := dict.tables.GetItemById(tblId);
        end;
        if (tti<>nil) and (tti.Owner<>'sys') then
        begin
          Col_id := rDataset.Fields[1].AsInteger;
          type_id := rDataset.Fields[2].AsInteger;
          Max_length := rDataset.Fields[3].AsInteger;
          procision := rDataset.Fields[4].AsInteger;
          scale := rDataset.Fields[5].AsInteger;
          is_nullable := rDataset.Fields[6].AsBoolean;
          ColName := rDataset.Fields[7].AsString;
          nullMap := rDataset.Fields[8].AsInteger - 1;
          leaf_pos := rDataset.Fields[9].AsInteger;
          collation_name := rDataset.Fields[10].AsString;
          if rDataset.Fields[11].IsNull then
            CodePage := -1
          else
            CodePage := rDataset.Fields[11].AsInteger;
          field := tti.Fields.GetItemById(Col_id);
          if field=nil then
          begin
            DiffStr.Add(Format('���ݿ�Field + %s', [tti.getFullName+'.'+ColName]));
          end else begin
            tmpStr := '';
            if field.ColName<>ColName then
            begin
              tmpStr := tmpStr + Format(',name:%s => %s', [ColName, field.ColName])
            end;
            if field.type_id<>type_id then
            begin
              tmpStr := tmpStr + Format(',type_id:%d => %d', [type_id, field.type_id])
            end;
            if field.nullMap<>nullMap then
            begin
              tmpStr := tmpStr + Format(',nullMap:%d => %d', [nullMap, field.nullMap])
            end;
            if field.Max_length<>Max_length then
            begin
              tmpStr := tmpStr + Format(',Max_length:%d => %d', [Max_length, field.Max_length])
            end;
            if field.procision<>procision then
            begin
              tmpStr := tmpStr + Format(',procision:%s => %s', [procision, field.procision])
            end;
            if field.scale<>scale then
            begin
              tmpStr := tmpStr + Format(',scale:%d => %d', [scale, field.scale])
            end;
            if field.is_nullable<>is_nullable then
            begin
              tmpStr := tmpStr + Format(',is_nullable:%s => %s', [booltostr(is_nullable,True), booltostr(field.is_nullable,True)])
            end;
            if field.collation_name<>collation_name then
            begin
              tmpStr := tmpStr + Format(',collation_name:%s => %s', [collation_name, field.collation_name])
            end;
            if field.CodePage<>CodePage then
            begin
              tmpStr := tmpStr + Format(',CodePage:%d => %d', [CodePage, field.CodePage])
            end;
            if tmpStr<>'' then
              DiffStr.Add('���ݿ�Field X >'+ tti.getFullName+'.'+ColName + tmpStr);
          end;
        end;
        rDataset.Next;
      end;
      rDataset.Free;
    end;

    aSql := 'select a.id,a.colid from sysindexkeys a join sys.indexes b on a.id=b.object_id and a.indid=b.index_id and is_unique=1 and [type]=1 order by a.id,keyno';
    if ExecSql(aSql, rDataset) then
    begin
      rDataset.First;
      tblId := 0;
      tti := nil;
      idxxxxs:=TList.Create;
      while not rDataset.Eof do
      begin
        if tblId <> rDataset.Fields[0].AsInteger then
        begin
          if (tti<>nil) and (idxxxxs.Count>0) then
          begin
            tmpStr := '';
            for J := 0 to tti.UniqueClusteredKeys.Count-1 do
            begin
              tmpStr := ',' + TdbFieldItem(tti.UniqueClusteredKeys[j]).ColName;
            end;
            tmpStr2 := '';
            for J := 0 to idxxxxs.Count-1 do
            begin
              tmpStr2 := ',' + TdbFieldItem(idxxxxs[j]).ColName;
            end;
            if tmpStr<>tmpStr2 then
              DiffStr.Add('���ݿ�UcK X > '+ tmpStr2+' => '+tmpStr);
          end;
          tblId := rDataset.Fields[0].AsInteger;
          tti := dict.tables.GetItemById(tblId);
          idxxxxs.clear;
        end;
        if (tti<>nil) and (tti.Owner<>'sys') then
        begin
          field := tti.Fields.GetItemById(rDataset.Fields[1].AsInteger);
          if field<>nil then
          begin
            idxxxxs.Add(field);
          end;
        end;
        rDataset.Next;
      end;
      if (tti<>nil) and (idxxxxs.Count>0) then
      begin
        tmpStr := '';
        for J := 0 to tti.UniqueClusteredKeys.Count-1 do
        begin
          tmpStr := ',' + TdbFieldItem(tti.UniqueClusteredKeys[j]).ColName;
        end;
        tmpStr2 := '';
        for J := 0 to idxxxxs.Count-1 do
        begin
          tmpStr2 := ',' + TdbFieldItem(idxxxxs[j]).ColName;
        end;
        if tmpStr<>tmpStr2 then
          DiffStr.Add('���ݿ�UcK X > '+tti.TableNmae+ tmpStr2+' => '+tmpStr);
      end;
      idxxxxs.Free;

      for I := 0 to dict.tables.Count-1 do
      begin
        if dict.tables[i].Owner<>'sys' then
        begin
          if (dict.tables[i].UniqueClusteredKeys.Count>0) and (not rDataset.Locate('id',dict.tables[i].TableId,[])) then
          begin
            tmpStr := '';
            for J := 0 to dict.tables[i].UniqueClusteredKeys.Count-1 do
            begin
              tmpStr := ',' + TdbFieldItem(dict.tables[i].UniqueClusteredKeys[j]).ColName;
            end;

            DiffStr.Add('���ݿ�UcK X >'+dict.tables[i].TableNmae+'  => '+tmpStr);
          end;
        end;
      end;

      rDataset.Free;
    end;

    Result := DiffStr.Text;
  finally
    DiffStr.Free;
  end;

end;

procedure TdatabaseConnection.refreshDict;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  //ˢ�±���Ϣ
  //aSql := 'select s.name,a.object_id, a.name from sys.objects a, sys.schemas s where (a.type = ''U'' or a.type = ''S'') and a.schema_id = s.schema_id';
   aSql := 'select s.name,a.object_id, a.name,partition_id '+
           'from sys.objects a join sys.schemas s on a.schema_id = s.schema_id '+
           'left join (select partition_id,object_id from sys.partitions where partitions.index_id <= 1) p on a.object_id=p.object_id '+
           'where (a.type = ''U'' or a.type = ''S'') ';
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
  aSql := 'select a.id,a.colid from sysindexkeys a join sys.indexes b on a.id=b.object_id and a.indid=b.index_id and is_unique=1 and [type]=1 order by a.id,keyno';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTablesUniqueKey(rDataset);
    rDataset.Free;
  end;
end;


end.

