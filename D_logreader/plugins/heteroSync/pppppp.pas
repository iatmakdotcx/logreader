unit pppppp;

interface

uses
  System.Contnrs, System.Classes, plgSrcData;

const
  DESPASSWORD = 'lkjhyuio';

type
  TImplsItemState = (Unconfigured, Normal, Pause);

  TableOptDefItem = class(TObject)
    ObjName: string;
    Insert: string;
    Delete: string;
    Update: string;
  end;

  TImplsItem = class(TObject)
  private
    FCfgPath:string;
    items: TObjectList;

    procedure saveBin(afile: string);
    procedure loadBin(afile: string);
    procedure loadXml(afile: string);
    procedure saveXml(afile: string);
  public
    uid:string;
    Host:string;
    user:string;
    pass:string;
    dbName:string;
    Paused:Boolean;
    procedure save(afile: string = '');
    procedure load(afile: string = '');

    constructor Create;
    destructor Destroy; override;
    function getState:TImplsItemState;
    function getItemByName(ObjName: string): TableOptDefItem;
    function Count: Integer;
    function Add(vvv:TableOptDefItem):Integer;
  end;

  TImplsManger = class(TObject)
  private
    //データソース
    Host:string;
    user:string;
    pass:string;
    dbName:string;
    dbid:Integer;    
  public
    items:TObjectList; 
    CfgPath:string;
    constructor Create;
    destructor Destroy; override;
    function find(Host:string;dbName:string):TImplsItem;
    procedure save;
    procedure load;
    function Add(vvv:TImplsItem):Integer;
    function Count: Integer;
  end;

  TLrSvrJob = class(TObject)
  private
    items:array of TImplsManger;
    function defcfgPath:string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure load;
    function get(source:Pplg_source):TImplsManger;
  end;

var
  LrSvrJob: TLrSvrJob;

implementation

uses
  System.SysUtils, Xml.XMLIntf, Xml.XMLDoc, loglog, Des;


function TImplsItem.Add(vvv: TableOptDefItem): Integer;
begin
  Result := items.Add(vvv);
end;

function TImplsItem.Count: Integer;
begin
  Result := items.Count;
end;

function TImplsItem.getItemByName(ObjName: string): TableOptDefItem;
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

procedure TImplsItem.load(afile: string);
begin
  if afile = '' then
    afile := FCfgPath
  else
    FCfgPath := afile;
  if not FileExists(afile) then
  begin
    Exit;
  end;
  loadXml(afile);
end;

procedure TImplsItem.loadBin(afile: string);
var
  mmo: TMemoryStream;
  Rter: TReader;
  tmpStr:string;
  tod:TableOptDefItem;
  tableCnt:Integer;
  I: Integer;
begin
  mmo := TMemoryStream.Create;
  try
    try
      mmo.LoadFromFile(afile);
      Rter := TReader.Create(mmo, 1);
      try
        if Rter.ReadInteger = $EE then
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

procedure TImplsItem.loadXml(afile: string);
var
  tod:TableOptDefItem;
  I: Integer;
  xml:IXMLDocument;
  Root,ItemsNode,RowNode : IXMLNode;
