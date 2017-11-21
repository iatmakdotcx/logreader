unit ConstString;

interface

const
  datapath = '/Data';

function getConstStr(key:string):string;

implementation

uses
  IniFiles;

var
   lanList:THashedStringList;

procedure lanInit;
begin
  lanList := THashedStringList.Create;
  lanList.Add('a01=请填写数据库服务器！');
  lanList.Add('a02=请填写数据库登录用户名！');
  lanList.Add('a03=请选择数据库！');
  lanList.Add('a04=本程序必须数据库服务器上运行！');
end;

function getConstStr(key:string):string;
begin
  Result := lanList.Values[key];
end;

initialization
  lanInit;

finalization
  lanList.Free;


end.
