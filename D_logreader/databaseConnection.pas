unit databaseConnection;

interface

uses
  ADODB, Classes, p_structDefine;

type
  TdatabaseConnection = class(TObject)
  private
    AdoQ:TADOQuery;
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

     constructor Create;
     destructor Destroy;override;
     procedure refreshConnection;

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
begin
  nSize := MAX_COMPUTERNAME_LENGTH;
  GetComputerName(@cmpName, nSize);
  Host := LowerCase(Host);
  if (Host = '.') or (Host = '127.0.0.1') or (Host = 'localhost') or (Host = StrPas(@cmpName)) or (Host = getDb_ComputerNamePhysicalNetBIOS) then
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
  AdoQ := TADOQuery.Create(nil);
end;

destructor TdatabaseConnection.Destroy;
begin
  AdoQ.Free;
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
end;

function TdatabaseConnection.getDb_ComputerNamePhysicalNetBIOS: string;
begin
  AdoQ.sql.Text := 'SELECT CONVERT(nvarchar(256), SERVERPROPERTY(''ComputerNamePhysicalNetBIOS''))';
  AdoQ.Open;
  Result := AdoQ.Fields[0].AsString;
  AdoQ.Close;
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
end;

procedure TdatabaseConnection.refreshConnection;
begin
  if dbName = '' then
    dbName := 'master';
  AdoQ.ConnectionString := getConnectionString(Host, user, PassWd, dbName);
end;

end.
