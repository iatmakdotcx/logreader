unit p_main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Data.DB,
  Data.Win.ADODB, Vcl.StdCtrls, System.Contnrs, Vcl.ComCtrls;

type
  TableOptDefItem = class(TObject)
    ObjName: string;
    Insert: string;
    Delete: string;
    Update: string;
  end;

  TTableOptDef = class(TObject)
  private
    items: TObjectList;
    function defcfgName: string;
    function getItemByName(ObjName: string): TableOptDefItem;
  public
    constructor Create;
    destructor Destroy; override;
    procedure save(afile: string = '');
    procedure load(afile: string = '');
    function Count: Integer;
  end;

type
  Tfrm_main = class(TForm)
    adoc_Src: TADOConnection;
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
    procedure pnl_optsResize(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edt_filterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Button2Click(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    SeltnlName:string;
    TableOptDef: TTableOptDef;
    procedure InitTables;
    procedure RefreshTablelist;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frm_main: Tfrm_main;

implementation
uses
 loglog;

{$R *.dfm}

procedure Tfrm_main.Button1Click(Sender: TObject);
begin
  InitTables;
end;

procedure Tfrm_main.Button2Click(Sender: TObject);
var
  Ddd: TableOptDefItem;
begin
  if SeltnlName <> '' then
  begin
    Ddd := TableOptDef.getItemByName(SeltnlName);
    if Ddd = nil then
    begin
      Ddd := TableOptDefItem.Create;
      Ddd.ObjName := SeltnlName;
      TableOptDef.items.Add(Ddd);
    end;
    Ddd.Insert := Memo_Insert.Text;
    Ddd.Delete := Memo_Delete.Text;
    Ddd.Update := Memo_Update.Text;
    TableOptDef.save;
    ShowMessage('ok');
  end;
end;

procedure Tfrm_main.edt_filterKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  RefreshTablelist;
end;

procedure Tfrm_main.FormCreate(Sender: TObject);
begin
  TableOptDef := TTableOptDef.Create;
  TableOptDef.load;
end;

procedure Tfrm_main.FormDestroy(Sender: TObject);
begin
  TableOptDef.Free;
end;

procedure Tfrm_main.RefreshTablelist;
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
    Ddd := TableOptDef.getItemByName(Nnn);
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

procedure Tfrm_main.InitTables;
begin
  ADOQuery1.Close;
  ADOQuery1.SQL.Text := 'select tbl.name,tbl.object_id,SCHEMA_NAME(tbl.schema_id) from sys.tables tbl join ' + 
        'sys.indexes idx on idx.object_id = tbl.object_id  and ' + 
        '(idx.index_id < 2  or (tbl.is_memory_optimized = 1 and idx.index_id < 3)) order by 3,1';
  ADOQuery1.Open;
  RefreshTablelist;
end;

procedure Tfrm_main.ListView1SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Ddd: TableOptDefItem;
begin
  SeltnlName := Item.Caption;
  if SeltnlName <> '' then
  begin
    lbl_tblName.Caption := SeltnlName;
    Ddd := TableOptDef.getItemByName(SeltnlName);
    if Ddd <> nil then
    begin
      Memo_Insert.Text := Ddd.Insert;
      Memo_Delete.Text := Ddd.Delete;
      Memo_Update.Text := Ddd.Update;
    end
    else
    begin
      Memo_Insert.Text := '';
      Memo_Delete.Text := '';
      Memo_Update.Text := '';
    end;
  end;
end;

procedure Tfrm_main.pnl_optsResize(Sender: TObject);
begin
  gb_Insert.Height := pnl_opts.Height div 3;
  gb_Delete.Height := gb_Insert.Height;
end;

{ TonDMLOpt }

constructor TTableOptDef.Create;
begin
  items := TObjectList.Create;
end;

function TTableOptDef.defcfgName: string;
begin
  Result := ExtractFilePath(GetModuleName(HInstance)) + 'cfg\heteroSync.bin';
  ForceDirectories(ExtractFilePath(Result));
end;

destructor TTableOptDef.Destroy;
begin
  items.Free;
  inherited;
end;

function TTableOptDef.Count: Integer;
begin
  Result := items.Count;
end;

function TTableOptDef.getItemByName(ObjName: string): TableOptDefItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to items.Count - 1 do
  begin
    if TableOptDefItem(items[I]).ObjName = ObjName then
    begin
      Result := TableOptDefItem(items[I]);
      Break;
    end;
  end;
end;

procedure TTableOptDef.load(afile: string);
var
  mmo: TMemoryStream;
  Rter: TReader;
  tmpStr:string;
  tod:TableOptDefItem;
  tableCnt:Integer;
  I: Integer;
begin
  if afile = '' then
    afile := defcfgName;
  if not FileExists(afile) then
  begin  
    Loger.Add('异构配置文件不存在：' + afile);
    Exit;
  end;
  mmo := TMemoryStream.Create;
  try
    try
      mmo.LoadFromFile(afile);
      Rter := TReader.Create(mmo, 1);
      try
        if Rter.ReadInteger = $FD then
        begin
          tmpStr := Rter.ReadString;
          if tmpStr = 'TTableOptDef v 1.0' then
          begin
            tableCnt := Rter.ReadInteger;
            for I := 0 to tableCnt - 1 do
            begin
              tod := TableOptDefItem.Create;
              tod.ObjName := Rter.ReadString;
              tod.Insert := Rter.ReadString;
              tod.Delete := Rter.ReadString;
              tod.Update := Rter.ReadString;
              items.Add(tod);
            end;
          end else begin
            Loger.Add('配置文件读取失败(HeadCheckFail2):'+afile);
          end;
        end else begin
          Loger.Add('配置文件读取失败(HeadCheckFail):'+afile);
        end;
      finally
        Rter.Free;
      end;
    except
      on EE:Exception do
      begin
        Loger.Add('配置文件读取失败:'+afile);
      end;
    end;
  finally
    mmo.Free;
  end;
end;

procedure TTableOptDef.save(afile: string);
var
  wter: TWriter;
  I: Integer;
  tableBin: TMemoryStream;
  tod:TableOptDefItem;
begin
  if afile = '' then
    afile := defcfgName;
  
  tableBin := TMemoryStream.Create;
  wter := TWriter.Create(tableBin, 1);
  wter.WriteInteger($FD);
  wter.WriteString('TTableOptDef v 1.0');  
  wter.WriteInteger(items.Count);
  for I := 0 to items.Count - 1 do
  begin
    tod := TableOptDefItem(items[I]);
    wter.WriteString(tod.ObjName);
    wter.WriteString(tod.Insert);
    wter.WriteString(tod.Delete);
    wter.WriteString(tod.Update);  
  end;
  wter.FlushBuffer;
  wter.Free;
  tableBin.Seek(0, 0);
  tableBin.SaveToFile(afile);
  tableBin.Free; 
end;

end.

