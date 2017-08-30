unit logdisplay;

interface

uses
  Windows, Messages, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxStyles, cxCustomData, cxFilter, cxData,
  cxDataStorage, cxEdit, cxNavigator, cxGridLevel, cxGridCustomTableView,
  cxGridTableView, cxClasses, cxGridCustomView, Classes, Vcl.Controls,
  cxGrid,vcl.forms, p_structDefine;

type
  Tfrm_logdisplay = class(TForm)
    cxGrid1Level1: TcxGridLevel;
    cxGrid1: TcxGrid;
    cxGrid1TableView1: TcxGridTableView;
    cxGrid1TableView1Column1: TcxGridColumn;
    cxGrid1TableView1Column2: TcxGridColumn;
    cxGrid1TableView1Column3: TcxGridColumn;
    cxGrid1TableView1Column4: TcxGridColumn;
    cxGrid1TableView1Column5: TcxGridColumn;
    cxGrid1TableView1Column6: TcxGridColumn;
    cxGrid1TableView1Column7: TcxGridColumn;
    cxGrid1TableView1Column8: TcxGridColumn;
    cxGrid1TableView1Column9: TcxGridColumn;
    cxGrid1TableView1Column10: TcxGridColumn;
    cxGrid1TableView1Column11: TcxGridColumn;
    cxGrid1TableView1Column12: TcxGridColumn;
    cxGrid1TableView1Column13: TcxGridColumn;
    cxGrid1TableView1Column14: TcxGridColumn;
    cxGrid1TableView1Column15: TcxGridColumn;
  private

    { Private declarations }
  public
    { Public declarations }

  end;

var
  frm_logdisplay: Tfrm_logdisplay;

procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);stdcall;

implementation

uses
  OpCode, contextCode, System.SysUtils;


{$R *.dfm}

procedure NotifySubscribe2(lsn: Tlog_LSN; Raw: TMemory_data);
var
  rl : PRawLog;
begin
  if Raw.dataSize>0 then
  begin
    rl := Raw.data;
    outputdebugstring(PChar(LSN2Str(lsn)+'==>'+inttostr(rl.fixedLen)+'==>'+inttostr(rl.OpCode)));
  end;
end;

procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
var
  rl: PRawLog;
  ridx: Integer;
begin
  if Raw.dataSize > 0 then
  begin
    rl := Raw.data;
    if frm_logdisplay <> nil then
    begin

      with frm_logdisplay.cxGrid1TableView1.DataController do
      begin
        RecordCount := 100;
        ridx := 0;
//        RecordCount := RecordCount + 1;
        Values[ridx, 0] := LSN2Str(lsn);
//        Values[ridx, 1] := OpcodeToStr(rl.OpCode);
//        Values[ridx, 2] := contextCodeToStr(rl.ContextCode);
//        Values[ridx, 3] := TranId2Str(rl.TransID);
//        Values[ridx, 4] := rl.fixedLen;
//        Values[ridx, 5] := Raw.dataSize;
//        Values[ridx, 6] := LSN2Str(rl.PreviousLSN);
//        Values[ridx, 7] := Format('%.4X', [rl.FlagBits]);

        Application.ProcessMessages;
      end;
    end;
  end;
end;

end.

