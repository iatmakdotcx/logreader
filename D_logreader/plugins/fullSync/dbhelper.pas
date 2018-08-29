unit dbhelper;

interface

const
  DESPASSWORD = 'ifuwants';

var
  dbconStr:array[1..255] of string;
  TransEnable:array[1..255] of Boolean;

function RunSql(dbid:Integer;aSql:string): Boolean;
procedure dbConfig(dbid:Integer);
procedure SavedbConfig;


implementation
uses
  System.SysUtils, loglog, System.Classes, des, System.NetEncoding,db,adodb,
  Winapi.Windows;

procedure loadcfg;
var
  cfgfilepath:string;
  sl:Tstringlist;
  I: Integer;
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
      //sl.Text := DesDecryStr(TNetEncoding.Base64.Decode(sl.Text), DESPASSWORD);
      for I := 1 to 255 do
      begin
        TransEnable[i] := sl.Values['enable_'+IntToStr(i)] = '1';
        dbconStr[i] := sl.Values['ConnStr_'+IntToStr(i)];
      end;
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
  I:Integer;
begin
  try
    cfgfilepath := ExtractFilePath(GetModuleName(HInstance)) + 'lr_fullSync.db';
    sl := Tstringlist.Create;
    try
      for I := 1 to 255 do
      begin
        sl.Values['ConnStr_'+IntToStr(i)] := dbconStr[i];
        if TransEnable[i] then
          sl.Values['enable_'+IntToStr(i)] := '1'
        else
          sl.Values['enable_'+IntToStr(i)] := '0';
      end;
      //sl.Text := TNetEncoding.Base64.Encode(DesEncryStr(sl.Text, DESPASSWORD));
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

procedure dbConfig(dbid:Integer);
var
  TmpStr:string;
begin
  TmpStr := PromptDataSource(0, dbconStr[dbid]);

  if (TmpStr<>'') and (TmpStr<>dbconStr[dbid]) then
  begin
    dbconStr[dbid] := TmpStr;
    SavedbConfig;
  end;
end;

function RunSql(dbid:Integer;aSql:string): Boolean;
var
  adoq:TADOCommand;
begin
  Loger.Add(aSql,LOG_IMPORTANT);
  result := False;
  if TransEnable[dbid] then
  begin
    if dbconStr[dbid]<>'' then
    begin
      try
        adoq := TADOCommand.Create(nil);
        try
          adoq.ParamCheck := False;
          adoq.ConnectionString := dbconStr[dbid];
          adoq.CommandText := aSql;
          adoq.Execute;
          result := True;
        finally
          adoq.Free;
        end;
      except
        on EE:Exception do
        begin
          Loger.Add('dbhelper.RunSql fail!' + EE.Message + WIN_EOL + aSql, LOG_IMPORTANT or LOG_ERROR);
        end;
      end;
    end;
  end;
end;

initialization
  loadcfg

end.
