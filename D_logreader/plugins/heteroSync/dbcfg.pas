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
    Label4: TLabel;
    edt_DatabaseName: TComboBox;
    ADOQuery1: TADOQuery;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure edt_DatabaseNameDropDown(Sender: TObject);
  private
    { Private declarations }
  public
    dbcfg_Host: string;
    dbcfg_user: string;
    dbcfg_pass: string;
    dbcfg_dbName: string;
    { Public declarations }
  end;


var
  frm_dbcfg: Tfrm_dbcfg;


implementation

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
    dbcfg_dbName := edt_DatabaseName.Text;
    Self.ModalResult := mrOk;
  end;
end;

procedure Tfrm_dbcfg.Button2Click(Sender: TObject);
begin
  Self.ModalResult := mrCancel;
end;

procedure Tfrm_dbcfg.edt_DatabaseNameDropDown(Sender: TObject);
begin
  ADOConnection1.Close;
  ADOConnection1.Connected := False;
  ADOConnection1.ConnectionString := getConnectionString(Edit1.Text, Edit2.Text, Edit3.Text);
  ADOConnection1.Connected := True;

  ADOQuery1.close;
  ADOQuery1.sql.Text := 'select name from sys.databases order by 1';
  ADOQuery1.open;
  edt_DatabaseName.Clear;
  while not ADOQuery1.eof do
  begin
    edt_DatabaseName.Items.Add(ADOQuery1.Fields[0].AsString);
    ADOQuery1.Next;
  end;
end;

procedure Tfrm_dbcfg.FormCreate(Sender: TObject);
begin
  Edit1.Text := dbcfg_Host;
  Edit2.Text := dbcfg_user;
  Edit3.Text := dbcfg_pass;
  if dbcfg_dbName <> '' then
  begin
    edt_DatabaseName.Items.Add(dbcfg_dbName);
    edt_DatabaseName.ItemIndex := 0;
  end;

  {$IFDEF DEBUG}
   Edit1.Text := '127.0.0.1';
   Edit2.Text := 'sa';
   Edit3.Text := 'aa1234569';
   edt_DatabaseName.Items.Add('dbt2');
   edt_DatabaseName.ItemIndex := 0;
  {$ENDIF}
end;

end.

