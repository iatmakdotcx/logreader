unit SqlDDLs;

interface

uses
  dbDict, System.Classes, System.Contnrs;

type
  TOperationType = (Opt_Insert, Opt_Update, Opt_Delete, Opt_DML);
  //把DML作为DDL的分支，便于统一顺序


type
{$REGION 'Base'}
  TDDLItem = class(TObject)
    OpType: TOperationType;
    xType: string; //v,u,s,d
    function getObjId: Integer; virtual; abstract;
  end;

  TDDLItem_Insert = class(TDDLItem)
    constructor Create;
  end;

  TDDLItem_Delete = class(TDDLItem)
    constructor Create;
    function ParentId: Integer; virtual;
  end;

  TDDLItem_Update = class(TDDLItem)
    constructor Create;
  end;

  TDMLItem = class(TDDLItem)
    data:Pointer;
    constructor Create;
    function getObjId: Integer; override;
  end;
{$ENDREGION 'Base'}

{$REGION 'Insert'}

  TDDL_Create_Table = class(TDDLItem_Insert)
    TableObj: TdbTableItem;
  public
    constructor Create;
    destructor Destroy; override;
    function getObjId: Integer; override;
  end;

  TDDL_Create_View = class(TDDLItem_Insert)
  //TODO:TDDL_Create_View
  end;

  TDDL_Create_Procedure = class(TDDLItem_Insert)
  //TODO:TDDL_Create_View
  end;

  TDDL_Create_Def = class(TDDLItem_Insert)
    objId: Integer;
    objName: string;
    tableid: Integer;
    colid: Integer;
    value: string;
    constructor Create;
    function getObjId: Integer; override;
  end;

{$ENDREGION 'Insert'}

{$REGION 'Delete'}
  TDDL_Delete_Table = class(TDDLItem_Delete)
    objId: Integer;
    objName: string;
    Owner: string;
  public
    constructor Create;
    function getObjId: Integer; override;
  end;

  TDDL_Delete_Def = class(TDDLItem_Delete)
    objId: Integer;
    objName: string;
    tableid: Integer;
    constructor Create;
    function getObjId: Integer; override;
    function ParentId: Integer; override;
  end;

  TDDL_Delete_Column = class(TDDLItem_Delete)
    TableId:Integer;
    objName: string;
    constructor Create;
    function getObjId: Integer; override;
    function ParentId: Integer; override;
  end;
{$ENDREGION 'Delete'}

{$REGION 'Update'}

{$ENDREGION 'Update'}

  TDDLMgr = class(TObject)
    FItems: TObjectList;
  public
    function GetItem(ObjId: Integer): TDDLItem;
    procedure Add(obj: TDDLItem);
    constructor Create;
    destructor Destroy; override;
  end;

  TAllocUnitMgr = class(TObject)
  private
    type
      TAllocUnitMgrItrem = class(TObject)
        AllocId: Int64;
        ObjId: Integer;
      end;
    var
      FItems: TObjectList;
  public
    function AllocIdExists(AllocId: Int64): Boolean;
    function GetObjId(AllocId: Int64): Integer;
    procedure Add(AllocId: Int64; ObjId: Integer);
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TDDLItem_Insert }

constructor TDDLItem_Insert.Create;
begin
  OpType := Opt_Insert;
end;

{ TDDLItem_Delete }

constructor TDDLItem_Delete.Create;
begin
  OpType := Opt_Delete;
end;

function TDDLItem_Delete.ParentId: Integer;
begin
  Result := 0;
end;

{ TDDLItem_Update }

constructor TDDLItem_Update.Create;
begin
  OpType := Opt_Update;
end;


{ TDDL_Create_Table }

constructor TDDL_Create_Table.Create;
begin
  inherited;
  TableObj := TdbTableItem.Create;
  xType := 'u';
end;

destructor TDDL_Create_Table.Destroy;
begin
  TableObj.Free;
  inherited;
end;

function TDDL_Create_Table.getObjId: Integer;
begin
  Result := TableObj.TableId;
end;

{ TDDLMgr }

procedure TDDLMgr.Add(obj: TDDLItem);
begin
  FItems.Add(obj);
end;

constructor TDDLMgr.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TDDLMgr.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TDDLMgr.GetItem(ObjId: Integer): TDDLItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FItems.Count - 1 do
  begin
    if TDDLItem(FItems[I]).getObjId = ObjId then
    begin
      Result := TDDLItem(FItems[I]);
      Exit;
    end;
  end;
end;

{ TAllocUnitMgr }

procedure TAllocUnitMgr.Add(AllocId: Int64; ObjId: Integer);
var
  NewItem: TAllocUnitMgrItrem;
begin
  if not AllocIdExists(AllocId) then
  begin
    NewItem := TAllocUnitMgrItrem.Create;
    NewItem.AllocId := AllocId;
    NewItem.ObjId := ObjId;
    FItems.Add(NewItem);
  end;
end;

function TAllocUnitMgr.AllocIdExists(AllocId: Int64): Boolean;
begin
  Result := GetObjId(AllocId) <> 0;
end;

constructor TAllocUnitMgr.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TAllocUnitMgr.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TAllocUnitMgr.GetObjId(AllocId: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if TAllocUnitMgrItrem(FItems[I]).AllocId = AllocId then
    begin
      Result := TAllocUnitMgrItrem(FItems[I]).ObjId;
      Exit;
    end;
  end;
  Result := 0;
end;

{ TDDL_Create_Def }

constructor TDDL_Create_Def.Create;
begin
  inherited;
  xType := 'd';
end;

function TDDL_Create_Def.getObjId: Integer;
begin
  Result := ObjId;
end;

{ TDDL_Delete_Table }

constructor TDDL_Delete_Table.Create;
begin
  inherited;
  xType := 'u'
end;

function TDDL_Delete_Table.getObjId: Integer;
begin
  Result := ObjId;
end;

{ TDDL_Delete_Def }

constructor TDDL_Delete_Def.Create;
begin
  inherited;
  xType := 'd';
end;

function TDDL_Delete_Def.getObjId: Integer;
begin
  Result := ObjId;
end;

function TDDL_Delete_Def.ParentId: Integer;
begin
  Result := tableid;
end;

{ TDDL_Delete_Column }

constructor TDDL_Delete_Column.Create;
begin
  inherited;
  xType := 'column'
end;

function TDDL_Delete_Column.getObjId: Integer;
begin
  Result := 0;
end;

function TDDL_Delete_Column.ParentId: Integer;
begin
  Result := TableId;
end;

{ TDMLItem }

constructor TDMLItem.Create;
begin
  inherited;
  OpType := Opt_DML;
  data := nil;
end;

function TDMLItem.getObjId: Integer;
begin
  Result := 0;
end;

end.

