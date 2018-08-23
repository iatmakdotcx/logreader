unit p_mainCfg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Data.DB,
  Data.Win.ADODB, Vcl.StdCtrls, System.Contnrs, Vcl.ComCtrls, pppppp, Vcl.Menus;

type
  Tfrm_mainCfg = class(TForm)
    ADOQuery1: TADOQuery;
    Panel1: TPanel;
    GroupBox1: TGroupBox;
    gb_Delete: TGroupBox;
    gb_Update: TGroupBox;
    gb_Insert: TGroupBox;
    pnl_opts: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Button1: TButton;
    edt_filter: TEdit;
    Memo_Update: TMemo;
    Memo_Delete: TMemo;
    Memo_Insert: TMemo;
    Button2: TButton;
    Panel2: TPanel;
    lbl_tblName: TLabel;
    ListView1: TListView;
    lbl_TransInfo: TLabel;
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    upd1: TMenuItem;
    CheckBox1: TCheckBox;
    Button3: TButton;
    N2: TMenuItem;
    ADOConnection1: TADOConnection;
    procedure pnl_optsResize(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure edt_filterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Button2Click(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure FormShow(Sender: TObject);
    procedure N1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Memo_InsertClick(Sender: TObject);
    procedure Memo_InsertKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    SelMmo:TMemo;
    SelMmoIdx:Integer;
    SeltnlName:string;
    procedure InitTables;
    procedure RefreshTablelist;
    { Private declarations }
  public
    ImplsManger: TImplsManger;
    implItem: TImplsItem;
    { Public declarations }
    procedure fieldlstClick(fieldName,paramName:string);
  end;


implementation
uses
  loglog,XMLDoc,XMLIntf, p_paramStyleHelp, p_tblfieldsDisp;

{$R *.dfm}

procedure Tfrm_mainCfg.Button1Click(Sender: TObject);
begin
  InitTables;
end;

procedure Tfrm_mainCfg.Button2Click(Sender: TObject);
var
  Ddd: TableOptDefItem;
begin
  if SeltnlName <> '' then
  begin
    Ddd := implItem.getItemByName(SeltnlName);
    if Ddd = nil then
    begin
      Ddd := TableOptDefItem.Create;
      Ddd.ObjName := SeltnlName;
      implItem.Add(Ddd);
    end;
    Ddd.Insert := Memo_Insert.Text;
    Ddd.Delete := Memo_Delete.Text;
    Ddd.Update := Memo_Update.Text;
    Ddd.ReplaceParam2Str := CheckBox1.Checked;
    if (Ddd.Insert = '') and (Ddd.Delete = '') and (Ddd.Update = '') then
    begin
      implItem.Remove(SeltnlName);
    end;
    implItem.save;
    ShowMessage('ok');
  end;
end;

procedure Tfrm_mainCfg.Button3Click(Sender: TObject);
var
  frm_paramStyleHelp: Tfrm_paramStyleHelp;
begin
  frm_paramStyleHelp := Tfrm_paramStyleHelp.create(nil);
  try
    frm_paramStyleHelp.ShowModal;
  finally
    frm_paramStyleHelp.free;
  end;
end;

procedure Tfrm_mainCfg.edt_filterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  RefreshTablelist;
end;

procedure Tfrm_mainCfg.FormCreate(Sender: TObject);
begin
  frm_TblFieldsDisp := Tfrm_TblFieldsDisp.Create(nil);
  frm_TblFieldsDisp.ADOQuery1.Connection := ADOConnection1;
end;

procedure Tfrm_mainCfg.FormShow(Sender: TObject);
begin
  lbl_TransInfo.Caption := ImplsManger.Host + ':' + ImplsManger.dbName + '  >>  ' + getDispConnStr(implItem.ConnStr, True);
  ADOConnection1.Connected := False;
  ADOConnection1.ConnectionString := getConnectionString(ImplsManger.Host, ImplsManger.user, ImplsManger.pass, ImplsManger.dbName);
  ADOConnection1.Connected := True;
  Button1.Click;
end;

procedure Tfrm_mainCfg.RefreshTablelist;
var
  Nnn: string;
  Ddd: TableOptDefItem;
  flagStr:string;
begin
  ADOQuery1.Filtered := False;
  if edt_filter.Text <> '' then
  begin
    ADOQuery1.Filter := ' name like ''%' + edt_filter.Text + '%''  ';
    ADOQuery1.Filtered := True;
  end;

  ListView1.Items.Clear;
  ADOQuery1.First;
  while not ADOQuery1.eof do
  begin
    Nnn := '['+ADOQuery1.Fields[2].AsString+'].['+ADOQuery1.Fields[0].AsString+']';
    Ddd := implItem.getItemByName(Nnn);
    flagStr := '';
    if Ddd <> nil then
    begin      
      if Ddd.Insert <> '' then
      begin
        flagStr := flagStr + ',I'
      end;
      if Ddd.Delete <> '' then
      begin
        flagStr := flagStr + ',D'
      end;
      if Ddd.Update <> '' then
      begin
        flagStr := flagStr + ',U'
      end;
      if flagStr<>'' then
        Delete(flagStr, 1, 1);
    end;
    with ListView1.Items.Add do
    begin  
      Caption := Nnn;
      SubItems.Add(flagStr);
    end;
    ADOQuery1.Next;
  end;
end;

procedure Tfrm_mainCfg.InitTables;
begin
  ADOQuery1.Close;
  ADOQuery1.Connection := ADOConnection1;
  ADOQuery1.SQL.Text := 'select tbl.name,tbl.object_id,SCHEMA_NAME(tbl.schema_id) from sys.tables tbl join ' + 
        'sys.indexes idx on idx.object_id = tbl.object_id  and ' + 
        '(idx.index_id < 2  or (tbl.is_memory_optimized = 1 and idx.index_id < 3)) order by 3,1';
  ADOQuery1.Open;
  RefreshTablelist;
end;

procedure Tfrm_mainCfg.ListView1SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Ddd: TableOptDefItem;
begin
  SeltnlName := Item.Caption;
  if SeltnlName <> '' then
  begin
    lbl_tblName.Caption := SeltnlName;
    Ddd := implItem.getItemByName(SeltnlName);
    if Ddd <> nil then
    begin
      Memo_Insert.Text := Ddd.Insert;
      Memo_Delete.Text := Ddd.Delete;
      Memo_Update.Text := Ddd.Update;
      CheckBox1.Checked := Ddd.ReplaceParam2Str;
    end
    else
    begin
      Memo_Insert.Text := '';
      Memo_Delete.Text := '';
      Memo_Update.Text := '';
      CheckBox1.Checked := False;
    end;
    frm_TblFieldsDisp.RefreshTableColumns(SeltnlName);
  end;
end;

procedure Tfrm_mainCfg.Memo_InsertClick(Sender: TObject);
begin
  SelMmo := Sender as TMemo;
  SelMmoIdx := SelMmo.SelStart;
end;

procedure Tfrm_mainCfg.Memo_InsertKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  SelMmoIdx := SelMmo.SelStart;
end;

procedure Tfrm_mainCfg.fieldlstClick(fieldName, paramName: string);
var
  ssss:string;
begin
  if paramName.StartsWith('@$') and (SelMmo<>Memo_Update) then
  begin
    MessageBox(Handle, '½öÓÃÓÚUpdate£¡', '', MB_OK + MB_ICONSTOP);
  end else begin
    ssss := SelMmo.Lines.Text;
    Insert(' '+paramName+' ', ssss, SelMmoIdx + 1);
    SelMmo.Lines.Text := ssss;
    SelMmo.SetFocus;
    SelMmo.SelStart := SelMmoIdx;
  end;
end;

procedure Tfrm_mainCfg.N1Click(Sender: TObject);
begin
  Button1.Click;
end;

procedure Tfrm_mainCfg.N2Click(Sender: TObject);
begin
  frm_TblFieldsDisp.cfgForm := Self;
  frm_TblFieldsDisp.show;
end;

procedure Tfrm_mainCfg.pnl_optsResize(Sender: TObject);
begin
  gb_Insert.Height := pnl_opts.Height div 3;
  gb_Delete.Height := gb_Insert.Height;
end;


end.

