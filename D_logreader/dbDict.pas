unit dbDict;

interface

uses
  Contnrs, Classes, ADODB, IniFiles, System.SysUtils, Xml.XMLIntf,
  System.Generics.Collections;

type
  TdbFieldItem = class(TObject)
    Col_id: Integer;
    ColName: string;
    type_id: Word;
    nullMap: Integer;
    Max_length: Word;
    procision: Integer;
    scale: Integer;
    is_nullable: Boolean;
    leaf_pos: Integer;
    collation_name: string;  //字符集
    CodePage: Integer;
    //identify
    Idt_seed:Integer;
    Idt_increment:Integer;
    //
    isLogSkipCol:Boolean;
    function getSafeColName: string;
    constructor Create;
    function getTypeStr: string;
  end;

  TdbFields = class(TObject)
  private
    FItems: TObjectList;
    FItems_s_Id: array of TdbFieldItem; //根据id排序的内容
    FItems_s_Name: TStringHash;          //根据名称排序的
    fSorted: Boolean;
    fRowMaxLength:Integer;
    function GetItemsCount: Integer;
    function GetItem(idx: Integer): TdbFieldItem;
    procedure Sort;
  public
    constructor Create;
    destructor Destroy; override;
    procedure addField(item: TdbFieldItem);
    procedure RemoveField(ColName:string);
    property Count: Integer read GetItemsCount;
    property Items[idx: Integer]: TdbFieldItem read GetItem; default;
    function GetItemById(ColId: Integer): TdbFieldItem;
    function GetItemByName(ColName: string): TdbFieldItem;
    function Get_RowMaxLength:Integer;
  end;

  TdbTableItem = class(TObject)
    TableId: Integer;
    TableNmae: string;
    Owner: string;
    Fields: TdbFields;
    /// <summary>
    /// 唯一聚合键（如果有
    /// </summary>
    UniqueClusteredKeys:TList;
    hasIdentity:Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function getFullName: string;
    function getNullMapLength: Integer;

    function Serialize:TMemoryStream;
    procedure Deserialize(data:TMemoryStream);
    function AsXml:string;overload;
    procedure AsXml(Node:IXMLNode);overload;
    function loadXml(tableNode:IXMLNode):Boolean;
  end;

  TdbTables = class(TObject)
  private
    FItems: TObjectList;
    FItems_s_Id: array of TdbTableItem; //根据id排序的内容
    FItems_s_Name: TStringHash;         //根据名称排序的
    fSorted: Boolean;
    function GetItem(idx: Integer): TdbTableItem;
    function GetItemsCount: Integer;
    procedure Sort;
  public
    Alloc2ObjId: TDictionary<UInt64, Integer>;
    Parti2ObjId: TDictionary<UInt64, Integer>;
    constructor Create;
    destructor Destroy; override;
    procedure addTable(item: TdbTableItem);
    procedure RemoveTable(objId:Integer);
    property Count: Integer read GetItemsCount;
    property Items[idx: Integer]: TdbTableItem read GetItem; default;
    function GetItemById(TableId: Integer): TdbTableItem;
    function GetItemByName(TableName: string): TdbTableItem;
    function GetItemByPartitionId(PartitionId: Int64): TdbTableItem;
    procedure addAlloc(k:UInt64; v:Integer);
    procedure addParti(k:UInt64; v:Integer);
  end;

  TDbDict = class(TObject)
  public
    tables: TdbTables;
    procedure RefreshTables(Qry: TCustomADODataSet);
    procedure RefreshTablesFields(Qry: TCustomADODataSet);
    procedure RefreshTablesUniqueKey(Qry: TCustomADODataSet);
    procedure RefreshAlloc(Qry: TCustomADODataSet);
    procedure RefreshParti(Qry: TCustomADODataSet);
    constructor Create;
    destructor Destroy; override;

    function Serialize:TMemoryStream;
    procedure Deserialize(data: TMemoryStream);
    procedure toXml(node:IXMLNode);
    procedure fromXml(node:IXMLNode);
  end;

  PdbFieldValue = ^TdbFieldValue;

  TdbFieldValue = record
    field: TdbFieldItem;
    value: TBytes;
    isNull:Boolean;
  end;

  TtableFilterItem = class(TObject)
  public
    filterType:Integer;  //equal,endwith,startwith
    valueStr:string;
    function ToString: string; override;
    function check(astr:string): Boolean;
  end;


