unit p_impl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, System.Contnrs,
  p_main;

type
  TImplsItemState = (Unconfigured, Normal, Pause);

  TImplsItem = class(TObject)
    uid:string;
    Host:string;
    user:string;
    pass:string;
    dbName:string;
    TableOptDef: TTableOptDef;
    Paused:Boolean;
    constructor Create;
    destructor Destroy; override;
    function getState:TImplsItemState;
  end;

  TImplsManger = class(TObject)
    items:TObjectList;
    constructor Create;
    destructor Destroy; override;
    function find(Host:string;dbName:string):TImplsItem;
  end;

type
  Tfrm_impl = class(TForm)
    ListView1: TListView;
    GroupBox1: TGroupBox;
    Button1: TButton;
    btn_enable: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure btn_enableClick(Sender: TObject);
  private
    procedure RefreshList;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frm_impl: Tfrm_impl;
  ImplsManger:TImplsManger;

implementation

uses
  dbcfg;

{$R *.dfm}


{ TImplsManger }

constructor TImplsManger.Create;
begin
  items := TObjectList.Create;
end;

destructor TImplsManger.Destroy;
begin
  items.Free;
  inherited;
end;

function TImplsManger.find(Host, dbName: string): TImplsItem;
var
  I: Integer;
begin
  result := nil;
  for I := 0 to items.Count-1 do
  begin
    if (TImplsItem(items.Items[I]).Host = Host) and (TImplsItem(items.Items[I]).dbName = dbName) then
    begin
      Result := TImplsItem(items.Items[I]);
    end;
  end;
end;

procedure Tfrm_impl.btn_enableClick(Sender: TObject);
var
  impItem:TImplsItem;
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

procedure Tfrm_impl.Button1Click(Sender: TObject);
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
      ImplsManger.items.Add(impItem);

      RefreshList;
    end;
  finally
    frm_dbcfg.free;
  end;
end;

procedure Tfrm_impl.ListView1SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  impItem:TImplsItem;
begin
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
  for I := 0 to ImplsManger.items.Count-1 do
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


{ TImplsItem }

constructor TImplsItem.Create;
begin
  TableOptDef := TTableOptDef.Create;
  Paused := False;
end;

destructor TImplsItem.Destroy;
begin
  TableOptDef.Free;
  inherited;
end;

function TImplsItem.getState: TImplsItemState;
begin
  if Paused then
  begin
    Result := Pause;
  end else begin
    if TableOptDef.Count = 0 then
    begin
      Result := Unconfigured
    end else
    begin
      Result := Normal;
    end;
  end;
end;

initialization
  ImplsManger := TImplsManger.Create;

finalization
  ImplsManger.Free;


end.
