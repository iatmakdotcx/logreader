unit cfg;

interface

var
  CFG_DBids: Uint64 = 0;

procedure saveCfg;


implementation

uses
  System.SysUtils, System.Classes, pageCaptureDllHandler, loglog;


procedure saveCfg;
var
  sss:string;
  cfgStrl: TStringList;
begin
  try
    sss := ExtractFilePath(GetModuleName(HInstance));
    sss := sss +'cfg/LreCfg.bin';
    ForceDirectories(ExtractFilePath(sss));
    cfgStrl := TStringList.Create;
    try
      cfgStrl.Values['DBids'] := UIntToStr(CFG_DBids);
      //TODO:¼ÓÃÜ
      cfgStrl.SaveToFile(sss);
    finally
      cfgStrl.Free;
    end;
  except
    on eee:Exception do
    begin
      DefLoger.add('cfg.saveCfg=>'+eee.Message, LOG_ERROR);
    end;
  end;
end;

procedure loadCfg;
var
  sss:string;
  cfgStrl: TStringList;
begin
  try
    sss := ExtractFilePath(GetModuleName(HInstance));
    sss := sss + 'cfg/LreCfg.bin';
    cfgStrl := TStringList.Create;
    try
      cfgStrl.LoadFromFile(sss);
      //TODO:½âÃÜ
      CFG_DBids := StrToUInt64Def(cfgStrl.Values['DBids'], 0);
      if Assigned(_Lc_Set_Databases) then
      begin
        _Lc_Set_Databases(CFG_DBids);
      end;
    finally
      cfgStrl.Free;
    end;
  except
    on eee: Exception do
    begin
      DefLoger.add('cfg.loadCfg=>' + eee.Message, LOG_ERROR);
    end;
  end;
end;

initialization
  loadCfg;

finalization
  saveCfg;


end.
