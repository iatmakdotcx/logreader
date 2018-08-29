unit p_HookHelper;

interface


var
  SVR_Sqlmin_md5:string = '';
  SVR_hookPnt_Row:Integer = 0;


procedure HookpreInit;

implementation

uses
  Winapi.Windows, HashHelper, dbhelper, loglog, System.SysUtils, pageCaptureDllHandler,
  cfg;

procedure HookpreInit;
var
  hdl: tHandle;
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  hookPnt: Integer;
  dllPath: string;
begin
  hdl := GetModuleHandle('sqlmin.dll');
  if (hdl <> 0) then
  begin
    ZeroMemory(@Pathbuf[0], MAX_PATH + 2);
    GetModuleFileName(hdl, Pathbuf, MAX_PATH);
    SVR_Sqlmin_md5 := GetFileHashMD5(Pathbuf);
    try
      if DBH.cfg(SVR_Sqlmin_md5, hookPnt, dllPath) then
      begin
        SVR_hookPnt_Row := hookPnt;
        pageCapture_init(dllPath);
        _Lc_Set_Databases(cfg.CFG_DBids);
      end;
    except
      on e: Exception do
      begin
        Loger.add('preInit Ê§°Ü£¡'+e.Message)
      end;
    end;
  end;

end;


end.