implementation

uses
  loglog, Types, Variants, Xml.XMLDoc, dbFieldTypes, System.StrUtils;

{ TDbDict }

constructor TDbDict.Create;
begin
  tables := TdbTables.Create;
end;

destructor TDbDict.Destroy;
begin
  tables.Free;
end;

procedure TDbDict.RefreshAlloc(Qry: TCustomADODataSet);
var
  k:UInt64;
  v:Integer;
begin
  while not Qry.Eof do
  begin
    k := Qry.Fields[0].AsLargeInt;
    v := Qry.Fields[1].AsInteger;
    tables.addAlloc(k, v);
    Qry.Next;
  end;
end;

procedure TDbDict.RefreshParti(Qry: TCustomADODataSet);
var
  k:UInt64;
  v:Integer;
begin
  while not Qry.Eof do
  begin
    k := Qry.Fields[0].AsLargeInt;
    v := Qry.Fields[1].AsInteger;
    tables.addParti(k, v);
    Qry.Next;
  end;
end;

procedure TDbDict.RefreshTables(Qry: TCustomADODataSet);
var
  tti: TdbTableItem;
begin
  //非线程安全，保证在事务线程启动之前运行
  tables.Free;
  tables := TdbTables.Create;
  while not Qry.Eof do
  begin
    tti := TdbTableItem.Create;
    tti.Owner := Qry.Fields[0].AsString;
    tti.TableId := Qry.Fields[1].AsInteger;
    tti.TableNmae := LowerCase(Qry.Fields[2].AsString);
    tables.addTable(tti);
    Qry.Next;
  end;
end;

procedure TDbDict.RefreshTablesFields(Qry: TCustomADODataSet);
var
  tti: TdbTableItem;
  tblId: Integer;
  field: TdbFieldItem;
begin
  tblId := 0;
  tti := nil;
  while not Qry.Eof do
  begin
    if tblId <> Qry.Fields[0].AsInteger then
    begin
      tblId := Qry.Fields[0].AsInteger;
      tti := tables.GetItemById(tblId);
    end;
    if tti <> nil then
    begin
      field := TdbFieldItem.Create;
      field.Col_id := Qry.Fields[1].AsInteger;
      field.type_id := Qry.Fields[2].AsInteger;
      field.Max_length := Qry.Fields[3].AsInteger;
      field.procision := Qry.Fields[4].AsInteger;
      field.scale := Qry.Fields[5].AsInteger;
      field.is_nullable := Qry.Fields[6].AsBoolean;
      field.ColName := Qry.Fields[7].AsString;
      field.nullMap := Qry.Fields[8].AsInteger - 1;
      field.leaf_pos := Qry.Fields[9].AsInteger;
      field.collation_name := Qry.Fields[10].AsString;
      if Qry.Fields[11].IsNull then
        field.CodePage := -1
      else
        field.CodePage := Qry.Fields[11].AsInteger;
      if (not Qry.Fields[12].IsNull) and Qry.Fields[12].AsBoolean then
      begin
        //is identity
        tti.hasIdentity := True;
      end;
      if field.ColName = '' then
      begin
        field.isLogSkipCol := True;
      end else begin
        if Qry.Fields[13].AsBoolean then
        begin
          field.isLogSkipCol := True;
        end;
      end;
      tti.Fields.addField(field);
    end;
    Qry.Next;
  end;
end;

procedure TDbDict.RefreshTablesUniqueKey(Qry: TCustomADODataSet);
var
  tti: TdbTableItem;
  tblId: Integer;
  field: TdbFieldItem;
begin
  tblId := 0;
  tti := nil;
  while not Qry.Eof do
  begin
    if tblId <> Qry.Fields[0].AsInteger then
    begin
      tblId := Qry.Fields[0].AsInteger;
      tti := tables.GetItemById(tblId);
      if tti <> nil then
        tti.UniqueClusteredKeys.Clear;
    end;
    if tti <> nil then
    begin
      field := tti.Fields.GetItemById(Qry.Fields[1].AsInteger);
      if field<>nil then
      begin
        tti.UniqueClusteredKeys.Add(field);
      end;
    end;
    Qry.Next;
  end;
