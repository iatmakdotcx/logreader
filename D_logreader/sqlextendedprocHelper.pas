unit sqlextendedprocHelper;

interface
uses
  databaseConnection, p_structDefine, System.SysUtils;

function checkCfgExists(databaseConnection:TdatabaseConnection):Boolean;
function getUpdateSoltData(databaseConnection:TdatabaseConnection;LSN: Tlog_LSN):TBytes;
function setDbOn(databaseConnection:TdatabaseConnection):Boolean;
function setDbOff(databaseConnection:TdatabaseConnection):Boolean;

function setCapLogStart(databaseConnection:TdatabaseConnection):Boolean;
function setCapLogStop(databaseConnection:TdatabaseConnection):Boolean;

implementation

uses
  Data.Win.ADODB, MakCommonfuncs, Winapi.Windows;

const
  OPTSQLPROCNAME = 'Lr_doo';
  OPTSQLPROCNAME_readLog = 'Lr_roo';
  OPTSQLPROCNAME_readLogAsXml = 'Lr_roo2';


function CheckExtendedProcExists(databaseConnection:TdatabaseConnection; ProcName:string):Boolean;
var
  rDataset:TCustomADODataSet;
  aSql:string;
begin
  Result := False;
  aSql := Format('select object_id from sys.extended_procedures where name=''%s''', [ProcName]);
  if databaseConnection.ExecSqlOnMaster(aSql, rDataset) then
  begin
    if not rDataset.Eof then
    begin
      Result := True;
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
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
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
  if CreateExtendedProc(databaseConnection, OPTSQLPROCNAME) then
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

end.
