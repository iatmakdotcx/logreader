unit dbhelper;

interface

const
  DESPASSWORD = 'ifuwants';

var
  dbconStr:string = '';
  TransEnable:Boolean = False;

function RunSql(aSql:string): Boolean;
procedure dbConfig;


implementation
uses
  System.SysUtils, loglog, System.Classes, des, System.NetEncoding,db,adodb,
  Winapi.Windows;

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
      sl.Text := DesDecryStr(TNetEncoding.Base64.Decode(sl.Text), DESPASSWORD);
      TransEnable := sl.Values['enable'] = '1';
      dbconStr := sl.Values['ConnStr'];
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
procedure SavedbConfig;
var
  cfgfilepath: string;
  sl: Tstringlist;
begin
  try
    cfgfilepath := ExtractFilePath(GetModuleName(HInstance)) + 'lr_fullSync.db';
    sl := Tstringlist.Create;
    try
      sl.Values['ConnStr'] := dbconStr;
      if TransEnable then
        sl.Values['enable'] := '0'
      else
        sl.Values['enable'] := '1';
      sl.Text := TNetEncoding.Base64.Encode(DesEncryStr(sl.Text, DESPASSWORD));
      sl.SaveToFile(cfgfilepath);
    finally
      sl.Free;
    end;
  except
    on EE: Exception do
    begin
      Loger.Add('dbhelper.SavedbConfig fail!' + EE.Message);
      MessageBox(0, Pchar(EE.Message), '配置失败', MB_OK + MB_ICONSTOP);
    end;
  end;
end;

procedure dbConfig;
var
  TmpStr:string;
begin
  TmpStr := PromptDataSource(0, dbconStr);

  if (TmpStr<>'') and (TmpStr<>dbconStr) then
  begin
    dbconStr := TmpStr;
    SavedbConfig;
  end;
end;

function RunSql(aSql:string): Boolean;
var
  adoq:TADOCommand;
begin
  result := False;
  if TransEnable then
  begin
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
end;

initialization
  loadcfg

end.
