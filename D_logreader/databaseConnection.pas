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
     //手动设置部分
    Host: string;
    user: string;
    PassWd: string;
    dbName: string;
     //数据库查询部分
     /// <summary>
     /// 数据库id
     /// </summary>
    dbID: Integer;
     /// <summary>
     /// 数据库版本号
     /// </summary>
    dbVer_Major: Integer;
    dbVer_Minor: Integer;
    dbVer_BuildNumber: Integer;

    //数据库是否是64位版本
    dbIs64bit:Boolean;

     /// <summary>
     /// 数据库恢复模式
     /// </summary>
    recovery_model: Integer;
     /// <summary>
     /// 数据库进程Pid
     /// </summary>
    SvrProcessID: Integer;
     //当前数据的日志文件信息
    FlogFileList: TlogFile_List;
     //数据库的全部日志vlf
    FVLF_List: TVLF_List;

     //数据库字典
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
    /// 在Master表执行Sql ，并获取执行结果
    /// </summary>
    /// <param name="aSql">要执行的sql</param>
    /// <param name="resDataset">执行的返回结果。如果函数执行成功，应该手动释放此结果集</param>
    /// <returns>执行是否成功</returns>
    function ExecSqlOnMaster(aSql: string; out resDataset: TCustomADODataSet;withOpen:Boolean=True): Boolean;
    /// <summary>
    /// 在当前实例库中执行sql，并获取执行结果
    /// </summary>
    /// <param name="aSql">要执行的sql</param>
    /// <param name="resDataset">执行的返回结果集。如果函数执行成功，应该手动释放此结果集</param>
    /// <returns>执行是否成功</returns>
    function ExecSql(aSql: string; out resDataset: TCustomADODataSet;withOpen:Boolean=True): Boolean;
    function CheckIsSysadmin:Boolean;
    function getUpdateSQLfromSelect(table:TdbTableItem; wherekey: string): string;
    property dbok:Boolean read FdBConfigOK;

  end;

implementation

uses
  Windows, SysUtils, dbHelper, comm_func, MakCommonfuncs, loglog,
  Winapi.ADOInt, System.Variants, Data.DB, dbFieldTypes;

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
  //提取基本信息用
  AdoQCs := TCriticalSection.Create;
  ADOConn := TADOConnection.Create(nil);
  ADOConn.LoginPrompt := False;
  ADOConn.KeepConnection := False;

  AdoQ := TADOQuery.Create(nil);
  AdoQ.Connection := ADOConn;
  //Master扩展过程通讯用
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
    //2008之前的版本只能遍历句柄
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
    //2008 之后有了 sys.dm_io_virtual_file_stats 可以直接获取文件句柄
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
          Loger.Add('数据库id与配置不匹配！请重新配置。', LOG_ERROR);
          Exit;
        end;
        if dbVer_Major <> (microsoftversion shr 24) and $FF then
        begin
          Loger.Add('数据库版本与配置不匹配！请重新配置。', LOG_ERROR);
          Exit;
        end;
        if dbVer_Minor <> (microsoftversion shr 16) and $FF then
        begin
          Loger.Add('数据库版本与配置不匹配！请重新配置。', LOG_ERROR);
          Exit;
        end;
        if dbVer_BuildNumber <> microsoftversion and $FFFF then
        begin
          Loger.Add('数据库版本与配置不匹配！请重新配置。', LOG_ERROR);
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
  //查询全部的vlfs
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
        Loger.Add(' ExecSqlOnMaster fail。%s,[%s]', [e.Message, aSql], LOG_ERROR);
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
        Loger.Add(' ExecSql fail。%s,[%s]', [e.Message, aSql], LOG_ERROR);
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
function DumpMemory2Str(data:Pointer; dataSize:Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to dataSize-1 do
  begin
    Result := Result + IntToHex(Pbyte(uintptr(data)+I)^,2);
  end;
end;
function getfieldValueAsString(field: TField): string;
var
  ddSize: Integer;
  buff: Pointer;
  Data: OleVariant;
  blobData: TBytes;
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
        buff := AllocMem(ddSize);
        if field.GetData(buff) then
        begin
          ddSize := Pword(buff)^;
          Result := '0x' + DumpMemory2Str(pointer(Uintptr(buff) + 2), ddSize);
        end;
        FreeMem(buff);
      end;
    ftVariant:
      begin
        //TODO:暂时不支持此类型
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
      buff := AllocMem(ddSize);
      if field.GetData(buff) then
      begin
        Result := '0x' + DumpMemory2Str(buff, ddSize);
      end;
      FreeMem(buff);
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
      //忽略类型
      MsTypes.TIMESTAMP,
      MsTypes.GEOGRAPHY,
      MsTypes.XML,
      MsTypes.SQL_VARIANT:
      Continue;
    else
      //忽略聚合(如果更新聚合可能导致行数据重建(DELETE+INSERT)
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
      for I := 0 to rDataset.Fields.Count -1 do
      begin
        Result := Result + ',['+rDataset.Fields[i].FieldName+']=' + getfieldValueAsString(rDataset.Fields[i]);
      end;
      Delete(Result,1,1);
      rDataset.Free;
    end;
  end
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
  //刷新表信息
  aSql := 'select s.name,a.object_id, a.name from sys.objects a, sys.schemas s where (a.type = ''U'' or a.type = ''S'') and a.schema_id = s.schema_id';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTables(rDataset);
    rDataset.Free;
  end;
  //刷新列信息
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
  //刷新唯一键信息
  aSql := 'select a.id,a.colid from sysindexkeys a join sys.indexes b on a.id=b.object_id and a.indid=b.index_id and is_unique=1 and [type]=1 order by a.id,keyno';
  if ExecSql(aSql, rDataset) then
  begin
    dict.RefreshTablesUniqueKey(rDataset);
    rDataset.Free;
  end;
end;


end.

