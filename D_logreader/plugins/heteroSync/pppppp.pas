unit pppppp;

interface

uses
  System.Contnrs, System.Classes, plgSrcData, Xml.XMLIntf;

const
  DESPASSWORD = 'lkjhyuio';

type
  TImplsItemState = (Unconfigured, Normal, Pause);

  TableOptDefItem = class(TObject)
    ReplaceParam2Str:Boolean;
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
    function getSqlTemplate(objName:string; typeStr:string;var p2s:Boolean):string;
  public
    uid:string;
    //デスティネーション
    ConnStr:string;
    Paused:Boolean;
    procedure save(afile: string = '');
    procedure load(afile: string = '');

    constructor Create;
    destructor Destroy; override;
    function getState:TImplsItemState;
    function getItemByName(ObjName: string): TableOptDefItem;
    function Count: Integer;
    function Add(vvv:TableOptDefItem):Integer;
    procedure Remove(ObjName: string);
    function RunSql(objName, typeStr: string; OptNode: IXMLNode):string;
  end;

  TImplsManger = class(TObject)
  public
   //データソース
    Host:string;
    user:string;
    pass:string;
    dbName:string;
    dbid:Integer;

    items:TObjectList; 
    CfgPath:string;
    constructor Create;
    destructor Destroy; override;
    function find(ConnStr: string):TImplsItem;
    procedure save;
    procedure load(afile:string='');
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

function getConnectionString(host, user, pwd, dbName: string): string;
function getDispConnStr(ConnStr: string; fullSs: boolean = False): string;
function getXmlTextWithTureEol(node:IXMLNode): string;
function getSqlParams(aSql:string):TStringList;


var
  LrSvrJob: TLrSvrJob;

implementation

uses
  System.SysUtils, Xml.XMLDoc, loglog, Des, System.Variants, Data.Win.ADODB,
  RegularExpressions;

function getConnectionString(host, user, pwd, dbName: string): string;
begin
  Result := Format('Provider=SQLOLEDB.1;Persist Security Info=True;Data Source=%s;User ID=%s;Password=%s;Initial Catalog=%s', [host, user, pwd, dbName]);
end;

