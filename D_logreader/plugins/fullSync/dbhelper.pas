unit dbhelper;

interface

const
  DESPASSWORD = 'ifuwants';

var
  dbconStr:string = '';

function RunSql(aSql:string): Boolean;


implementation
uses
  System.SysUtils, loglog, System.Classes, des, System.NetEncoding,db,adodb;

procedure loadcfg;
var
  cfgfilepath:string;
  sl:Tstringlist;
begin
  cfgfilepath := ExtractFilePath(GetModuleName(HInstance))+'lr_fullSync.db';
  if not FileExists(cfgfilepath) then
  begin
    Loger.Add('数据库配置文件不存在！' + cfgfilepath, LOG_ERROR);
    Exit;
  end;
  try
    sl := Tstringlist.Create;
    try
      sl.LoadFromFile(cfgfilepath);
      dbconStr := DesDecryStr(TNetEncoding.Base64.Decode(sl.Text), DESPASSWORD);
    finally
      sl.Free;
    end;
  except
    on EE:Exception do
    begin
      Loger.Add('dbhelper.loadcfg fail!' + EE.Message);
    end;
  end;
end;

function RunSql(aSql:string): Boolean;
var
  adoq:TADOCommand;
begin
  result := False;
  if dbconStr='' then
  begin
    loadcfg;
  end;
  if dbconStr<>'' then
  begin
    try
      adoq := TADOCommand.Create(nil);
      try
        adoq.ConnectionString := dbconStr;
        adoq.CommandText := aSql;
        adoq.Execute;
        result := True;
      finally
        adoq.Free;
      end;
    except
      on EE:Exception do
      begin
        Loger.Add('dbhelper.RunSql fail!' + EE.Message + WIN_EOL + aSql);
      end;
    end;
  end;
end;

initialization

end.
