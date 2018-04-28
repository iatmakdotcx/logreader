unit sqlextendedprocHelper;

interface
uses
  databaseConnection, p_structDefine, System.SysUtils;

function checkCfgExists(databaseConnection:TdatabaseConnection):Boolean;
/// <summary>
/// 从数据库接口获取行原始数据（此处可能阻塞 10s
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="LSN"></param>
/// <returns></returns>
function getUpdateSoltData(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;
/// <summary>
/// 根据 Dbcc Page 获取页数据，（不靠谱
/// </summary>
/// <param name="databaseConnection"></param>
/// <param name="Page_Id"></param>
/// <returns></returns>
function getUpdateSoltFromDbccPage(databaseConnection:TdatabaseConnection;Page_Id: TPage_Id):TBytes;

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
  OPTSQLPROCNAME_readLogAsXml = 'master..Lr_roo2';


function CheckExtendedProcExists(databaseConnection:TdatabaseConnection; ProcName:string):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
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
  if not CheckExtendedProcExists(databaseConnection, ProcName) then
  begin
    Result := False;
    //TODO:隐患，可能不在相同目录！！！
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
  Result := nil;
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME_readLog) then
  begin
    aSql := Format('exec %s %d,%d,%d,%d', [OPTSQLPROCNAME_readLog, databaseConnection.dbID, LSN.LSN_1, LSN.LSN_2, LSN.LSN_3]);
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
    begin
      if not rDataset.Eof then
      begin
        Result := rDataset.Fields[1].AsBytes;
      end;
      rDataset.Free;
    end;
  end;
end;

function getUpdateSoltDataXML(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):string;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := '';
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME_readLogAsXml) then
  begin
    aSql := Format('exec %s %d,%d,%d,%d', [OPTSQLPROCNAME_readLogAsXml, databaseConnection.dbID, LSN.LSN_1, LSN.LSN_2, LSN.LSN_3]);
    if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
    begin
      if not rDataset.Eof then
      begin
        Result := rDataset.Fields[1].AsString;
      end;
      rDataset.Free;
    end;
  end;
end;

function setDbOn(databaseConnection:TdatabaseConnection):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
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

end.