end;

function TDbDict.Serialize:TMemoryStream;
var
  wter: TWriter;
  I: Integer;
  tableBin: TMemoryStream;
begin
  Result := TMemoryStream.Create;
  wter := TWriter.Create(Result, 1);
  wter.WriteInteger(tables.Count);
  for I := 0 to tables.Count - 1 do
  begin
    tableBin := tables[I].Serialize;
    tableBin.seek(0, 0);
    wter.Write(tableBin.Memory^, tableBin.Size);
    tableBin.Free;
  end;
  wter.WriteInteger(10);
  wter.FlushBuffer;
  wter.Free;
end;

procedure TDbDict.toXml(node: IXMLNode);
var
  I: Integer;
  aTable:TdbTableItem;
  TmpNode,tn2:IXMLNode;
  aa:TArray<TPair<UInt64, Integer>>;
begin
  TmpNode := node.AddChild('tables');
  for I := 0 to tables.Count-1 do
  begin
    aTable := tables.Items[i];
    aTable.AsXml(TmpNode);
  end;
  TmpNode := node.AddChild('alloc');
  aa := tables.Alloc2ObjId.ToArray();
  for I := 0 to Length(aa) - 1 do
  begin
    tn2 := TmpNode.AddChild('a');
    tn2.Attributes['k'] := aa[I].Key;
    tn2.Attributes['v'] := aa[I].Value;
  end;
  TmpNode := node.AddChild('parti');
  aa := tables.Parti2ObjId.ToArray();
  for I := 0 to Length(aa) - 1 do
  begin
    tn2 := TmpNode.AddChild('a');
    tn2.Attributes['k'] := aa[I].Key;
    tn2.Attributes['v'] := aa[I].Value;
  end;
end;

procedure TDbDict.fromXml(node: IXMLNode);
var
  table:TdbTableItem;
  I: Integer;
  TmpNode,tn2:IXMLNode;
  k:UInt64;
  v:Integer;
begin
  TmpNode := node.ChildNodes['tables'];
  for I := 0 to TmpNode.ChildNodes.Count - 1 do
  begin
    if TmpNode.ChildNodes[I].NodeName = 'table' then
    begin
      table := TdbTableItem.Create;
      table.loadXml(TmpNode.ChildNodes[I]);
      tables.addTable(table);
    end;
  end;
  TmpNode := node.ChildNodes['alloc'];
  for I := 0 to TmpNode.ChildNodes.Count - 1 do
  begin
    tn2 := TmpNode.ChildNodes[I];
    if (tn2.NodeName = 'a') and (tn2.HasAttribute('k')) and (tn2.HasAttribute('v')) then
    begin
      k := tn2.Attributes['k'];
      v := tn2.Attributes['v'];
      tables.Alloc2ObjId.Add(k, v);
    end;
  end;
  TmpNode := node.ChildNodes['parti'];
  for I := 0 to TmpNode.ChildNodes.Count - 1 do
  begin
    tn2 := TmpNode.ChildNodes[I];
    if (tn2.NodeName = 'a') and (tn2.HasAttribute('k')) and (tn2.HasAttribute('v')) then
    begin
      k := tn2.Attributes['k'];
      v := tn2.Attributes['v'];
      tables.Parti2ObjId.Add(k, v);
    end;
  end;
end;

procedure TDbDict.Deserialize(data: TMemoryStream);
var
  Rter: TReader;
  tableCount:Integer;
  I: Integer;
  table:TdbTableItem;
begin
  Rter := TReader.Create(data, 1);
  try
    tableCount := Rter.ReadInteger;
    for I := 0 to tableCount -1 do
    begin
      table := TdbTableItem.Create;
      tables.addTable(table);
      table.Deserialize(data);
    end;
  finally
    Rter.Free;
  end;
end;

{ TdbFields }

procedure TdbFields.addField(item: TdbFieldItem);
var
  idx: Integer;
begin
  idx := FItems.Add(item);
  FItems_s_Name.Add(item.ColName, idx);
  fSorted := False;
end;

