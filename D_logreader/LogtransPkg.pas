unit LogtransPkg;

interface

uses
  p_structDefine, Contnrs, Classes;

type
  TTransPkgItem = class(TObject)
    LSN: Tlog_LSN;
    Raw: TMemory_data;
    constructor Create(lsn: Tlog_LSN; Raw: TMemory_data);
    destructor Destroy; override;
  end;

  TTransPkg = class(TObject)
  private
    FItems: TObjectList;
  public
    Ftransid: TTrans_Id;
    constructor Create(transid: TTrans_Id);
    destructor Destroy; override;
    procedure addRawLog(log: TTransPkgItem);
    property Items:TObjectList read FItems;
  end;


implementation

{ TTransPkg }

procedure TTransPkg.addRawLog(log: TTransPkgItem);
begin
  FItems.Add(log);
end;

constructor TTransPkg.Create(transid: TTrans_Id);
begin
  FItems := TObjectList.Create;
  Ftransid := transid;
end;

destructor TTransPkg.Destroy;
begin
  FItems.Clear;
  FItems.Free;
  inherited;
end;


{ TTransPkgItem }

constructor TTransPkgItem.Create(lsn: Tlog_LSN; Raw: TMemory_data);
begin
  Self.LSN := lsn;
  Self.Raw := Raw;
end;

destructor TTransPkgItem.Destroy;
begin
  if Raw.data <> nil then
  begin
    FreeMem(Raw.data);
  end;
  inherited;
end;

end.

