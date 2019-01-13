unit lscfgFilteritem;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  Tfrm_lscfgFilteritem = class(TForm)
    RadioGroup1: TRadioGroup;
    Edit1: TEdit;
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frm_lscfgFilteritem: Tfrm_lscfgFilteritem;

implementation

{$R *.dfm}

procedure Tfrm_lscfgFilteritem.Button1Click(Sender: TObject);
begin
  if Edit1.Text = '' then
  begin
    ShowMessage('±ÿ–Î ‰»Îƒ⁄»›£°');
    Exit;
  end;
  Self.ModalResult := mrOk;
end;

end.
