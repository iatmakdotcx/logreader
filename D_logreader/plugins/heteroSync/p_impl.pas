unit p_impl;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, System.Contnrs,
  p_main;

type
  TImplsItem = class(TObject)
    Host:string;
    user:string;
    pass:string;
    dbName:string;
    TableOptDef: TTableOptDef;
    constructor Create;
    destructor Destroy; override;
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
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
  private
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

procedure Tfrm_impl.Button1Click(Sender: TObject);
var
  impItem:TImplsItem;
begin
  frm_dbcfg := Tfrm_dbcfg.create(nil);
  try
    if frm_dbcfg.ShowModal = mrok then
    begin
      impItem := ImplsManger.find(frm_dbcfg.dbcfg_Host, frm_dbcfg.dbcfg_dbName);
      if impItem <> nil then
      begin

        Exit;
      end;

      impItem:=TImplsItem.Create;

    end;
  finally
    frm_dbcfg.free;
  end;
end;

{ TImplsItem }

constructor TImplsItem.Create;
begin
  TableOptDef := TTableOptDef.Create;
end;

destructor TImplsItem.Destroy;
begin
  TableOptDef.Free;
  inherited;
end;

initialization
  ImplsManger := TImplsManger.Create;

finalization
  ImplsManger.Free;


end.
