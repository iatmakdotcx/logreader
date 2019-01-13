unit p_tableview;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, LogSource, cxGraphics,
  cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxStyles, cxCustomData,
  cxFilter, cxData, cxDataStorage, cxEdit, cxNavigator, Data.DB, cxDBData,
  cxGridLevel, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  cxClasses, cxGridCustomView, cxGrid, cxCheckBox, Vcl.Menus;

type
  Tfrm_tableview = class(TForm)
    cxGrid1: TcxGrid;
    cxGrid1Level1: TcxGridLevel;
    cxGrid1TableView1: TcxGridTableView;
    cxGrid1TableView1Column1: TcxGridColumn;
    cxGrid1TableView1Column2: TcxGridColumn;
    cxGrid1TableView1Column3: TcxGridColumn;
    cxGrid1TableView1Column4: TcxGridColumn;
    cxGrid1TableView1Column6: TcxGridColumn;
    cxGrid1TableView1Column7: TcxGridColumn;
    PopupMenu1: TPopupMenu;
    ExportXml1: TMenuItem;
    cxGrid1Level2: TcxGridLevel;
    cxGrid1TableView2: TcxGridTableView;
    cxGrid1TableView2Column1: TcxGridColumn;
    cxGrid1TableView2Column2: TcxGridColumn;
    cxGrid1TableView2Column3: TcxGridColumn;
    cxGrid1TableView2Column4: TcxGridColumn;
    procedure FormShow(Sender: TObject);
    procedure ExportXml1Click(Sender: TObject);
    procedure cxGrid1TableView1DataControllerDetailExpanding(
      ADataController: TcxCustomDataController; ARecordIndex: Integer;
      var AAllow: Boolean);
  private
    LogSource:TLogSource;
    { Private declarations }
  public
    { Public declarations }
    procedure refreshTables;
  end;

var
  frm_tableview: Tfrm_tableview;
  procedure showtables(ls:TLogSource);

implementation

uses
  dbDict;

{$R *.dfm}

procedure showtables(ls: TLogSource);
begin
  frm_tableview := Tfrm_tableview.Create(nil);
  frm_tableview.LogSource := ls;
  frm_tableview.ShowModal;
  frm_tableview.Free;
end;


{ Tfrm_tableview }

procedure Tfrm_tableview.cxGrid1TableView1DataControllerDetailExpanding(
  ADataController: TcxCustomDataController;
  ARecordIndex: Integer; var AAllow: Boolean);
var
  tableid: Integer;
  ti: TdbTableItem;
  I: Integer;
  fi:TdbFieldItem;
  dede:TcxCustomDataController;
begin
  tableid := StrToIntDef(ADataController.GetValue(ARecordIndex, 1), 0);
  if tableid > 0 then
  begin
    ti := LogSource.Fdbc.dict.tables.GetItemById(tableid);
    if ti <> nil then
    begin
      dede := ADataController.GetDetailDataController(ARecordIndex,0);
      dede.BeginUpdate;
      dede.RecordCount := ti.Fields.Count;
      for I := 0 to ti.Fields.Count-1 do
      begin
        fi := ti.Fields[i];
        dede.Values[i,0] := fi.Col_id;
        dede.Values[i,1] := fi.ColName;
        dede.Values[i,2] := fi.getTypeStr;
        dede.Values[i,3] := fi.is_nullable;
      end;
      dede.EndUpdate;
    end;
  end;
end;

procedure Tfrm_tableview.ExportXml1Click(Sender: TObject);
var
  tableid: Integer;
  ti: TdbTableItem;
  ss: TStringList;
  sdlg: TSaveDialog;
begin
  tableid := StrToIntDef(cxGrid1TableView1.DataController.Values[cxGrid1TableView1.DataController.FocusedRowIndex, 1], 0);
  if tableid > 0 then
  begin
    ti := LogSource.Fdbc.dict.tables.GetItemById(tableid);
    if ti <> nil then
    begin
      sdlg := TSaveDialog.Create(nil);
      if sdlg.Execute then
      begin
        ss := TStringList.Create;
        ss.Text := ti.AsXml;
        ss.SaveToFile(sdlg.FileName);
        ss.Free;
      end;
      sdlg.Free;
    end;
  end;
end;

procedure Tfrm_tableview.FormShow(Sender: TObject);
begin
  refreshTables;
end;

procedure Tfrm_tableview.refreshTables;
var
  I: Integer;
  tableItem:TdbTableItem;
  uk:string;
  J: Integer;

begin
  cxGrid1TableView1.BeginUpdate();
   cxGrid1TableView1.DataController.RecordCount := LogSource.Fdbc.dict.tables.Count;
  for I := 0 to LogSource.Fdbc.dict.tables.Count - 1 do
  begin
    tableItem := LogSource.Fdbc.dict.tables[i];
    cxGrid1TableView1.DataController.Values[i,0] := IntToStr(I+1);
    cxGrid1TableView1.DataController.Values[i,1] := IntToStr(tableItem.TableId);
    cxGrid1TableView1.DataController.Values[i,2] := tableItem.Owner;
    cxGrid1TableView1.DataController.Values[i,3] := tableItem.TableNmae;
    cxGrid1TableView1.DataController.Values[i,4] := tableItem.hasIdentity;
    uk := '';
    for J := 0 to tableItem.UniqueClusteredKeys.Count - 1 do
    begin
      if uk = '' then
      begin
        uk := TdbFieldItem(tableItem.UniqueClusteredKeys[J]).ColName;
      end
      else
      begin
        uk := uk + ',' + TdbFieldItem(tableItem.UniqueClusteredKeys[J]).ColName;
      end;
    end;
    cxGrid1TableView1.DataController.Values[i,5] := uk;
  end;
  cxGrid1TableView1.EndUpdate;
end;



end.
