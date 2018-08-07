unit winshellHelper;

interface

/// <summary>
/// ���ָ�������Ƿ���ȫ����Ȩ��
/// </summary>
/// <param name="aDataPath">Ŀ¼</param>
/// <param name="ServiceAccount">�û�</param>
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
  strTmp := '===============================' + WIN_EOL + doCmdstr + WIN_EOL + '===============================' + WIN_EOL + strTmp + WIN_EOL + '===============================';
  loger.add(strTmp);
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
      // NT SERVICE\MSSQLSERVER�û����������ļ���ȫ������Ȩ��
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

  //�ȿ����Ƿ���Ȩ��
  Result := CheckExistsAuthentication;
  if not Result then
  begin
    //���û��Ȩ�ޣ���������Ȩ�ޣ�
    Set_LrExtutils_DataPath_Authentication(aDataPath);
  end;
  Result := CheckExistsAuthentication;
end;

end.

