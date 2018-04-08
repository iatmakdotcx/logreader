unit cfg;

interface

var
  DBids: Uint64 = 0;

procedure saveCfg();
procedure loadCfg();

implementation

uses
  System.SysUtils, System.Classes, pageCaptureDllHandler;


procedure saveCfg();
var
  sss:string;
  mmo: TMemoryStream;
  wter: TWriter;
begin
  sss := ExtractFilePath(GetModuleName(HInstance));
  sss := sss +'cfg/1.bin';
  mmo := TMemoryStream.Create;
  try
    wter := TWriter.Create(mmo, 1);
    wter.WriteInteger($FB);
    wter.WriteStr('LrExt v 1.0');
    wter.WriteInteger(DBids);
    wter.Free;
    if not ForceDirectories(ExtractFilePath(sss)) then
      raise Exception.Create('无法创建目录：'+SysErrorMessage(GetLastError));
    mmo.SaveToFile(sss);
  finally
    mmo.Free;
  end;
end;

procedure loadCfg();
var
  sss:string;
  mmo: TMemoryStream;
  Rter: TReader;
  tmpStr: string;
begin
  sss := ExtractFilePath(GetModuleName(HInstance));
  sss := sss +'Lrcfg/1.bin';
  mmo := TMemoryStream.Create;
  try
    mmo.LoadFromFile(sss);
    Rter := TReader.Create(mmo, 1);
    try
      if Rter.ReadInteger = $FB then
      begin
        tmpStr := Rter.ReadStr;
        if tmpStr = 'LrExt v 1.0' then
        begin
          DBids :=  Rter.ReadInteger;
          if Assigned(_Lc_Set_Databases) then
          begin
            _Lc_Set_Databases(DBids);
          end;
        end;
      end;
    finally
      Rter.Free;
    end;
  finally
    mmo.Free;
  end;
end;


end.
