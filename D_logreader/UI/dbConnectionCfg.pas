unit dbConnectionCfg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, databaseConnection;

type
  Tfrm_dbConnectionCfg = class(TForm)
    Label1: TLabel;
    edt_svr: TEdit;
    Label2: TLabel;
    edt_user: TEdit;
    Label3: TLabel;
    edt_passwd: TEdit;
    Label4: TLabel;
    edt_DatabaseName: TComboBox;
    btn_ok: TButton;
    btn_cancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure edt_DatabaseNameDropDown(Sender: TObject);
    procedure btn_okClick(Sender: TObject);
  private
    { Private declarations }
  public
    databaseConnection:TdatabaseConnection;
    { Public declarations }
  end;

var
  frm_dbConnectionCfg: Tfrm_dbConnectionCfg;

implementation

uses
  dbHelper, ConstString;

{$R *.dfm}

procedure Tfrm_dbConnectionCfg.btn_okClick(Sender: TObject);
begin
  if edt_svr.Text = '' then
  begin
    Application.MessageBox(PChar(getConstStr('a01')), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_svr.SetFocus;
    exit;
  end;
  if edt_user.Text = '' then
  begin
    Application.MessageBox(PChar(getConstStr('a02')), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_user.SetFocus;
    exit;
  end;
  if edt_DatabaseName.Text = '' then
  begin
    Application.MessageBox(PChar(getConstStr('a03')), PChar(Caption), MB_OK + MB_ICONINFORMATION);
    edt_DatabaseName.SetFocus;
    exit;
  end;
  
  databaseConnection.Host := edt_svr.Text;
  databaseConnection.user := edt_user.Text;
  databaseConnection.PassWd := edt_passwd.Text;
  databaseConnection.dbName := edt_DatabaseName.Text;
  
  if not databaseConnection.CheckIsLocalHost then
  begin
    Application.MessageBox(PChar(getConstStr('a04')), PChar(Caption), MB_OK + MB_ICONINFORMATION);
  end
  else
  begin
    Self.ModalResult := mrOk;
  end;
end;


procedure Tfrm_dbConnectionCfg.edt_DatabaseNameDropDown(Sender: TObject);
var
  dbs:TStringList;
  I: Integer;
begin
  databaseConnection.Host := edt_svr.Text;
  databaseConnection.user := edt_user.Text;
  databaseConnection.PassWd := edt_passwd.Text;
  databaseConnection.dbName := 'master';
  databaseConnection.refreshConnection;
  dbs := databaseConnection.getDb_AllDatabases;
  try
    for I := 0 to dbs.Count - 1 do
    begin
      edt_DatabaseName.Items.Add(dbs[i]);
    end;
  finally
    dbs.Free;
  end;
end;

procedure Tfrm_dbConnectionCfg.FormCreate(Sender: TObject);
begin
{$IFDEF DEBUG}
  edt_svr.Text := '.';
  edt_user.Text := 'sa';
  edt_passwd.Text := 'aa1234569';
{$ENDIF}

 databaseConnection := TdatabaseConnection.create;
end;

end.