constructor TdbFields.Create;
begin
  fSorted := False;
  FItems := TObjectList.Create;
  FItems_s_Name := TStringHash.Create;
  fRowMaxLength := -1;
end;

destructor TdbFields.Destroy;
begin
  FItems_s_Name.Free;
  FItems.Free;
  inherited;
end;

function TdbFields.GetItem(idx: Integer): TdbFieldItem;
begin
  Result := TdbFieldItem(FItems.Items[idx]);
end;

function TdbFields.GetItemById(ColId: Integer): TdbFieldItem;
var
  H, L, M: Integer;
begin
  if not fSorted then
    Sort;
  //二分查找
  L := 0;
  H := Count - 1;
  while L <= H do
  begin
    M := (L + H) div 2;
    if FItems_s_Id[M].Col_id = ColId then
    begin
      Result := FItems_s_Id[M];
      Exit;
    end
    else if FItems_s_Id[M].Col_id > ColId then
    begin
      H := M - 1;
    end
    else
    begin
      L := M + 1;
    end;
  end;
  Result := nil;
end;

function TdbFields.GetItemByName(ColName: string): TdbFieldItem;
var
  idx: Integer;
begin
  idx := FItems_s_Name.ValueOf(ColName);
  if idx = -1 then
  begin
    Result := nil;
  end
  else
  begin
    Result := TdbFieldItem(FItems[idx]);
  end;
end;

function TdbFields.GetItemsCount: Integer;
begin
  Result := FItems.Count;
end;

function TdbFields.Get_RowMaxLength: Integer;
var
  I: Integer;
  sss: TdbFieldItem;
begin
  if fRowMaxLength < 1 then
  begin
    fRowMaxLength := 0;
    for I := 0 to Count - 1 do
    begin
      sss := Items[I];
      if sss.Max_length > 0 then
      begin
        fRowMaxLength := fRowMaxLength + sss.Max_length;
      end;
    end;
  end;
  Result := fRowMaxLength;
end;

procedure TdbFields.RemoveField(ColName: string);
var
  field:TdbFieldItem;
begin
  field := GetItemByName(ColName);
  if field<>nil then
  begin
    FItems.Remove(field);
    FItems_s_Name.Remove(ColName);
    fSorted := False;
  end;
end;

procedure TdbFields.Sort;
var
  I, J: Integer;
  tmpItm: TdbFieldItem;
begin
  SetLength(FItems_s_Id, Count);
  for I := 0 to Count - 1 do
  begin
    FItems_s_Id[I] := TdbFieldItem(FItems[I]);
  end;
  for I := 0 to count - 1 do
  begin
    for J := I + 1 to Count - 1 do
    begin
      if FItems_s_Id[I].Col_id > FItems_s_Id[J].Col_id then
      begin
        tmpItm := FItems_s_Id[I];
        FItems_s_Id[I] := FItems_s_Id[J];
        FItems_s_Id[J] := tmpItm;
      end;
    end;
  end;
  fSorted := True;
end;

{ TdbTables }

procedure TdbTables.addAlloc(k: UInt64; v: Integer);
begin
  if Alloc2ObjId.ContainsKey(k) then
  begin
    Alloc2ObjId.Items[k] := v;
  end else begin
    Alloc2ObjId.Add(k, v);
  end;
end;

procedure TdbTables.addParti(k: UInt64; v: Integer);
begin
  if Parti2ObjId.ContainsKey(k) then
  begin
    Parti2ObjId.Items[k] := v;
  end
  else
  begin
    Parti2ObjId.Add(k, v);
  end;
end;

procedure TdbTables.addTable(item: TdbTableItem);

  function isIgnoreTable(Owner, TableName: string): Boolean;
  begin
    Result := False;
    if lowerCase(Owner) = 'sys' then
    begin
      // https://msdn.microsoft.com/zh-cn/library/ms179503
      TableName := LowerCase(TableName);
      if (TableName = 'sysprufiles') //数据库文件信息，路径，大小等、
      then
      begin
        result := true;
      end;