function getXmlTextWithTureEol(node:IXMLNode): string;
begin
  result := '';
  if not VarIsNull(node) then
  begin
    result := node.Text;
    if Pos(#$A, Result) > 0 then
    begin
      if Pos(#$D#$A, node.XML) > 0 then
      begin
        result := StringReplace(result, #$A, #$D#$A, [rfreplaceAll]);
      end;
    end;
  end;
end;

function getSqlParams(aSql:string):TStringList;
var
  ms:TMatchCollection;
  I: Integer;
begin
  Result := TStringList.Create;
  ms := TRegEx.Matches(aSql,'(\@[\w\$\x{4e00}-\x{9fBF}]+)',[roMultiLine]);
  for I := 0 to ms.Count-1 do
  begin
    if Result.IndexOf(ms[i].Value)=-1 then
    begin
      Result.Add(ms[i].Value);
    end;
  end;
end;

function getDispConnStr(ConnStr: string; fullSs: boolean): string;
var
  ssss: TStringList;
  ff:TstringList;
begin
  ssss := TStringList.Create;
  try
    ssss.StrictDelimiter := True;
    ssss.Delimiter := ';';
    ssss.DelimitedText := ConnStr;
    Result := ssss.Values['Data Source'];
    if (Result = '') or fullSs then
    begin
      ff:=TstringList.Create;
      ff.Values['Data Source'] := ssss.Values['Data Source'];
      ff.Values['Initial Catalog'] := ssss.Values['Initial Catalog'];
      ff.Values['User ID'] := ssss.Values['User ID'];
      Result := stringreplace(ff.Text, #$D#$A, ';', [rfReplaceAll]);
      ff.Free;
    end;
  finally
    ssss.Free;
  end;
end;

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
            DefLoger.Add('配置文件读取失败(HeadCheckFail2):'+afile);
          end;
        end else begin
          DefLoger.Add('配置文件读取失败(HeadCheckFail):'+afile);
        end;
      finally
        Rter.Free;
      end;
    except
      on EE:Exception do
      begin
        DefLoger.Add('配置文件读取失败:'+afile);
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
      if (RowNode <> nil) and (RowNode.NodeName = 'row') and (RowNode.HasAttribute('name')) then
      begin
        tod := TableOptDefItem.Create;
        tod.ObjName := RowNode.Attributes['name'];
        if RowNode.HasAttribute('ReplaceParam2Str') then
          tod.ReplaceParam2Str := RowNode.Attributes['ReplaceParam2Str'] = '1';
        tod.Insert := getXmlTextWithTureEol(RowNode.ChildNodes['Insert']);
        tod.Delete := getXmlTextWithTureEol(RowNode.ChildNodes['Delete']);
        tod.Update := getXmlTextWithTureEol(RowNode.ChildNodes['Update']);
        items.Add(tod);
      end;
    end;
  end;
end;

procedure TImplsItem.Remove(ObjName: string);
var
  I: Integer;
begin
  for I := 0 to items.Count - 1 do
  begin
    if TableOptDefItem(items[I]).ObjName = ObjName then
    begin
      items.Delete(i);
      Break;
    end;
  end;
end;

function TImplsItem.RunSql(objName, typeStr: string; OptNode: IXMLNode): string;
var
  SqlTemplate_Bak,SqlTemplate:string;
  adoq:TADOQuery;
  ParamLst:TStringList;
  p2s:Boolean;
  I, J: Integer;
  paramName:string;
  nodeName:string;

  var
  field,valueNode:IXMLNode;
  dtype:string;
  ssvL:string;
  tmpPa:TParameter;
begin
  SqlTemplate := getSqlTemplate(objName, typeStr, p2s);
  SqlTemplate_Bak := SqlTemplate;
  if SqlTemplate <> '' then
  begin
    ParamLst := getSqlParams(SqlTemplate);
    adoq := TADOQuery.Create(nil);
    try
      adoq.Close;
      try
        if not p2s then
        begin
          //定义入参
          adoq.SQL.Text := SqlTemplate.Replace('@',':',[rfReplaceAll]);
          adoq.Parameters.Clear;
        end;
        for I := 0 to ParamLst.Count-1 do
        begin
          paramName := ParamLst[i];
          if paramName.StartsWith('@$') then
          begin
            //old
            nodeName := paramName.Substring(2);
          end else begin
            //new
            nodeName := paramName.Substring(1);
          end;
          for J := 0 to OptNode.ChildNodes.Count - 1 do
          begin
            if OptNode.ChildNodes[J].NodeName= nodeName then
            begin
              field := OptNode.ChildNodes[J];
              if typeStr = 'update' then
              begin
                if paramName.StartsWith('@$') then
                begin
                  //old
                  valueNode := field.ChildNodes['old'];
                end else begin
                  //new
                  valueNode := field.ChildNodes['new'];
                end;
              end else begin
                //insert ,delete
                valueNode := field;
              end;
              if field.HasAttribute('dtype') then
              begin
                dtype := field.Attributes['dtype'];
              end;

              if p2s then
              begin
                //参数替换为值
                if valueNode.HasAttribute('null') then
                begin
                  ssvL := 'NULL';
                end else begin
                  if dtype = 'int' then
                  begin
                    ssvL := valueNode.Text;
                  end
                  else if dtype = 'float' then
                  begin
                    ssvL := valueNode.Text;
                  end
                  else if dtype = 'bin' then
                  begin
                    ssvL := valueNode.Text;
                  end
                  else if dtype = 'bool' then
                  begin
                    ssvL := valueNode.Text;
                  end
                  else
                  begin
                    ssvL := valueNode.Text.QuotedString;
                  end;
                end;
                SqlTemplate := StringReplace(SqlTemplate, paramName, ssvL,[rfReplaceAll]);
              end else begin
                //定义入参
                tmpPa := adoq.Parameters.AddParameter;
                tmpPa.Name := paramName;
                if valueNode.HasAttribute('null') then
                begin
                  tmpPa.Value := null;
                end else begin
                  if dtype = 'int' then
                  begin
                    tmpPa.Value := valueNode.Text;
                  end
                  else if dtype = 'float' then
                  begin
                    tmpPa.Value := valueNode.Text;
                  end
                  else if dtype = 'bin' then
                  begin
                    tmpPa.Value := valueNode.Text;
                  end
                  else if dtype = 'bool' then
                  begin
                    tmpPa.Value := valueNode.Text;
                  end
                  else
                  begin
                    tmpPa.Value := valueNode.Text;
                  end;
                end;
              end;
              Break;
            end;
          end;
        end;
        if p2s then
        begin
          adoq.SQL.Text := SqlTemplate;
        end;
        adoq.ConnectionString := ConnStr;
        adoq.ExecSQL;
      except
        on Eee:Exception do
        begin
          dtype := '执行Sql失败！！' + Eee.Message+#$D#$A+'================================================';
          dtype := dtype +'XML:'+ OptNode.XML+#$D#$A+'------------------';
          dtype := dtype +'SQL:'+ SqlTemplate_Bak;
          DefLoger.Add(dtype, LOG_ERROR or LOG_IMPORTANT);
        end;
      end;
    finally
      adoq.Free;
      ParamLst.Free;
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
    if tod.ReplaceParam2Str then
      RowNode.Attributes['ReplaceParam2Str'] := '1'
    else
      RowNode.Attributes['ReplaceParam2Str'] := '0';

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

function TImplsManger.find(ConnStr: string): TImplsItem;
var
  I: Integer;
begin
  result := nil;
  for I := 0 to items.Count-1 do
  begin
    if TImplsItem(items.Items[I]).ConnStr = ConnStr then
    begin
      Result := TImplsItem(items.Items[I]);
    end;
  end;
end;

procedure TImplsManger.load(afile:string);
var
  cfgStr:TStringList;
  idxfile:string;
  CfgCnt:Integer;
  I: Integer;
  impItem:TImplsItem;
begin
  if afile='' then
    idxfile := CfgPath + inttostr(dbid) + '.idx'
  else
    idxfile := afile;
  if FileExists(idxfile) then
  begin
    cfgStr := TStringList.Create;
    try
      cfgStr.LoadFromFile(idxfile);
      dbName := cfgStr.Values['dbName'];
      dbid := StrToIntDef(cfgStr.Values['dbid'], 0);
      CfgCnt := strTointDef(cfgStr.Values['CfgCnt'], 0);
      for I := 0 to CfgCnt - 1 do
      begin
        try
          impItem := TImplsItem.Create;
          impItem.uid := cfgStr.Values['id_'+IntToStr(i)];
          impItem.ConnStr := DesDecryStrHex(cfgStr.Values['connstr_'+IntToStr(i)], DESPASSWORD);
          impItem.Paused := cfgStr.Values['paused_' + IntToStr(I)] = '1';
          impItem.load(CfgPath + impItem.uid + '.db');
          items.add(impItem);
        except
          on EEE:Exception do
          begin
            DefLoger.Add('异构插件配置文件读取失败！' + inttostr(I) +' >> '+ EEE.Message);
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
    cfgStr.Values['dbName'] := dbName;
    cfgStr.Values['dbid'] := IntToStr(dbid);
    cfgStr.Values['CfgCnt'] := IntToStr(items.Count);
    for I := 0 to items.Count - 1 do
    begin
      impItem := TImplsItem(items[i]);
      cfgStr.Values['id_'+IntToStr(i)] := impItem.uid;
      cfgStr.Values['connstr_'+IntToStr(i)] := DesEncryStrHex(impItem.connstr, DESPASSWORD);
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

function TImplsItem.getSqlTemplate(objName, typeStr: string;var p2s:Boolean): string;
var
  dii: TableOptDefItem;
begin
  Result := '';
  dii := getItemByName(objName);
  if dii <> nil then
  begin
    if typeStr = 'insert' then
    begin
      Result := dii.Insert;
    end
    else if typeStr = 'delete' then
    begin
      Result := dii.Delete;
    end
    else if typeStr = 'update' then
    begin
      Result := dii.Update;
    end;
    p2s := dii.ReplaceParam2Str;
  end;
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
      Result := items[source.dbid];
    end;
    Result.Host := source.host;
    Result.user := source.user;
    Result.pass := source.pass;
    Result.dbName := source.dbName;
    Result.dbid := source.dbid;
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
      items[i].load(fff);
    end;
  end;
end;

initialization
  LrSvrJob := TLrSvrJob.Create;
  LrSvrJob.load;

finalization
  LrSvrJob.Free;


end.
