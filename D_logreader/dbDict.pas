unit dbDict;

interface

uses
  Contnrs, Classes, ADODB, IniFiles, System.SysUtils;

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
    function isLogSkipCol: Boolean;
    function getSafeColName: string;
    constructor Create;
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
  public
    constructor Create;
    destructor Destroy; override;
    function getFullName: string;
    function getNullMapLength: Integer;

    function Serialize:TMemoryStream;
    procedure Deserialize(data:TMemoryStream);
  end;

  TdbTables = class(TObject)
  private
    FItems: TObjectList;
    FItems_s_Id: array of TdbTableItem; //根据id排序的内容
    FItems_s_Name: TStringHash;    //根据名称排序的
    fSorted: Boolean;
    function GetItem(idx: Integer): TdbTableItem;
    function GetItemsCount: Integer;
    procedure Sort;
  public
    constructor Create;
    destructor Destroy; override;
    procedure addTable(item: TdbTableItem);
    procedure RemoveTable(objId:Integer);
    property Count: Integer read GetItemsCount;
    property Items[idx: Integer]: TdbTableItem read GetItem; default;
    function GetItemById(TableId: Integer): TdbTableItem;
    function GetItemByName(TableName: string): TdbTableItem;
  end;

  TDbDict = class(TObject)
  public
    tables: TdbTables;
    procedure RefreshTables(Qry: TCustomADODataSet);
    procedure RefreshTablesFields(Qry: TCustomADODataSet);
    procedure RefreshTablesUniqueKey(Qry: TCustomADODataSet);
    constructor Create;
    destructor Destroy; override;

    function Serialize:TMemoryStream;
    procedure Deserialize(data: TMemoryStream);
  end;

  PdbFieldValue = ^TdbFieldValue;

  TdbFieldValue = record
    field: TdbFieldItem;
    value: TBytes;
  end;

implementation

uses
  loglog,Types;

{ TDbDict }

constructor TDbDict.Create;
begin
  tables := TdbTables.Create;
end;

destructor TDbDict.Destroy;
begin
  tables.Free;
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
    //删除列不影响排序
    //fSorted := False;
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
  //删除列不影响排序
  //fSorted := False;
end;

constructor TdbTables.Create;
begin
  fSorted := False;
  FItems := TObjectList.Create;
  FItems_s_Name := TStringHash.Create;
end;

destructor TdbTables.Destroy;
begin
  FItems.Free;
  FItems_s_Name.Free;
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

constructor TdbTableItem.Create;
begin
  Fields := TdbFields.Create;
  UniqueClusteredKeys:=TList.Create;
end;


destructor TdbTableItem.Destroy;
begin
  UniqueClusteredKeys.Free;
  Fields.Free;
  inherited;
end;

function TdbTableItem.getFullName: string;
begin
  Result := '[' + Owner + '].[' + TableNmae + ']';
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
  wter.WriteInteger(TableId);
  wter.WriteString(TableNmae);
  wter.WriteString(Owner);
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
    TableId := Rter.ReadInteger;
    TableNmae := Rter.ReadString;
    Owner := Rter.ReadString;
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
end;

function TdbFieldItem.getSafeColName: string;
begin
  Result := '[' + ColName + ']';
end;

function TdbFieldItem.isLogSkipCol: Boolean;
begin
  Result := False;
end;

end.

