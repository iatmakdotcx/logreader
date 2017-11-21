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
  lanList.Add('a01=����д���ݿ��������');
  lanList.Add('a02=����д���ݿ��¼�û�����');
  lanList.Add('a03=��ѡ�����ݿ⣡');
  lanList.Add('a04=������������ݿ�����������У�');
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
