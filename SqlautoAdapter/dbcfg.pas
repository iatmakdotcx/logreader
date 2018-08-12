unit dbcfg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Data.DB,
  Data.Win.ADODB;

type
  Tfrm_dbcfg = class(TForm)
    Label1: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    Button1: TButton;
    Button2: TButton;
    ADOConnection1: TADOConnection;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

function getConnectionString(host, user, pwd: string): string;

var
  frm_dbcfg: Tfrm_dbcfg;
  dbcfg_Host: string;
  dbcfg_user: string;
  dbcfg_pass: string;

implementation
uses
  main;

{$R *.dfm}

function getConnectionString(host, user, pwd: string): string;
begin
  Result := Format('Provider=SQLOLEDB.1;Persist Security Info=True;Data Source=%s;User ID=%s;Password=%s;Initial Catalog=master', [host, user, pwd]);
end;

procedure Tfrm_dbcfg.Button1Click(Sender: TObject);
begin
  ADOConnection1.Close;
  ADOConnection1.ConnectionString := getConnectionString(Edit1.Text, Edit2.Text, Edit3.Text);
  ADOConnection1.Connected := True;
  if ADOConnection1.Connected then
  begin
    dbcfg_Host := Edit1.Text;
    dbcfg_user := Edit2.Text;
    dbcfg_pass := Edit3.Text;
    Self.ModalResult := mrOk;
  end;
end;

procedure Tfrm_dbcfg.Button2Click(Sender: TObject);
begin
  Self.ModalResult := mrCancel;
end;

procedure Tfrm_dbcfg.FormCreate(Sender: TObject);
begin
  Edit1.Text := dbcfg_Host;
  Edit2.Text := dbcfg_user;
  Edit3.Text := dbcfg_pass;

  {$IFDEF DEBUG}
   Edit1.Text := '127.0.0.1';
   Edit2.Text := 'sa';
   Edit3.Text := 'aa1234569';
  {$ENDIF}
end;

end.

