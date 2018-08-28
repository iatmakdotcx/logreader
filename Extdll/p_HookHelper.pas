unit p_HookHelper;

interface


var
  SVR_Sqlmin_md5:string = '';
  SVR_hookPnt_Row:Integer = 0;


procedure HookpreInit;

implementation

uses
  Winapi.Windows, HashHelper, dbhelper, loglog, System.SysUtils, pageCaptureDllHandler;

procedure HookpreInit;
var
  hdl: tHandle;
  Pathbuf: array[0..MAX_PATH + 2] of Char;
  sqlminMD5: string;
  hookPnt: Integer;
  dllPath: string;
begin
  hdl := GetModuleHandle('sqlmin.dll');
  if (hdl <> 0) then
  begin
    ZeroMemory(@Pathbuf[0], MAX_PATH + 2);
    GetModuleFileName(hdl, Pathbuf, MAX_PATH);
    sqlminMD5 := GetFileHashMD5(Pathbuf);
    Loger.add('preInit =============================');
    try
      if DBH.cfg(sqlminMD5, hookPnt, dllPath) then
      begin
        SVR_hookPnt_Row := hookPnt;
        pageCapture_init(dllPath);
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