//      if (TableName = 'sysowners') or (TableName = 'sysschobjs') or (TableName = 'syscolpars') or (TableName = 'sysobjvalues') or (TableName = 'sysidxstats') or (TableName = 'sysiscols') or (TableName = 'sysrscols') or (TableName = 'syshobtcolumns') or (TableName = 'sysrowsetcolumns') or (TableName = 'sysallocunits') or (TableName = 'sysrowsets') or (TableName = 'syssingleobjrefs') or (TableName = 'sysmultiobjrefs') or (TableName = 'sysprivs') or (TableName = 'sysclsobjs') then
//      begin
//        Result := True;
//      end;
    end;
  end;

var
  idx: Integer;
begin
  if not isIgnoreTable(item.Owner, item.TableNmae) then
  begin
    idx := fitems.Add(item);
    FItems_s_Name.Add(item.getFullName, idx);
    fSorted := False;
  end
  else
  begin
    //如果是忽略的表，这里直接释放掉
    item.Free;
  end;
end;

procedure TdbTables.RemoveTable(objId: Integer);
var
  table:TdbTableItem;
begin
  table := GetItemById(objId);
  FItems_s_Name.Remove(table.getFullName);
  fitems.Remove(table);
  fSorted := False;
end;

constructor TdbTables.Create;
begin
  fSorted := False;
  FItems := TObjectList.Create;
  FItems_s_Name := TStringHash.Create;

  Alloc2ObjId:= TDictionary<UInt64, Integer>.create();
  Parti2ObjId:= TDictionary<UInt64, Integer>.create();
end;

destructor TdbTables.Destroy;
begin
  FItems.Free;
  FItems_s_Name.Free;
  Alloc2ObjId.Free;
  Parti2ObjId.Free;
  inherited;
end;

function TdbTables.GetItem(idx: Integer): TdbTableItem;
begin
  Result := TdbTableItem(FItems.Items[idx]);
end;

function TdbTables.GetItemById(TableId: Integer): TdbTableItem;
var
  H, L, M: Integer;
begin
  if not fSorted then
    Sort;
  //二分查找
  L := 0;
  H := Count - 1;
  while L <= H do
  begin
    M := (L + H) div 2;
    if FItems_s_Id[M].TableId = TableId then
    begin
      Result := FItems_s_Id[M];
      Exit;
    end
    else if FItems_s_Id[M].TableId > TableId then
    begin
      H := M - 1;
    end
    else
    begin
      L := M + 1;
    end;
  end;
  Result := nil;
end;

function TdbTables.GetItemByName(TableName: string): TdbTableItem;
var
  idx: Integer;
begin
  idx := FItems_s_Name.ValueOf(TableName);
  if idx = -1 then
  begin
    Result := nil;
  end
  else
  begin
    Result := TdbTableItem(FItems[idx]);
  end;
end;

function TdbTables.GetItemByPartitionId(PartitionId: Int64): TdbTableItem;
var
  objId: Integer;
begin
  if Parti2ObjId.TryGetValue(PartitionId, objId) then
  begin
    result := GetItemById(objId);
  end else begin
    result := nil;
  end;
end;

function TdbTables.GetItemsCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TdbTables.Sort;
var
  I, J: Integer;
  tmpItm: TdbTableItem;
begin
  SetLength(FItems_s_Id, Count);
  for I := 0 to Count - 1 do
  begin
    FItems_s_Id[I] := TdbTableItem(FItems[I]);
  end;
  for I := 0 to count - 1 do
  begin
    for J := I + 1 to Count - 1 do
    begin
      if FItems_s_Id[I].TableId > FItems_s_Id[J].TableId then
      begin
        tmpItm := FItems_s_Id[I];
        FItems_s_Id[I] := FItems_s_Id[J];
        FItems_s_Id[J] := tmpItm;
      end;
    end;
  end;
  fSorted := True;
end;

{ TdbTableItem }

function TdbTableItem.AsXml: string;
var
  xml:IXMLDocument;
begin
  xml := TXMLDocument.create(nil);
  xml.Active := True;
  AsXml(xml.AddChild('tables'));
  Result := xml.XML.Text;
end;

procedure TdbTableItem.AsXml(Node: IXMLNode);
var
  I: Integer;
  field:TdbFieldItem;
  rootNode,fieldsNode,tmpNode:IXMLNode;
