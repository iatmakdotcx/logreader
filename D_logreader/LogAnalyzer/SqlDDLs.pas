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
    isSkip:Boolean;
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
    data: Pointer;
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

  TDDL_Create_PrimaryKey = class(TDDLItem_Insert)
    objId: Integer;
    objName: string;
    tableid: Integer;
    colid: Integer;
    value: string;
    isCLUSTERED: Boolean;
    constructor Create;
    function getObjId: Integer; override;
  end;
  TDDL_Create_Column = class(TDDLItem_Insert)
    Table: TdbTableItem;
    field: TdbFieldItem;
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
    TableId: Integer;
    objName: string;
    constructor Create;
    function getObjId: Integer; override;
    function ParentId: Integer; override;
  end;
{$ENDREGION 'Delete'}

{$REGION 'Update'}

{$ENDREGION 'Update'}
  //这个数据在索引之前创建，所以只能先记录，再关联了

  TDDL_Idxs_ColsItem = class(TObject)
    idxId:Integer;
    ColId: Integer;
    orderType: string; //status &0x4 倒叙标志
  end;

  TDDL_Idxs_ColsMgr = class(TObject)
    FItems: TObjectList;
  private
   type
     TDDL_Idxs_ColsItem_id = class(TObject)
        pid: Integer;      //table id
        cols: TObjectList;
        constructor Create;
        destructor Destroy; override;
      end;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(pid, idxId, ColId: Integer; orderDesc: Boolean);
    function GetById(pid: Integer): TObjectList;
  end;

  TDDLMgr = class(TObject)
    FItems: TObjectList;
  public
    function GetItem(ObjId: Integer): TDDLItem;
    procedure Add(obj: TDDLItem);
    constructor Create;
    destructor Destroy; override;
  end;

  TAllocUnitMgr = class(TObject)
    FItems: TObjectList;
  private
    type
      TAllocUnitMgrItrem = class(TObject)
        AllocId: Int64;
        ObjId: Integer;
      end;
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
  if TableObj<>nil then
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

{ TDDL_Create_PrimaryKey }

constructor TDDL_Create_PrimaryKey.Create;
begin
  inherited;
  xType := 'pk';
end;

function TDDL_Create_PrimaryKey.getObjId: Integer;
begin
  Result := ObjId;
end;

{ TDDL_Idxs_ColsMgr }

procedure TDDL_Idxs_ColsMgr.Add(pid, idxId, ColId: Integer; orderDesc: Boolean);
var
  TmpItem: TDDL_Idxs_ColsItem;
  idObj:TDDL_Idxs_ColsItem_id;
  objs:TObjectList;
begin
  objs := GetById(pid);
  if objs = nil then
  begin
    idObj:=TDDL_Idxs_ColsItem_id.Create;
    FItems.Add(idObj);
    idObj.pid:= pid;
    objs := idObj.cols;
  end;
  TmpItem := TDDL_Idxs_ColsItem.Create;
  TmpItem.idxId := idxId;
  TmpItem.ColId := ColId;
  if orderDesc then
    TmpItem.orderType := 'DESC'
  else
    TmpItem.orderType := 'ASC';
  objs.Add(TmpItem);
end;

constructor TDDL_Idxs_ColsMgr.Create;
begin
  FItems := TObjectList.Create;
end;

destructor TDDL_Idxs_ColsMgr.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TDDL_Idxs_ColsMgr.GetById(pid: Integer): TObjectList;
var
  I: Integer;
begin
  for I := 0 to FItems.Count -1 do
  begin
    if TDDL_Idxs_ColsItem_id(FItems[i]).pid=pid then
    begin
      Result := TDDL_Idxs_ColsItem_id(FItems[i]).cols;
      Exit;
    end;
  end;
  Result := nil;
end;

{ TDDL_Idxs_ColsMgr.TDDL_Idxs_ColsItem_id }

constructor TDDL_Idxs_ColsMgr.TDDL_Idxs_ColsItem_id.Create;
begin
  cols := TObjectList.Create;
end;

destructor TDDL_Idxs_ColsMgr.TDDL_Idxs_ColsItem_id.Destroy;
begin
  cols.Free;
  inherited;
end;

{ TDDL_Create_Column }

constructor TDDL_Create_Column.Create;
begin
  inherited;
  xType := 'column'
end;

function TDDL_Create_Column.getObjId: Integer;
begin
  Result := 0;
end;

end.

