unit dbhelper;

interface

uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDBH = class(TObject)
  private
    DBConnt: TFDConnection;
    Qry: TFDQuery;
    function tableExists(tableName: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function checkMd5(md5Str: string): Boolean;
    function cfg(md5Str: string; var pnt: Integer; var dll: string): Boolean;
  end;

var
  DBH: TDBH;

procedure init;

implementation

uses
  Winapi.Windows, System.SysUtils, SqlSvrHelper, pluginlog;

procedure init;
begin
  DBH := TDBH.Create;
end;

{ TDBH }

function TDBH.cfg(md5Str: string; var pnt: Integer; var dll: string): Boolean;
var
  sSQL: string;
begin
  sSQL := 'select a.pnt,a.pnt2,b.dllpath from cfg a join dlls b on a.bin=b.id where `hash`="' + md5Str + '"';
  Qry.Close;
  Qry.Open(sSQL);
  if Qry.RecordCount > 0 then
  begin
    pnt := Qry.FieldByName('pnt').AsInteger;
    dll := Qry.FieldByName('dllpath').AsString;
    Result := True;
  end
  else
  begin
    Result := False;
  end;
  Qry.Close;
  Qry.Connection.Connected := False;
end;

function TDBH.checkMd5(md5Str: string): Boolean;
var
  sSQL: string;
begin
  if tableExists('cfg') then
  begin
    sSQL := 'select 1 from cfg where `hash`="' + md5Str + '"';
    Qry.Close;
    Qry.Open(sSQL);
    Result := Qry.RecordCount > 0;
    Qry.Close;
    Qry.Connection.Connected := False;
  end
  else
  begin
    Loger.Add('mapdb.cfg²»´æÔÚ£¡', LOG_ERROR);
    result := False;
  end;
end;

constructor TDBH.Create;
var
  buffPath: array[0..MAX_PATH + 2] of Char;
  dbPath: string;
begin
  GetModuleFileName(HInstance, buffPath, MAX_PATH);
  dbPath := ExtractFilePath(string(buffPath)) + 'mapdb.db';
  Loger.Add('mapdb:'+dbPath);
  DBConnt := TFDConnection.Create(nil);
  DBConnt.Params.Clear;
  DBConnt.Params.Add('Database=' + dbPath);
  DBConnt.Params.Add('DriverID=SQLite');
  DBConnt.TxOptions.AutoCommit := False;
  Qry := TFDQuery.Create(nil);
  Qry.Connection := DBConnt;
  Qry.CachedUpdates := True;
end;

destructor TDBH.Destroy;
begin
  DBConnt.Free;
  Qry.Free;
  inherited;
end;

function TDBH.tableExists(tableName: string): Boolean;
var
  sSQL: string;
begin
  sSQL := 'SELECT 1 FROM sqlite_master where type="table" and name="' + tableName + '"';
  Qry.Close;
  Qry.Open(sSQL);
  Result := Qry.RecordCount > 0;
  Qry.Close;
  Qry.Connection.Connected := False;
end;

initialization

finalization
  DBH.Free;

end.