begin
  rootNode := Node.AddChild('table');
  //rootNode.Attributes['partition_id'] := partition_id;
  rootNode.Attributes['TableId'] := TableId;
  rootNode.Attributes['Owner'] := Owner;
  rootNode.Attributes['TableNmae'] := TableNmae;
  rootNode.Attributes['hasIdentity'] := hasIdentity;
  fieldsNode := rootNode.AddChild('fields');
  for I := 0 to Fields.Count-1 do
  begin
    field := TdbFieldItem(Fields[i]);
    tmpNode := fieldsNode.AddChild('field');
    tmpNode.Attributes['Col_id'] := field.Col_id;
    tmpNode.Attributes['ColName'] := field.ColName;
    tmpNode.Attributes['type_id'] := field.type_id;
    tmpNode.Attributes['nullMap'] := field.nullMap;
    tmpNode.Attributes['Max_length'] := field.Max_length;
    tmpNode.Attributes['procision'] := field.procision;
    tmpNode.Attributes['scale'] := field.scale;
    tmpNode.Attributes['is_nullable'] := field.is_nullable;
    tmpNode.Attributes['leaf_pos'] := field.leaf_pos;
    tmpNode.Attributes['collation_name'] := field.collation_name;
    tmpNode.Attributes['CodePage'] := field.CodePage;
    tmpNode.Attributes['isLogSkipCol'] := field.isLogSkipCol;
  end;
  fieldsNode := rootNode.AddChild('UniqueClusteredKeys');
  for I := 0 to UniqueClusteredKeys.Count - 1 do
  begin
    field := TdbFieldItem(UniqueClusteredKeys[I]);
    tmpNode := fieldsNode.AddChild('field');
    tmpNode.Attributes['Col_id'] := field.Col_id;
  end;
end;

function TdbTableItem.loadXml(tableNode: IXMLNode): Boolean;
var
  Xmlfields,tmpNode:IXMLNode;
  I: Integer;
  field: TdbFieldItem;
  TmpColId:Integer;
begin
  if (not tableNode.HasAttribute('TableId')) or
     (not tableNode.HasAttribute('Owner')) or
     (not tableNode.HasAttribute('TableNmae')) or
     (not tableNode.HasAttribute('hasIdentity')) then
  begin
    raise Exception.Create('table属性读取失败！！！');
  end;

  //partition_id := tableNode.Attributes['partition_id'];
  TableId := tableNode.Attributes['TableId'];
  Owner := tableNode.Attributes['Owner'];
  TableNmae := tableNode.Attributes['TableNmae'];
  hasIdentity := tableNode.Attributes['hasIdentity'];

  Xmlfields := tableNode.ChildNodes['fields'];
  for I := 0 to Xmlfields.ChildNodes.Count - 1 do
  begin
    if Xmlfields.ChildNodes[i].NodeName = 'field' then
    begin
      tmpNode := Xmlfields.ChildNodes[i];
      if not tmpNode.HasAttribute('Col_id') then
      begin
        Continue;
      end;
      field := TdbFieldItem.Create;
      field.Col_id := tmpNode.Attributes['Col_id'];
      field.ColName := tmpNode.Attributes['ColName'];
      field.type_id := tmpNode.Attributes['type_id'];
      field.nullMap := tmpNode.Attributes['nullMap'];
      field.Max_length := tmpNode.Attributes['Max_length'];
      field.procision := tmpNode.Attributes['procision'];
      field.scale := tmpNode.Attributes['scale'];
      field.is_nullable := tmpNode.Attributes['is_nullable'];
      field.leaf_pos := tmpNode.Attributes['leaf_pos'];
      field.collation_name := tmpNode.Attributes['collation_name'];
      field.CodePage := tmpNode.Attributes['CodePage'];
      field.isLogSkipCol := tmpNode.Attributes['isLogSkipCol'];
      Fields.addField(field);
    end;
  end;
  Xmlfields := tableNode.ChildNodes['UniqueClusteredKeys'];
  for I := 0 to Xmlfields.ChildNodes.Count - 1 do
  begin
    tmpNode := Xmlfields.ChildNodes[i];
    if not tmpNode.HasAttribute('Col_id') then
    begin
      Continue;
    end;
    TmpColId := tmpNode.Attributes['Col_id'];

    field := fields.GetItemById(TmpColId);
    if field<>nil then
    begin
      UniqueClusteredKeys.Add(field);
    end;
  end;
  Result := True;
