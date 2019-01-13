unit lscfg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  LogSource;

type
  Tfrm_lscfg = class(TForm)
    ListBox1: TListBox;
    PageControl1: TPageControl;
    tab_base: TTabSheet;
    tab_filter: TTabSheet;
    RadioGroup1: TRadioGroup;
    btn_filter_add: TButton;
    btn_filter_delete: TButton;
    btn_refresh: TButton;
    procedure btn_filter_addClick(Sender: TObject);
    procedure btn_refreshClick(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    logsource:TLogSource;
    { Public declarations }
  end;

var
  frm_lscfg: Tfrm_lscfg;

implementation
uses
  lscfgFilteritem, dbDict, System.Contnrs;

{$R *.dfm}

procedure Tfrm_lscfg.btn_refreshClick(Sender: TObject);
var
  I: Integer;
begin
  RadioGroup1.ItemIndex := logsource.FilterType;
  ListBox1.Clear;
  for I := 0 to logsource.FilterList.Count - 1 do
  begin
    ListBox1.Items.Add(TtableFilterItem(logsource.FilterList[I]).ToString);
  end;
end;

procedure Tfrm_lscfg.FormShow(Sender: TObject);
begin
  btn_refresh.Click;
  RadioGroup1Click(nil);
end;

procedure Tfrm_lscfg.btn_filter_addClick(Sender: TObject);
var
  tfi:TtableFilterItem;
begin
  frm_lscfgFilteritem := Tfrm_lscfgFilteritem.create(nil);
  try
    frm_lscfgFilteritem.Edit1.Text := '';
    if frm_lscfgFilteritem.ShowModal = mrOk then
    begin
      tfi := TtableFilterItem.create;
      tfi.filterType := frm_lscfgFilteritem.RadioGroup1.ItemIndex;
      tfi.valueStr := frm_lscfgFilteritem.Edit1.Text;
      logsource.FilterList.Add(tfi);
      btn_refresh.Click;
    end;
  finally
    frm_lscfgFilteritem.Free;
  end;
end;

procedure Tfrm_lscfg.RadioGroup1Click(Sender: TObject);
begin
  if RadioGroup1.ItemIndex = 0 then
  begin
    ListBox1.Enabled := False;
    btn_filter_add.Enabled := False;
    btn_filter_delete.Enabled := False;
  end
  else
  begin
    ListBox1.Enabled := True;
    btn_filter_add.Enabled := True;
    btn_filter_delete.Enabled := True;
  end;
  logsource.FilterType := RadioGroup1.ItemIndex;
end;

end.
