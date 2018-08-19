unit cfgForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, plgSrcData;

type
  Tfrm_cfg = class(TForm)
    CheckBox1: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    GroupBox1: TGroupBox;
    Button1: TButton;
    Button2: TButton;
    procedure Button1Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    source:Pplg_source;
    { Public declarations }
  end;

var
  frm_cfg: Tfrm_cfg;

implementation

uses
  dbHelper;

{$R *.dfm}

procedure Tfrm_cfg.Button1Click(Sender: TObject);
begin
  dbConfig(source.dbID);
  CheckBox1Click(nil);
end;

procedure Tfrm_cfg.Button2Click(Sender: TObject);
begin
  TransEnable[source.dbID] := CheckBox1.Checked;
  SavedbConfig;
  ShowMessage('����ɹ���');
  Self.ModalResult := mrOk;
end;

procedure Tfrm_cfg.CheckBox1Click(Sender: TObject);
var
  ss: TStringList;
begin
  if CheckBox1.Checked then
  begin
    Button1.Enabled := True;
    ss := TStringList.Create;
    ss.StrictDelimiter := True;
    ss.Delimiter := ';';
    ss.DelimitedText := dbconStr[source.dbID];
    Edit1.Text := ss.Values['Data Source'];
    Edit2.Text := ss.Values['Initial Catalog'];
    ss.Free;
  end
  else
  begin
    Button1.Enabled := false;
    Edit1.Text := '';
    Edit2.Text := '';
  end;
end;

procedure Tfrm_cfg.FormShow(Sender: TObject);
begin
  CheckBox1.Checked := TransEnable[source.dbID];
  CheckBox1Click(nil);
end;

end.

