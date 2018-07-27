unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource, Vcl.ComCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Menus, Xml.XMLIntf, System.Contnrs, plugins;

type
  TPluginMenuActionItem = class(TObject)
    PluginItem:TPluginItem;
    ActionId:string;
  end;

type
  TForm1 = class(TForm)
    Button3: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    GroupBox1: TGroupBox;
    Button7: TButton;
    Button12: TButton;
    Button13: TButton;
    GroupBox2: TGroupBox;
    Button1: TButton;
    Button2: TButton;
    Mom_ExistsCfg: TMemo;
    ReloadList: TButton;
    ListView1: TListView;
    Button5: TButton;
    Memo1: TMemo;
    ImageList1: TImageList;
    Button4: TButton;
    Button6: TButton;
    Button14: TButton;
    Button11: TButton;
    Edit1: TEdit;
    Button15: TButton;
    Button16: TButton;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    Button17: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure ReloadListClick(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure Button16Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
  private
    menuActions:TobjectList;
    procedure InitPluginsMenus;
    procedure CreatePluginsMenus(items: TMenuItem; node: IXMLNode;PluginItem:TPluginItem);
    procedure PluginMenuItemClick(Sender: TObject);
    { Private declarations }
  public
    logsource: TLogSource;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common,
  MakCommonfuncs, loglog, sqlextendedprocHelper, XMLDoc;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
begin
  logsource.Fdbc.refreshDict;
end;

procedure TForm1.Button11Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    tlsObj.Stop_picker;
  end;
end;

procedure TForm1.Button12Click(Sender: TObject);
begin
  logsource.saveToFile('d:\1.bin');
end;

procedure TForm1.Button13Click(Sender: TObject);
begin
  logsource.loadFromFile('d:\1.bin');
end;

procedure TForm1.Button14Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    Memo1.Text := tlsObj.CompareDict;
  end;
end;

procedure TForm1.Button15Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
  tmpStr:string;
  I: Integer;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    tmpStr := '';
    for I := 0 to tlsObj.Fdbc.dict.tables.Count-1 do
    begin
      if tlsObj.Fdbc.dict.tables[i].Owner<>'sys' then
        tmpStr:= tmpStr +',['+inttostr(tlsObj.Fdbc.dict.tables[i].TableId)+']'+tlsObj.Fdbc.dict.tables[i].TableNmae;
    end;
    Memo1.Lines.Add(tmpStr);
  end;
end;

procedure TForm1.Button16Click(Sender: TObject);
begin
  PluginsMgr.onTranSql('select 1');
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  savePath:string;
  logsource:TLogSource;
begin
  frm_dbConnectionCfg := Tfrm_dbConnectionCfg.create(nil);
  try
    if frm_dbConnectionCfg.ShowModal = mrOk then
    begin
      logsource := frm_dbConnectionCfg.logsource;
      savePath := ExtractFilePath(GetModuleName(0)) + Format('cfg\%d.lrd',[logsource.Fdbc.dbID]);
      if logsource.saveToFile(savePath) then
      begin
        //保存配置成功才继续，否则处理失败
        LogSourceList.Add(logsource);
        setDbOn(logsource.Fdbc);
        Loger.Add('新增配置完成！！');
      end else begin
        logsource.Free;
        ShowMessage('配置保存失败，确认目录权限.');
      end;
    end
    else
      frm_dbConnectionCfg.logsource.Free;
  finally
    frm_dbConnectionCfg.free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
procedure setLsn(tlsObj:TLogSource);
var
  TmpLst :TStringList;
  tmpLsn:Tlog_LSN;
begin
  if Edit1.Text<>'' then
  BEGIN
    TmpLst := TStringList.Create;
    try
      TmpLst.Text := StringReplace(Edit1.Text,':',WIN_EOL,[rfReplaceAll]);
      if TmpLst.Count<>3 then
      begin
        ShowMessage('LSN格式化无效！');
        Exit;
      end;

      tmpLsn.LSN_1 := StrToInt('$' + TmpLst[0]);
      tmpLsn.LSN_2 := StrToInt('$' + TmpLst[1]);
      tmpLsn.LSN_3 := StrToInt('$' + TmpLst[2]);
      tlsObj.FProcCurLSN := tmpLsn;
    finally
      TmpLst.Free;
    end;
  END;
end;
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
{$IFDEF DEBUG}
    setLsn(tlsObj);
{$ENDIF}
    tlsObj.Create_picker;
  end;
end;

procedure msgOut(aMsg: string; level: Integer);
begin
  Form1.Memo1.Lines.add(FormatDateTime('yyyy-MM-dd HH:mm:ss', Now) + ' - ' + IntToStr(level) + ' >>' + aMsg);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  loger.registerCallBack(msgOut);
  loger.Add('=================loger callback======================');
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
  LSN: Tlog_LSN;
  OutBuffer: TMemory_data;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    LSN.LSN_1 := $200;
    LSN.LSN_2 := $478;
    LSN.LSN_3 := 1;

    if tlsObj.GetRawLogByLSN(LSN, OutBuffer) and (OutBuffer.dataSize > 0) then
    begin
      ShowMessage(bytestostr(OutBuffer.data,OutBuffer.dataSize));
      FreeMem(OutBuffer.data);
    end;
  end;
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  oum: TMemory_data;
  mmp: TMemoryStream;
  logsource :TLogSource;
begin
  logsource := LogSourceList.Get(StrToInt(ListView1.Selected.Caption) - 1);

  logsource.cpyFile(2, oum);
  mmp := TMemoryStream.Create;
  mmp.WriteBuffer(oum.data^, oum.dataSize);
  mmp.Seek(0, 0);
  mmp.SaveToFile('d:\2_log.bin');
  mmp.Free;
  FreeMem(oum.data);
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  logsource.Create_picker;
end;

procedure TForm1.Button9Click(Sender: TObject);
begin
  logsource.Stop_picker;
end;

procedure TForm1.CreatePluginsMenus(items:TMenuItem; node:IXMLNode;PluginItem:TPluginItem);
var
  caption:string;
  I:Integer;
  aitem:TPluginMenuActionItem;
  menuI:TMenuItem;
begin
  caption := node.Attributes['caption'];
  menuI := TMenuItem.Create(Self);
  menuI.Caption := caption;
  items.Add(menuI);
  if node.HasAttribute('actionid') then
  begin
    aitem := TPluginMenuActionItem.Create;
    aitem.ActionId := node.Attributes['actionid'];
    aitem.PluginItem := PluginItem;
    menuActions.Add(aitem);
    menuI.Tag := menuActions.Count-1;
    menuI.OnClick := PluginMenuItemClick;
  end else begin
    for I := 0 to node.ChildNodes.Count - 1 do
    begin
      if node.ChildNodes[i].NodeName = 'item' then
      begin
        CreatePluginsMenus(menuI, node.ChildNodes[i], PluginItem);
      end;
    end;
  end;
end;

procedure TForm1.InitPluginsMenus;
var
  menuXml:PChar;
  I, J: Integer;
  resV: DWORD;
  Xml:IXMLDocument;
  Rootnode:IXMLNode;
begin
  for I := 0 to PluginsMgr.Count-1 do
  begin
    if Assigned(PluginsMgr.Items[i]._Lr_PluginMenu) then
    begin
      resV := PluginsMgr.Items[i]._Lr_PluginMenu(menuXml);
      if not Succeeded(resV) then
      begin
        Loger.Add('%s 插件 %s 已加载.获取菜单失败！Code：%d', [PluginsMgr.Items[i].dllname, PluginsMgr.Items[i].name, resV]);
      end else begin
        Xml := TXMLDocument.Create(nil);
        Xml.LoadFromXML(menuXml);
        Rootnode := Xml.DocumentElement;
        for J := 0 to Rootnode.ChildNodes.Count-1 do
        begin
          if Rootnode.ChildNodes[J].NodeName = 'item' then
          begin
            CreatePluginsMenus(MainMenu1.Items, Rootnode.ChildNodes[J], PluginsMgr.Items[i]);
          end;
        end;
      end;
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  menuActions := TobjectList.Create;
  logsource := TLogSource.create;
  InitPluginsMenus;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  logsource.Free;
  menuActions.Free;
end;

procedure TForm1.N2Click(Sender: TObject);
begin
  application.Terminate;
end;

procedure TForm1.PluginMenuItemClick(Sender: TObject);
var
  aitem:TPluginMenuActionItem;
begin
  if Sender is TMenuItem then
  begin
    aitem := TPluginMenuActionItem(menuActions[(Sender as TMenuItem).Tag]);
    aitem.PluginItem._Lr_PluginMenuAction(Pchar(aitem.ActionId));
  end;
end;

procedure TForm1.ReloadListClick(Sender: TObject);
var
  savePath:string;
  lst:TStringList;
  I: Integer;
  Tmplogsource : TLogSource;
  ItemIdx:Integer;
begin
  savePath := ExtractFilePath(GetModuleName(0)) + 'cfg\*.lrd';
  lst := searchAllFileAdv(savePath);
  for I := 0 to lst.Count - 1 do
  begin
    Mom_ExistsCfg.Lines.Add(lst[I]);
    Tmplogsource := TLogSource.Create;
    if Tmplogsource.loadFromFile(lst[I]) then
    begin
      ItemIdx := LogSourceList.Add(Tmplogsource);
      if ItemIdx = -1 then
      begin
        //已存在
        Tmplogsource.Free;
      end
      else
      begin
        Tmplogsource.Fdbc.refreshConnection;
        Tmplogsource.Fdbc.getDb_dbInfo(True);
        Tmplogsource.CreateLogReader;
      end;
    end
    else
    begin
      Tmplogsource.Free;
    end;
  end;
  lst.Free;
  ListView1.clear;
  for I := 0 to LogSourceList.Count - 1 do
  begin
    Tmplogsource := LogSourceList.Get(i);
    with ListView1.Items.Add do
    begin
      ImageIndex := ord(Tmplogsource.status);
      Caption := IntToStr(i + 1);
      SubItems.Add(Tmplogsource.Fdbc.Host);
      SubItems.Add(Tmplogsource.Fdbc.dbName);
      SubItems.Add(IntToStr(ord(Tmplogsource.status)));
    end;
  end;
end;

end.

