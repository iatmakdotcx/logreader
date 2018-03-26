unit sqlextendedprocHelper;

interface
uses
  databaseConnection;

function checkCfgExists(databaseConnection:TdatabaseConnection):Boolean;


implementation

uses
  Data.Win.ADODB, System.SysUtils, MakCommonfuncs, Winapi.Windows;

const
  OPTSQLPROCNAME = 'Lr_doo';


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

end.