end;


constructor TdbTableItem.Create;
begin
  Fields := TdbFields.Create;
  UniqueClusteredKeys:=TList.Create;
  hasIdentity := False;
end;


destructor TdbTableItem.Destroy;
begin
  UniqueClusteredKeys.Free;
  Fields.Free;
  inherited;
end;

function TdbTableItem.getFullName: string;
begin
  Result := '[' + Owner.Replace(']',']]') + '].[' + TableNmae.Replace(']',']]') + ']';
end;

function TdbTableItem.getNullMapLength: Integer;
begin
  Result := (Fields.Count + 7) shr 3
end;

function TdbTableItem.Serialize: TMemoryStream;
var
  wter: TWriter;
  I: Integer;
  field: TdbFieldItem;
begin
  Result := TMemoryStream.Create;
  wter := TWriter.Create(Result, 1);
 // wter.WriteInteger(partition_id);
  wter.WriteInteger(TableId);
  wter.WriteString(TableNmae);
  wter.WriteString(Owner);
  wter.WriteBoolean(hasIdentity);
  wter.WriteInteger(Fields.FItems.Count);
  for I := 0 to Fields.FItems.Count - 1 do
  begin
    field := TdbFieldItem(Fields.FItems[I]);
    wter.WriteInteger(field.Col_id);
    wter.WriteString(field.ColName);
    wter.WriteInteger(field.type_id);
    wter.WriteInteger(field.type_id);
    wter.WriteInteger(field.nullMap);
    wter.WriteInteger(field.Max_length);
    wter.WriteInteger(field.procision);
    wter.WriteInteger(field.scale);
    wter.WriteBoolean(field.is_nullable);
    wter.WriteInteger(field.leaf_pos);
    wter.WriteString(field.collation_name);
    wter.WriteInteger(field.CodePage);
    wter.WriteBoolean(field.isLogSkipCol);
  end;
  wter.WriteInteger(UniqueClusteredKeys.Count);
  for I := 0 to UniqueClusteredKeys.Count - 1 do
  begin
    field := TdbFieldItem(UniqueClusteredKeys[I]);
    wter.WriteInteger(field.Col_id);
  end;
  wter.Free;
end;

procedure TdbTableItem.Deserialize(data: TMemoryStream);
var
  Rter: TReader;
  FieldCount:Integer;
  I: Integer;
  field: TdbFieldItem;
begin
  Rter := TReader.Create(data, 1);
  try
    //partition_id := Rter.ReadInt64;
    TableId := Rter.ReadInteger;
    TableNmae := Rter.ReadString;
    Owner := Rter.ReadString;
    hasIdentity := Rter.ReadBoolean;
    FieldCount := Rter.ReadInteger;
    for I := 0 to FieldCount - 1 do
    begin
      field := TdbFieldItem.Create;
      Fields.addField(field);
      field.Col_id := Rter.ReadInteger;
      field.ColName := Rter.ReadString;
      field.type_id := Rter.ReadInteger;
      field.type_id := Rter.ReadInteger;
      field.nullMap := Rter.ReadInteger;
      field.Max_length := Rter.ReadInteger;
      field.procision := Rter.ReadInteger;
      field.scale := Rter.ReadInteger;
      field.is_nullable := Rter.ReadBoolean;
      field.leaf_pos := Rter.ReadInteger;
      field.collation_name := Rter.ReadString;
      field.CodePage := Rter.ReadInteger;
      field.isLogSkipCol := Rter.ReadBoolean;
    end;
    // UniqueKeys.Count
    FieldCount := Rter.ReadInteger;
    for I := 0 to FieldCount - 1 do
    begin
      UniqueClusteredKeys.Add(Fields.GetItemById(Rter.ReadInteger));
    end;
  finally
    Rter.Free;
  end;
end;

{ TdbFieldItem }

constructor TdbFieldItem.Create;
begin
  CodePage := -1;
  Idt_seed := 0;
  Idt_increment := 0;
  isLogSkipCol := False;
end;

function TdbFieldItem.getSafeColName: string;
begin
  Result := '[' + ColName.Replace(']',']]') + ']';
end;

