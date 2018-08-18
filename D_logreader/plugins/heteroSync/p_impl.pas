unit p_impl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, System.Contnrs,
  plgSrcData, pppppp;

type
  Tfrm_impl = class(TForm)
    ListView1: TListView;
    GroupBox1: TGroupBox;
    btn_add: TButton;
    btn_enable: TButton;
    btn_del: TButton;
    btn_cfg: TButton;
    procedure btn_addClick(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure btn_enableClick(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure btn_cfgClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    ImplsManger : TImplsManger;
    procedure RefreshList;
    { Private declarations }
  public
    source:Pplg_source;
    { Public declarations }
  end;

var
  frm_impl: Tfrm_impl;


implementation

uses
  dbcfg, Des, loglog, p_mainCfg;

{$R *.dfm}


procedure Tfrm_impl.btn_cfgClick(Sender: TObject);
var
  frm_mainCfg: Tfrm_mainCfg;
begin
  if ListView1.Selected<>nil then
  begin
    frm_mainCfg := Tfrm_mainCfg.Create(nil);
    try
      frm_mainCfg.implItem := TImplsItem(ListView1.Selected.Data);
      frm_mainCfg.showmodal;
    finally
      frm_mainCfg.free;
    end;
  end;
end;

procedure Tfrm_impl.btn_enableClick(Sender: TObject);
var
  impItem:TImplsItem;
begin
  if ListView1.Selected<>nil then
  begin
    impItem := TImplsItem(ListView1.Selected.Data);
    if btn_enable.Caption = '启用' then
    begin
      btn_enable.Caption := '停用';
      impItem.Paused := False;
    end else begin
      btn_enable.Caption := '启用';
      impItem.Paused := True;
    end;
    RefreshList;
  end;
end;

procedure Tfrm_impl.FormShow(Sender: TObject);
begin
  ImplsManger := LrSvrJob.Get(source);
  RefreshList;
end;

function GUIDToString(const Guid: TGUID): string;
begin
  Result := Format('%.8x-%.4x-%.4x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x',   // do not localize
    [Guid.D1, Guid.D2, Guid.D3, Guid.D4[0], Guid.D4[1], Guid.D4[2], Guid.D4[3],
    Guid.D4[4], Guid.D4[5], Guid.D4[6], Guid.D4[7]])
end;

procedure Tfrm_impl.btn_addClick(Sender: TObject);
var
  impItem:TImplsItem;
  uid:TGUID;
begin
  frm_dbcfg := Tfrm_dbcfg.create(nil);
  try
    if frm_dbcfg.ShowModal = mrok then
    begin
      impItem := ImplsManger.find(frm_dbcfg.dbcfg_Host, frm_dbcfg.dbcfg_dbName);
      if impItem <> nil then
      begin
        MessageBox(Handle, '相同实例已存在！', '实例已存在', MB_OK + MB_ICONSTOP);
        Exit;
      end;
      CreateGUID(uid);
      impItem := TImplsItem.Create;
      impItem.Host := frm_dbcfg.dbcfg_Host;
      impItem.user := frm_dbcfg.dbcfg_user;
      impItem.pass := frm_dbcfg.dbcfg_pass;
      impItem.dbName := frm_dbcfg.dbcfg_dbName;
      impItem.uid := GUIDToString(uid);
      ImplsManger.Add(impItem);
      ImplsManger.save;
      RefreshList;
    end;
  finally
    frm_dbcfg.free;
  end;
end;

procedure Tfrm_impl.ListView1DblClick(Sender: TObject);
begin
  btn_cfg.Click;
end;

procedure Tfrm_impl.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  impItem:TImplsItem;
begin
  btn_enable.Enabled := true;
  btn_del.Enabled := true;
  btn_cfg.Enabled := true;

  impItem := TImplsItem(Item.Data);
  if impItem.getState = Pause then
  begin
    btn_enable.Caption := '启用';
  end else begin
    btn_enable.Caption := '停用';
  end;
end;

procedure Tfrm_impl.RefreshList;
var
  I:Integer;
  impItem:TImplsItem;
begin
  ListView1.Clear;
  for I := 0 to ImplsManger.Count-1 do
  begin
    impItem := TImplsItem(ImplsManger.items[i]);
    with ListView1.Items.Add do
    begin
      Caption := impItem.Host;
      SubItems.Add(impItem.dbName);
      case impItem.getState of
        Unconfigured:
          SubItems.Add('未配置');
        Normal:
          SubItems.Add('正常');
        Pause:
          SubItems.Add('停用');
      end;
      Data := impItem;
    end;
  end;
end;


end.
