unit dbHelper;

interface
uses
  ADODB;


function getConnectionString(host,user,pwd,dbName:string):string;

procedure ReSetAdoCrlConnection(ctl:TCustomADODataSet);


implementation

uses
  SysUtils;

function getConnectionString(host,user,pwd,dbName:string):string;
begin
  Result := Format('Provider=SQLOLEDB.1;Persist Security Info=True;Data Source=%s;User ID=%s;Password=%s;Initial Catalog=%s',[host,user,pwd,dbName]);
end;

procedure ReSetAdoCrlConnection(ctl:TCustomADODataSet);
begin
  ctl.ConnectionString := '';

end;

end.