function TdbFieldItem.getTypeStr: string;
begin
  case type_id of
    MsTypes.IMAGE:
      Result := '[IMAGE]';
    MsTypes.TEXT:
      Result := '[TEXT]';
    MsTypes.UNIQUEIDENTIFIER:
      Result := '[UNIQUEIDENTIFIER]';
    MsTypes.DATE:
      Result := '[DATE]';
    MsTypes.TIME:
      Result := Format('[TIME](%d)', [scale]);
    MsTypes.DATETIME2:
      Result := Format('[DATETIME2](%d)', [scale]);
    MsTypes.DATETIMEOFFSET:
      Result := Format('[DATETIMEOFFSET](%d)', [scale]);
    MsTypes.TINYINT:
      Result := '[TINYINT]';
    MsTypes.SMALLINT:
      Result := '[SMALLINT]';
    MsTypes.INT:
      Result := '[INT]';
    MsTypes.SMALLDATETIME:
      Result := '[SMALLDATETIME]';
    MsTypes.REAL:
      Result := '[REAL]';
    MsTypes.MONEY:
      Result := '[MONEY]';
    MsTypes.DATETIME:
      Result := '[DATETIME]';
    MsTypes.FLOAT:
      Result := '[FLOAT]';
    MsTypes.SQL_VARIANT:
      Result := '[SQL_VARIANT]';
    MsTypes.NTEXT:
      Result := '[NTEXT]';
    MsTypes.BIT:
      Result := '[BIT]';
    MsTypes.DECIMAL:
      Result := Format('[DECIMAL](%d,%d)', [procision, scale]);
    MsTypes.NUMERIC:
      Result := Format('[NUMERIC](%d,%d)', [procision, scale]);
    MsTypes.SMALLMONEY:
      Result := '[SMALLMONEY]';
    MsTypes.BIGINT:
      Result := '[BIGINT]';
    MsTypes.VARBINARY:
      if Max_length = $FFFF then
      begin
        Result := '[VARBINARY](MAX)';
      end
      else
        Result := Format('[VARBINARY](%d)', [Max_length]);
    MsTypes.VARCHAR:
      if Max_length = $FFFF then
      begin
        Result := '[VARCHAR](MAX)';
      end
      else
        Result := Format('[VARCHAR](%d)', [Max_length]);
    MsTypes.BINARY:
      if Max_length = $FFFF then
      begin
        Result := '[BINARY](MAX)';
      end
      else
        Result := Format('[BINARY](%d)', [Max_length]);
    MsTypes.CHAR:
      if Max_length = $FFFF then
      begin
        Result := '[CHAR](MAX)';
      end
      else
        Result := Format('[CHAR](%d)', [Max_length]);
    MsTypes.TIMESTAMP:
      Result := '[TIMESTAMP]';
    MsTypes.NVARCHAR:
      if Max_length = $FFFF then
      begin
        Result := '[NVARCHAR](MAX)';
      end
      else
        Result := Format('[NVARCHAR](%d)', [Max_length]);
    MsTypes.NCHAR:
      if Max_length = $FFFF then
      begin
        Result := '[NCHAR](MAX)';
      end
      else
        Result := Format('[NCHAR](%d)', [Max_length]);
    MsTypes.XML:
      Result := '[XML]';
    MsTypes.GEOGRAPHY:
      Result := '[GEOGRAPHY]';
  else
    Result := '';
  end;
end;

{ TtableFilterItem }

function TtableFilterItem.check(astr: string): Boolean;
begin
  if filterType = 1 then
  begin
    Result := astr.StartsWith(valueStr);
  end
  else if filterType = 2 then
  begin
    Result := astr.EndsWith(valueStr);
  end
  else if filterType = 3 then
  begin
    Result := pos(valueStr, astr) > 0;
  end
  else
  begin
    Result := valueStr = astr;
  end;
end;

function TtableFilterItem.ToString: string;
begin
  if filterType = 1 then
  begin
    Result := '开头是:'+valueStr;
  end
  else if filterType = 2 then
  begin
    Result := '结尾是:'+valueStr;
  end
  else if filterType = 3 then
  begin
    Result := '包含字符:'+valueStr;
  end
  else
  begin
    Result := valueStr;
  end;
end;

end.

