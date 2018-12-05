unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource, Vcl.ComCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Menus, Xml.XMLIntf, System.Contnrs, plugins, Vcl.ExtCtrls,
  System.SyncObjs;

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
    N7: TMenuItem;
    Button1: TButton;
    Button2: TButton;
    Debug1: TMenuItem;
    CompareDictFromdb1: TMenuItem;
    ViewAllTable1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure btn_newCfgClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btn_ReloadListClick(Sender: TObject);
    procedure btn_jobStartClick(Sender: TObject);
    procedure btn_jobStopClick(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure N4Click(Sender: TObject);
    procedure N5Click(Sender: TObject);
    procedure N6Click(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure N7Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure CompareDictFromdb1Click(Sender: TObject);
    procedure ListView1Change(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure ListView1Click(Sender: TObject);
    procedure ListView1Changing(Sender: TObject; Item: TListItem;
      Change: TItemChange; var AllowChange: Boolean);
    procedure Button5Click(Sender: TObject);
    procedure ViewAllTable1Click(Sender: TObject);
  private
    menuActions:TobjectList;
    procedure InitPluginsMenus;
    procedure CreatePluginsMenus(items: TMenuItem; node: IXMLNode;PluginItem:TPluginItem);
    procedure PluginMenuItemClick(Sender: TObject);
    procedure ListViewRefresh;
    procedure XmlDebug(aXmlText: string);
    { Private declarations }
  public
    { Public declarations }
    MMO_LOGCS:TCriticalSection;
    procedure ShwLogMsg(aMsg: string; level: Integer);
  end;

var
  Form1: TForm1;

implementation

uses
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common,
  MakCommonfuncs, loglog, sqlextendedprocHelper, XMLDoc, LogtransPkg, dbDict, 
  LogtransPkgMgr, Sql2014logAnalyzer, p_tableview;

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
        tmpStr := tmpStr + ',[' + inttostr(tlsObj.Fdbc.dict.tables[I].TableId) + ']' +
        tlsObj.Fdbc.dict.tables[I].TableNmae+','+  BoolToStr(tlsObj.Fdbc.dict.tables[I].hasIdentity,true) + win_Eol;
    end;
    MMO_LOG.Lines.Add(tmpStr);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  tlsObj:TLogSource;
  tmpStr:string;
begin
  if ListView1.Selected <> nil then
  begin
    tlsObj := TLogSource(ListView1.Selected.Data);
    tmpStr := '';
    if tlsObj.Fdbc.dict.tables.Count>0 then
    begin
      tmpStr := tlsObj.Fdbc.dict.tables[0].AsXml;
    end;
    MMO_LOG.Lines.Add(tmpStr);
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  opendia:TOpenDialog;
  ff:TStringList;
begin
  opendia:=TOpenDialog.Create(nil);
  try
    if opendia.Execute then
    begin
      ff:=TStringList.Create;
      try
        ff.LoadFromFile(opendia.FileName);
        XmlDebug(ff.Text);
      finally
        ff.Free;
      end;
    end;
  finally
    opendia.Free;
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  tlsObj : TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    tlsObj := ListView1.Selected.Data;

    tlsObj.Loger.Add('aaaaaaaaaa',LOG_ERROR);
  end;
end;

procedure TForm1.XmlDebug(aXmlText:string);
var
  logsource : Tlogsource;
  pkgMgr: TTransPkgMgr;
  logAnalyzer:TSql2014logAnalyzer;
  xml:IXMLDocument;
  TTsPkg: TTransPkg;
  log: TTransPkgItem;
  TmpStr:string;
  root,rows,tables,tmpNode:IXMLNode;
  transId:TTrans_Id;
  I:Integer;
  lsn:Tlog_LSN; 
  tmpBytes:TBytes;
  Raw: TMemory_data;
  pageDatalist:TObjectList;
  table:TdbTableItem;
begin
  xml:=TXMLDocument.Create(nil);
  xml.XML.Text := aXmlText;
  xml.Active := True;
  root := xml.DocumentElement;
  transId := Str2TranId(root.ChildValues['transId']);
  if (transId.Id1=0) and (transId.Id2=0) then
  begin
    ShowMessage('Xml.TransId��Ч');
    Exit;
  end;
  rows := root.ChildNodes['rows'];
  TTsPkg := TTransPkg.Create(transId);
  pageDatalist := TObjectList.Create;
  for I := 0 to rows.ChildNodes.Count - 1 do
  begin
    if rows.ChildNodes[I].NodeName = 'item' then
    begin
      tmpNode := rows.ChildNodes[I];
      if tmpNode.HasAttribute('lsn') then
      begin
        TmpStr := tmpNode.Attributes['lsn'];
        lsn := Str2LSN(TmpStr);
        if (lsn.LSN_1 = 0) or (lsn.LSN_2 = 0) or (lsn.LSN_3 = 0) then
        begin
          ShowMessage('Xml.rows.Lsn��Ч:' + TmpStr);
          Continue;
        end;
        if VarIsNull(tmpNode.ChildValues['bin']) then
        begin
          ShowMessage('Xml.rows.bin��Ч:' + TmpStr);
          Continue;
        end;
        TmpStr := tmpNode.ChildValues['bin'];
        tmpBytes := strToBytes(TmpStr);
        Raw.dataSize := Length(tmpBytes);
        Raw.data := GetMemory(Raw.dataSize);
        CopyMemory(Raw.data, @tmpBytes[0], Raw.dataSize);
        SetLength(tmpBytes, 0);
        log := TTransPkgItem.Create(lsn, Raw);        
        TTsPkg.addRawLog(log);
        if not VarIsNull(tmpNode.ChildValues['data']) then
        begin
          //�������pagedata
          TmpStr := tmpNode.ChildValues['data'];
          tmpBytes := strToBytes(TmpStr);
          Raw.dataSize := Length(tmpBytes);
          Raw.data := GetMemory(Raw.dataSize);
          CopyMemory(Raw.data, @tmpBytes[0], Raw.dataSize);
          SetLength(tmpBytes, 0);
          pageDatalist.Add(TTransPkgItem.Create(lsn, Raw));
        end;        
      end;
    end;
  end;
  if TTsPkg.Items.Count>0 then
  begin
    logsource := Tlogsource.Create; 
    LogSource.FFFFIsDebug := True;
    logsource.Fdbc := TdatabaseConnection.Create(LogSource);
    LogSource.pageDatalist := pageDatalist;
    pkgMgr := TTransPkgMgr.Create(logsource);
    pkgMgr.FpaddingPrisePkg.Push(TTsPkg);
    //��ȡ����Ϣ
    tables := root.ChildNodes['tables'];
    for I := 0 to tables.ChildNodes.Count - 1 do
    begin
      if tables.ChildNodes[I].NodeName = 'table' then
      begin
        table:=TdbTableItem.Create;
        if table.loadXml(tables.ChildNodes[I]) then
        begin
          logsource.Fdbc.dict.tables.addTable(table);
        end else begin
          LogSource.Loger.Add('���ر���Ϣʧ�ܣ���');
          table.Free;        
        end;    
      end;
    end;
    
    logAnalyzer := TSql2014logAnalyzer.Create(pkgMgr, logsource);
//    logAnalyzer.Terminate;
//    logAnalyzer.WaitFor;
//    logAnalyzer.Free;
//    pkgMgr.Free;
//    logsource.Free;
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
      savePath := ExtractFilePath(GetModuleName(0)) + Format('cfg\%s.lrd',[logsource.Uid]);
      if logsource.saveToFile(savePath) then
      begin
        //�������óɹ��ż�����������ʧ��
        LogSourceList.Add(logsource);
        DefLoger.Add('����������ɣ���');
        ListViewRefresh;
      end else begin
        logsource.Free;
        ShowMessage('���ñ���ʧ�ܣ�ȷ��Ŀ¼Ȩ��.');
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
        ShowMessage('LSN��ʽ����Ч��');
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
    tlsObj.Create_picker(True);
  end;
end;

procedure msgOut(aMsg: string; level: Integer);
begin
  Form1.mmo_log.Lines.add(FormatDateTime('yyyy-MM-dd HH:mm:ss', Now) + ' - ' + IntToStr(level) + ' >>' + aMsg);
end;

procedure TForm1.CompareDictFromdb1Click(Sender: TObject);
begin
  Button14Click(nil);
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
    //���¼���һ�ɲ������ظ�
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
        DefLoger.Add('%s ��� %s �Ѽ���.��ȡ�˵�ʧ�ܣ�Code��%d', [PluginsMgr.Items[i].dllname, PluginsMgr.Items[i].name, resV]);
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
{$IFNDEF DEBUG}
  Panel1.Visible := False;
  GroupBox1.Visible := False;
{$ENDIF}
  MMO_LOGCS := TCriticalSection.Create;
  menuActions := TobjectList.Create;

  InitPluginsMenus;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  menuActions.Free;
  MMO_LOGCS.Free;
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
  if pos('��ʼ', N6.Caption)>0 then
  begin
    btn_jobStart.Click;
  end
  else
  begin
    btn_jobStop.Click;
  end;
end;

procedure TForm1.N7Click(Sender: TObject);
begin
  ListViewRefresh;
end;

procedure TForm1.PluginMenuItemClick(Sender: TObject);
var
  aitem:TPluginMenuActionItem;
  tlsObj:TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    tlsObj := ListView1.Selected.Data;
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
begin
  if ListView1.Selected <> nil then
  begin
    tlsObj := ListView1.Selected.Data;
    if tlsObj.status = tLS_running then
    begin
      N6.Caption := 'ֹͣ';
    end else begin
      N6.Caption := '��ʼ';
    end;
    N6.Enabled := True;
  end else begin
    N6.Enabled := False;
  end;
end;

procedure TForm1.ShwLogMsg(aMsg: string; level: Integer);
begin
  if MMO_LOG<>nil then
  begin
    try
      MMO_LOGCS.Enter;
      try
        MMO_LOG.lines.Add(FormatDateTime('yyyy-MM-dd HH:nn:ss.zzz', Now) + IntToStr(level) + ' >> ' + aMsg);
        MMO_LOG.Perform(WM_VSCROLL, SB_BOTTOM, 0);
        if MMO_LOG.Lines.Count >= 1000 then
        begin
          MMO_LOG.Lines.Delete(0);
        end;
      finally
        MMO_LOGCS.Leave;
      end;
    Except
    end;
  end;
end;

procedure TForm1.ViewAllTable1Click(Sender: TObject);
begin
  if ListView1.Selected <> nil then
  begin
    showtables(TLogSource(ListView1.Selected.Data));
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
        //�Ѵ���
        Tmplogsource.Free;
      end
      else
      begin
        Tmplogsource.Fdbc.refreshConnection;
        Tmplogsource.Fdbc.getDb_dbInfo(True);
        //Tmplogsource.Create_picker(True);
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

procedure TForm1.ListView1Change(Sender: TObject; Item: TListItem; Change: TItemChange);
begin
  ListView1Click(Sender);
end;

procedure TForm1.ListView1Changing(Sender: TObject; Item: TListItem;
  Change: TItemChange; var AllowChange: Boolean);
var
  tlsObj: TLogSource;
begin
  if (Item <> nil) and (Item.Data<>nil) then
  begin
    tlsObj := TLogSource(Item.Data);
    tlsObj.MainMSGDISPLAY := nil;
  end;
end;

procedure TForm1.ListView1Click(Sender: TObject);
var
  tlsObj: TLogSource;
begin
  if ListView1.Selected <> nil then
  begin
    tlsObj := TLogSource(ListView1.Selected.Data);
    MMO_LOG.text := tlsObj.FFmsg.Text;
    tlsObj.MainMSGDISPLAY := ShwLogMsg;
  end;
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
    lv_row.Data := Tmplogsource;

    lv_row.ImageIndex := ord(Tmplogsource.status);
    lv_row.Caption := IntToStr(i + 1);
    lv_row.SubItems.Add(Tmplogsource.Fdbc.Host);
    lv_row.SubItems.Add(Tmplogsource.Fdbc.dbName);
    lv_row.SubItems.Add(IntToStr(ord(Tmplogsource.status)));
    lv_row.SubItems.Add(LSN2Str(Tmplogsource.FProcCurLSN));

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

