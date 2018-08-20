unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource, Vcl.ComCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Menus, Xml.XMLIntf, System.Contnrs, plugins, Vcl.ExtCtrls;

type
  TPluginMenuActionItem = class(TObject)
    PluginItem:TPluginItem;
    ActionId:string;
  end;

type
  TForm1 = class(TForm)
    btn_newCfg: TButton;
    GroupBox1: TGroupBox;
    Button7: TButton;
    GroupBox2: TGroupBox;
    btn_ReloadList: TButton;
    ListView1: TListView;
    Button5: TButton;
    MMO_LOG: TMemo;
    ImageList1: TImageList;
    btn_jobStart: TButton;
    Button14: TButton;
    btn_jobStop: TButton;
    Edit1: TEdit;
    Button15: TButton;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    N4: TMenuItem;
    N5: TMenuItem;
    Panel1: TPanel;
    PopupMenu1: TPopupMenu;
    N6: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure btn_newCfgClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure btn_ReloadListClick(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure btn_jobStartClick(Sender: TObject);
    procedure btn_jobStopClick(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure N4Click(Sender: TObject);
    procedure N5Click(Sender: TObject);
    procedure N6Click(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
  private
    menuActions:TobjectList;
    procedure InitPluginsMenus;
    procedure CreatePluginsMenus(items: TMenuItem; node: IXMLNode;PluginItem:TPluginItem);
    procedure PluginMenuItemClick(Sender: TObject);
    procedure ListViewRefresh;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common,
  MakCommonfuncs, loglog, sqlextendedprocHelper, XMLDoc;

{$R *.dfm}

procedure TForm1.btn_jobStopClick(Sender: TObject);
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

procedure TForm1.Button14Click(Sender: TObject);
var
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    MMO_LOG.Lines.Add(tlsObj.CompareDict);
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
    MMO_LOG.Lines.Add(tmpStr);
  end;
end;

procedure TForm1.btn_newCfgClick(Sender: TObject);
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

procedure TForm1.btn_jobStartClick(Sender: TObject);
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
  Form1.mmo_log.Lines.add(FormatDateTime('yyyy-MM-dd HH:mm:ss', Now) + ' - ' + IntToStr(level) + ' >>' + aMsg);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  loger.registerCallBack(msgOut);
  loger.Add('=================loger callback======================');
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

procedure TForm1.CreatePluginsMenus(items:TMenuItem; node:IXMLNode;PluginItem:TPluginItem);
function getMenuCaption(caption:string):string;
begin
  Result := caption;
  if Pos('(', Result)>0 then
  begin
    Result := Copy(Result, 0, Pos('(', Result)-1);
  end;
end;
var
  caption:string;
  I:Integer;
  aitem:TPluginMenuActionItem;
  menuI:TMenuItem;
begin
  menuI := nil;
  caption := node.Attributes['caption'];
  for I := 0 to items.Count-1 do
  begin
    if(getMenuCaption(items[i].Caption)=caption) then
    begin
      menuI := items[i];
      Break;
    end;
  end;
  if (menuI = nil) or node.HasAttribute('actionid') then
  begin
    //是要有事件，一律不允许重复
    menuI := TMenuItem.Create(Self);
    menuI.Caption := caption;
    items.Add(menuI);
  end;
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
      menuXml := GetMemory($1000);
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
      FreeMem(menuXml);
    end;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  menuActions := TobjectList.Create;

  InitPluginsMenus;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  menuActions.Free;
end;

procedure TForm1.N2Click(Sender: TObject);
begin
  application.Terminate;
end;

procedure TForm1.N4Click(Sender: TObject);
begin
  btn_newCfg.Click;
end;

procedure TForm1.N5Click(Sender: TObject);
begin
  btn_ReloadList.Click;
end;

procedure TForm1.N6Click(Sender: TObject);
begin
  if N6.Caption = '开始' then
  begin
    btn_jobStart.Click;
  end
  else
  begin
    btn_jobStop.Click;
  end;
end;

procedure TForm1.PluginMenuItemClick(Sender: TObject);
var
  aitem:TPluginMenuActionItem;
  ItemIdx:Integer;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    if Sender is TMenuItem then
    begin
      aitem := TPluginMenuActionItem(menuActions[(Sender as TMenuItem).Tag]);
      aitem.PluginItem._Lr_PluginMenuAction(tlsObj.Fdbc.GetPlgSrc, Pchar(aitem.ActionId));
      ListViewRefresh;
    end;
  end;
end;

procedure TForm1.PopupMenu1Popup(Sender: TObject);
var
  tlsObj : TLogSource;
  ItemIdx:Integer;
begin
  if ListView1.Selected <> nil then
  begin
    ItemIdx := StrToInt(ListView1.Selected.Caption) - 1;
    tlsObj := LogSourceList.Get(ItemIdx);
    if tlsObj.status = tLS_running then
    begin
      N6.Caption := '停止';
    end else begin
      N6.Caption := '开始';
    end;
    N6.Enabled := True;
  end else begin
    N6.Enabled := False;
  end;
end;

procedure TForm1.btn_ReloadListClick(Sender: TObject);
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
    MMO_LOG.Lines.Add(lst[I]);
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
  ListViewRefresh;
end;

procedure TForm1.ListViewRefresh;
var
  I,J,K,L: Integer;
  Tmplogsource : TLogSource;
  pi:TPluginItem;
  tmpAAStr:PChar;
  Xml:IXMLDocument;
  Rootnode:IXMLNode;
  grid_caption:string;
  grid_Value:string;
  Col:TListColumn;
  lv_row:TListItem;
  tmpS:string;
begin
  ListView1.clear;
  for I := 0 to LogSourceList.Count - 1 do
  begin
    Tmplogsource := LogSourceList.Get(i);
    lv_row := ListView1.Items.Add;

    lv_row.ImageIndex := ord(Tmplogsource.status);
    lv_row.Caption := IntToStr(i + 1);
    lv_row.SubItems.Add(Tmplogsource.Fdbc.Host);
    lv_row.SubItems.Add(Tmplogsource.Fdbc.dbName);
    lv_row.SubItems.Add(IntToStr(ord(Tmplogsource.status)));

    for J:= 0 to PluginsMgr.Count-1 do
    begin
      pi := TPluginItem(PluginsMgr[J]);
      if Assigned(pi._Lr_PluginMainGridData) then
      begin
        tmpAAStr := GetMemory($1000);
        if (pi._Lr_PluginMainGridData(Tmplogsource.Fdbc.GetPlgSrc, tmpAAStr) = 0) and (tmpAAStr<>'') then
        begin
          Xml := TXMLDocument.Create(nil);
          Xml.LoadFromXML(tmpAAStr);
          Rootnode := Xml.DocumentElement;
          for K := 0 to Rootnode.ChildNodes.Count-1 do
          begin
            if (Rootnode.ChildNodes[K].NodeName='item') and Rootnode.ChildNodes[K].HasAttribute('caption') then
            begin
              grid_caption := Rootnode.ChildNodes[K].Attributes['caption'];
              if VarIsNull(Rootnode.ChildNodes[K].Text) then
                grid_Value := ''
              else
                grid_Value := Rootnode.ChildNodes[K].Text;
              Col := nil;
              for L := 0 to ListView1.Columns.Count-1 do
              begin
                if ListView1.Column[L].Caption=grid_caption then
                begin
                  Col := ListView1.Column[L];
                  Break;
                end;
              end;
              if Col = nil then
              begin
                Col := ListView1.Columns.Add;
                Col.Caption := grid_caption;
                if Rootnode.ChildNodes[K].HasAttribute('width') then
                  Col.Width := StrToIntDef(Rootnode.ChildNodes[K].Attributes['width'], 60);
                if Rootnode.ChildNodes[K].HasAttribute('align') then
                begin
                  tmpS := Rootnode.ChildNodes[K].Attributes['align'];
                  if tmpS = 'center' then
                  begin
                    Col.Alignment := taCenter;
                  end
                  else if tmpS = 'right' then
                  begin
                    Col.Alignment := taRightJustify;
                  end;
                end;
              end;
              while lv_row.SubItems.Count <= Col.Index do
              begin
                lv_row.SubItems.Add('');
              end;
              lv_row.SubItems[Col.Index-1] := grid_Value;
              Break;
            end;
          end;
        end;
        FreeMem(tmpAAStr);
      end;
    end;
  end;
end;

end.