begin

  Xml := TXMLDocument.Create(nil);
  Xml.LoadFromFile(afile);
  xml.Active := True;
  Root := xml.DocumentElement;
  ItemsNode := Root.ChildNodes['items'];
  if ItemsNode<>nil then
  begin
    for I := 0 to ItemsNode.ChildNodes.Count-1 do
    begin
      RowNode := ItemsNode.ChildNodes[i];
      if (RowNode<>nil) and (RowNode.NodeName='row') and (RowNode.HasAttribute('name')) then
      begin
        tod := TableOptDefItem.Create;
        tod.ObjName := RowNode.Attributes['name'];
        tod.Insert := RowNode.ChildValues['Insert'];
        tod.Delete := RowNode.ChildValues['Delete'];
        tod.Update := RowNode.ChildValues['Update'];
        tod.Insert := StringReplace(tod.Insert,#$A,#$D#$A,[rfreplaceAll]);
        tod.Delete := StringReplace(tod.Delete,#$A,#$D#$A,[rfreplaceAll]);
        tod.Update := StringReplace(tod.Update,#$A,#$D#$A,[rfreplaceAll]);
        items.Add(tod);
      end;
    end;
  end;
end;

procedure TImplsItem.save(afile: string);
begin
  if afile = '' then
    afile := FCfgPath
  else
    FCfgPath := afile;
  saveXml(afile);
end;

procedure TImplsItem.saveBin(afile: string);
var
  wter: TWriter;
  I: Integer;
  tableBin: TMemoryStream;
  tod:TableOptDefItem;
begin
  tableBin := TMemoryStream.Create;
  wter := TWriter.Create(tableBin, 1);
  wter.WriteInteger($EE);
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

procedure TImplsItem.saveXml(afile: string);
var
  I: Integer;
  tod:TableOptDefItem;

  xml:IXMLDocument;
  ItemsNode,RowNode,tmpNode : IXMLNode;
begin
  Xml := TXMLDocument.Create(nil);
  Xml.Active := True;
  Xml.Version := '1.0';
  Xml.Encoding :='UTF-8';

  xml.DocumentElement := Xml.AddChild('OptDef');
  ItemsNode := xml.DocumentElement.AddChild('items');

  for I := 0 to items.Count - 1 do
  begin
    tod := TableOptDefItem(items[I]);
    RowNode := ItemsNode.AddChild('row');
    RowNode.Attributes['name'] := tod.ObjName;

    tmpNode := RowNode.AddChild('Insert');
    tmpNode.Text := tod.Insert;

    tmpNode := RowNode.AddChild('Delete');
    tmpNode.Text := tod.Delete;

    tmpNode := RowNode.AddChild('Update');
    tmpNode.Text := tod.Update;
  end;
  xml.SaveToFile(afile);
end;

{ TImplsManger }

function TImplsManger.Add(vvv: TImplsItem): Integer;
begin
  result := items.Add(vvv);
end;

function TImplsManger.Count: Integer;
begin
  result := items.Count;
end;

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

procedure TImplsManger.load;
var
  cfgStr:TStringList;
  idxfile:string;
  CfgCnt:Integer;
  I: Integer;
  impItem:TImplsItem;
begin
  idxfile := CfgPath + inttostr(dbid) + '.idx';
  if FileExists(idxfile) then
  begin
    cfgStr := TStringList.Create;
    try
      cfgStr.LoadFromFile(idxfile);
      Host := cfgStr.Values['Host'];
      user := cfgStr.Values['user'];
      pass := DesDecryStrHex(cfgStr.Values['pass'], DESPASSWORD);
      dbName := cfgStr.Values['dbName'];
      CfgCnt := strTointDef(cfgStr.Values['CfgCnt'], 0);
      for I := 0 to CfgCnt - 1 do
      begin
        try
          impItem := TImplsItem.Create;
          impItem.uid := cfgStr.Values['id_'+IntToStr(i)];
          impItem.Host := cfgStr.Values['host_'+IntToStr(i)];
          impItem.user := cfgStr.Values['user_'+IntToStr(i)];
          impItem.pass := DesDecryStrHex(cfgStr.Values['pass_'+IntToStr(i)], DESPASSWORD);
          impItem.dbName := cfgStr.Values['dbname_'+IntToStr(i)];
          impItem.Paused := cfgStr.Values['paused_' + IntToStr(I)] = '1';
          impItem.load(CfgPath + impItem.uid + '.db');
          items.add(impItem);
        except
          on EEE:Exception do
          begin
            Loger.Add('异构插件配置文件读取失败！' + inttostr(I) +' >> '+ EEE.Message);
          end;
        end;
      end;
    finally
      cfgStr.Free;
    end;
  end;
end;

procedure TImplsManger.save;
var
  I: Integer;
  impItem:TImplsItem;
  cfgStr:TStringList;
begin
  cfgStr := TStringList.Create;
  try
    cfgStr.Values['version'] := 'TImplsManger v 1.0';
    cfgStr.Values['Host'] := Host;
    cfgStr.Values['user'] := user;
    cfgStr.Values['pass'] := DesEncryStrHex(pass, DESPASSWORD);
    cfgStr.Values['dbName'] := dbName;
    cfgStr.Values['CfgCnt'] := IntToStr(items.Count);
    for I := 0 to items.Count - 1 do
    begin
      impItem := TImplsItem(items[i]);
      cfgStr.Values['id_'+IntToStr(i)] := impItem.uid;
      cfgStr.Values['host_'+IntToStr(i)] := impItem.Host;
      cfgStr.Values['user_'+IntToStr(i)] := impItem.user;
      cfgStr.Values['pass_'+IntToStr(i)] := DesEncryStrHex(impItem.pass, DESPASSWORD);
      cfgStr.Values['dbname_'+IntToStr(i)] := impItem.dbName;
      if impItem.Paused then
        cfgStr.Values['paused_' + IntToStr(I)] := '1'
      else
        cfgStr.Values['paused_' + IntToStr(I)] := '0';

      impItem.save(CfgPath + impItem.uid + '.db');
    end;
    cfgStr.SaveToFile(CfgPath + inttostr(dbid) + '.idx');
  finally
    cfgStr.Free;
  end;
end;

{ TImplsItem }

constructor TImplsItem.Create;
begin
  items := TObjectList.Create;
  Paused := False;
end;

destructor TImplsItem.Destroy;
begin
  items.Free;
  inherited;
end;

function TImplsItem.getState: TImplsItemState;
begin
  if Paused then
  begin
    Result := Pause;
  end else begin
    if items.Count = 0 then
    begin
      Result := Unconfigured
    end else
    begin
      Result := Normal;
    end;
  end;
end;

{ TLrSvrJob }

constructor TLrSvrJob.Create;
var
 I:Integer;
begin
  SetLength(items, 1000);
  for I := 0 to Length(items)-1 do
  begin
    items[i] := nil;
  end;
end;

function TLrSvrJob.defcfgPath: string;
begin
  Result := ExtractFilePath(GetModuleName(HInstance)) + 'heteroSync\';
  ForceDirectories(Result);
end;

destructor TLrSvrJob.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(items) - 1 do
  begin
    if items[I]<>nil then
      items[I].Free;
  end;
  SetLength(items, 0);
  inherited;
end;

function TLrSvrJob.get(source:Pplg_source): TImplsManger;
begin
  if (source.dbid > 0) and (source.dbid < Length(items)) then
  begin
    Result := items[source.dbid];
    if Result = nil then
    begin
      items[source.dbid] := TImplsManger.Create;
      items[source.dbid].CfgPath := defcfgPath;
      items[source.dbid].Host := source.host;
      items[source.dbid].user := source.user;
      items[source.dbid].pass := source.pass;
      items[source.dbid].dbName := source.dbName;
      items[source.dbid].dbid := source.dbid;
      Result := items[source.dbid];
    end;
  end
  else
  begin
    raise Exception.Create('Error Message');
  end;
end;

procedure TLrSvrJob.load;
var
  cfgPath: string;
  I: Integer;
  fff:string;
begin
  cfgPath := defcfgPath;
  for I := 0 to Length(items) - 1 do
  begin
    fff := CfgPath + inttostr(i) + '.idx';
    if FileExists(fff) then
    begin
      items[i] := TImplsManger.Create;
      items[i].CfgPath := CfgPath;
      items[i].load;
    end;
  end;
end;

initialization
  LrSvrJob := TLrSvrJob.Create;
  LrSvrJob.load;

finalization
  LrSvrJob.Free;


end.
