unit winshellHelper;

interface

/// <summary>
/// 检测指定命令是否有全控制权限
/// </summary>
/// <param name="aDataPath">目录</param>
/// <param name="ServiceAccount">用户</param>
/// <returns></returns>
function Check_LrExtutils_DataPath_Authentication(aDataPath: string; ServiceAccount:string = 'NT SERVICE\MSSQLSERVER'): Boolean;

implementation

uses
  System.SysUtils, Winapi.Windows, System.Classes, MakCommonfuncs, loglog;

procedure Set_LrExtutils_DataPath_Authentication(aDataPath: string; ServiceAccount:string = 'NT SERVICE\MSSQLSERVER');
var
  doCmdstr:string;
  strTmp: string;
begin
  doCmdstr := 'cacls "' + aDataPath + '" /T /e /g "'+ServiceAccount+'":f';
  strTmp := GetDosOutput(doCmdstr);
//  strTmp := '===============================' + WIN_EOL + doCmdstr + WIN_EOL + '===============================' + WIN_EOL + strTmp + WIN_EOL + '===============================';
end;

function Check_LrExtutils_DataPath_Authentication(aDataPath: string; ServiceAccount:string = 'NT SERVICE\MSSQLSERVER'): Boolean;

  function CheckExistsAuthentication: Boolean;
  var
    slsl: TStringList;
    i: Integer;
  begin
    Result := false;
    slsl := TStringList.Create;
    try
      ServiceAccount := UpperCase(ServiceAccount);
      slsl.Text := GetDosOutput('cacls "' + aDataPath + '"');
      slsl.Text := UpperCase(slsl.Text);
      for i := 0 to slsl.Count - 1 do
      begin
      // NT SERVICE\MSSQLSERVER用户必须有子文件的全部访问权限
        if (Pos(ServiceAccount, slsl[i]) > 0) and (Pos('(OI)(CI)F', slsl[i]) > 0) then
        begin
          Result := True;
          Break;
        end;
      end;
    finally
      slsl.Free;
    end;
  end;

begin
  if aDataPath[length(aDataPath)] = '\' then
  begin
    Delete(aDataPath,length(aDataPath),1);
  end;

  //先看看是否有权限
  Result := CheckExistsAuthentication;
  if not Result then
  begin
    //如果没有权限，尝试增加权限！
    Set_LrExtutils_DataPath_Authentication(aDataPath);
  end;
  Result := CheckExistsAuthentication;
end;

end.

