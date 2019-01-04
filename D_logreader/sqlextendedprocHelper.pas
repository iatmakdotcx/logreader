unit sqlextendedprocHelper;

interface
uses
  databaseConnection, p_structDefine, System.SysUtils;

function checkCfgExists(databaseConnection:TdatabaseConnection):Boolean;
/// <summary>
/// �����ݿ�ӿڻ�ȡ��ԭʼ���ݣ��˴��������� 10s
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="LSN"></param>
/// <returns></returns>
function getUpdateSoltData(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;
/// <summary>
/// ���� Dbcc Page ��ȡҳ���ݣ���������
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="Page_Id"></param>
/// <returns></returns>
function getUpdateSoltFromDbccPage(databaseConnection:TdatabaseConnection;Page_Id: TPage_Id):TBytes;
/// <summary>
/// ���� Dbcc Page ��ȡ��ҳ���ݣ�����m_lsn����ҳ��ʷ
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="Page_Id"></param>
/// <returns></returns>
function getDbccPageFull(databaseConnection:TdatabaseConnection;Page_Id: TPage_Id):TBytes;
/// <summary>
/// ͨ��fnlog��ȡ��־��¼�������־���ضϣ�������ܻ�ȡʧ�ܡ������ֲ���ֱ�Ӷ��ļ�������
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="LSN"></param>
/// <returns></returns>
function getSingleTransLogFromFndblog(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;

function setDbOn(databaseConnection:TdatabaseConnection):Boolean;
function setDbOff(databaseConnection:TdatabaseConnection):Boolean;

function setCapLogStart(databaseConnection:TdatabaseConnection):Boolean;
function setCapLogStop(databaseConnection:TdatabaseConnection):Boolean;

implementation

uses
  Data.Win.ADODB, MakCommonfuncs, Winapi.Windows, Memory_Common;

const
  OPTSQLPROCNAME = 'master..Lr_doo';
  OPTSQLPROCNAME_readLog = 'master..Lr_roo';


function CheckExtendedProcExists(databaseConnection:TdatabaseConnection; ProcName:string):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := False;
  aSql := Format('select object_id(''%s'',''X'')', [ProcName]);
  if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
  begin
    if not rDataset.Eof then
    begin
      if rDataset.fields[0].asString<>'' then
      begin
        Result := True;
      end;
    end;
  end;
  rDataset.Free;
end;

function CreateExtendedProc(databaseConnection:TdatabaseConnection; ProcName:string):Boolean;
var
  rDataset:TCustomADODataSet;
  dllPath:string;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  if not CheckExtendedProcExists(databaseConnection, ProcName) then
  begin
    Result := False;
    //TODO:���������ܲ�����ͬĿ¼������
    dllPath := ExtractFilePath(GetModuleName(HInstance)) + 'LrExtutils.dll';
    aSql := Format('exec sp_addextendedproc ''%s'',''%s'' ',[ProcName, dllPath]);
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset, False) then
    begin
      if CheckExtendedProcExists(databaseConnection, ProcName) then
      begin
        Result := True;
      end;
    end;
  end else begin
    Result := True;
  end;
end;

function checkCfgExists(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := false;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
  begin
    aSql := 'exec ' + OPTSQLPROCNAME + ' ''G''';
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
    begin
      if rDataset.Fields[0].AsString = '1' then
      begin
        Result := True;
      end;
      rDataset.Free;
    end;
  end;
end;


function getUpdateSoltData(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := nil;
  aSql := Format('exec %s %d,%d,%d,%d', [OPTSQLPROCNAME_readLog, databaseConnection.dbID, LSN.LSN_1, LSN.LSN_2, LSN.LSN_3]);
  if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
  begin
    if not rDataset.Eof then
    begin
      Result := rDataset.Fields[1].AsBytes;
    end;
    rDataset.Free;
  end
  else
  begin
    if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME_readLog) then
    begin
      if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
      begin
        if not rDataset.Eof then
        begin
          Result := rDataset.Fields[1].AsBytes;
        end;
        rDataset.Free;
      end
    end;
  end;
end;

function setDbOn(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := false;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
  begin
    aSql := 'exec ' + OPTSQLPROCNAME + ' ''B+'','+IntToStr(databaseConnection.dbID);
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset, False) then
    begin
    end;
  end;
end;

function setDbOff(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := false;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
  begin
    aSql := 'exec ' + OPTSQLPROCNAME + ' ''B-'','+IntToStr(databaseConnection.dbID);
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset, False) then
    begin
    end;
  end;
end;

function setCapLogStart(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := false;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
  begin
    aSql := 'exec ' + OPTSQLPROCNAME + ' ''A''';
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset, False) then
    begin
    end;
  end;
end;

function setCapLogStop(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
 raise Exception.Create('not allowed!');
  Result := false;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
  begin
    aSql := 'exec ' + OPTSQLPROCNAME + ' ''F''';
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset, False) then
    begin
    end;
  end;
end;

function getUpdateSoltFromDbccPage(databaseConnection:TdatabaseConnection;Page_Id: TPage_Id):TBytes;
var
  rDataset:TCustomADODataSet;
  aSql:string;
  ResData:string;
begin
 raise Exception.Create('not allowed!');
  Result := nil;
  aSql := 'create table #a(p varchar(100),o varchar(100),f varchar(100),v varchar(100)) ';
  aSql := aSql + Format(' insert into #a exec(''dbcc page(%s,%d,%d,1)with tableresults'') ',[databaseConnection.dbName,Page_Id.FID,Page_Id.PID]);
  if databaseConnection.dbIs64bit then
  begin
    aSql := aSql + Format(' select substring(v,21,44) from #a where p like ''Slot %d,%%'' ',[Page_Id.solt]);
  end else begin
    aSql := aSql + Format(' select substring(v,13,44) from #a where p like ''Slot %d,%%'' ',[Page_Id.solt]);
  end;
  aSql := aSql + ' drop table #a';
  if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
  begin
    ResData := '';
    rDataset.first;
    while not rDataset.Eof do
    begin
      ResData := ResData + rDataset.Fields[0].AsString;
      rDataset.Next;
    end;
    rDataset.Free;
    try
      Result := strToBytes(ResData);
    except
      Result := nil;
    end;
  end;
end;

function getDbccPageFull(databaseConnection:TdatabaseConnection;Page_Id: TPage_Id):TBytes;
var
  rDataset:TCustomADODataSet;
  aSql:string;
  ResData:string;
begin
  Result := nil;
  aSql := 'create table #a(p varchar(100),o varchar(100),f varchar(100),v varchar(100)) ';
  aSql := aSql + Format(' insert into #a exec(''dbcc page(%s,%d,%d,2)with tableresults'') ',[databaseConnection.dbName,Page_Id.FID,Page_Id.PID]);
  if databaseConnection.dbIs64bit then
  begin
    aSql := aSql + ' select substring(v,21,44) from #a where o like ''Memory Dump%'' ';
  end else begin
    aSql := aSql + ' select substring(v,13,44) from #a where o like ''Memory Dump%'' ';
  end;
  aSql := aSql + ' drop table #a';
  if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
  begin
    ResData := '';
    rDataset.first;
    while not rDataset.Eof do
    begin
      ResData := ResData + rDataset.Fields[0].AsString;
      rDataset.Next;
    end;
    rDataset.Free;
    try
      Result := strToBytes(ResData);
    except
      Result := nil;
    end;
  end;
end;

function getSingleTransLogFromFndblog(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := nil;
  aSql := LSN2Str(LSN);
  aSql := Format('select [Log Record] from fn_dblog(''%s'',''%s'') ', [aSql, aSql]);
  if databaseConnection.ExecSql(aSql, rDataset) then
  begin
    if not rDataset.Eof then
    begin
      Result := rDataset.Fields[0].AsBytes;
    end;
    rDataset.Free;
  end;
end;


end.
