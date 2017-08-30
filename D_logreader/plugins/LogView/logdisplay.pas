unit logdisplay;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Graphics, Controls, Forms, Dialogs, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxStyles, cxCustomData, cxFilter, cxData, cxDataStorage,
  cxEdit, cxNavigator, cxGridLevel, cxGridCustomTableView, cxGridTableView,
  cxClasses, cxGridCustomView, cxGrid, p_structDefine, Vcl.Grids,
  cxGridCardView, cxGridCustomLayoutView;

type
  Tfrm_logdisplay = class(TForm)
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
    cxGrid1Level1: TcxGridLevel;
    StringGrid1: TStringGrid;
    cxGrid1CardView1: TcxGridCardView;
    cxGrid1CardView1Row1: TcxGridCardViewRow;
    cxGrid1CardView1Row2: TcxGridCardViewRow;
    cxGrid1CardView1Row3: TcxGridCardViewRow;
    cxGrid1CardView1Row4: TcxGridCardViewRow;
    cxGrid1CardView1Row5: TcxGridCardViewRow;
    cxGrid1CardView1Row6: TcxGridCardViewRow;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frm_logdisplay: Tfrm_logdisplay;

procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data); stdcall;

implementation

uses
  OpCode, contextCode, Memory_Common;


{$R *.dfm}

procedure NotifySubscribe2(lsn: Tlog_LSN; Raw: TMemory_data);
var
  rl: PRawLog;
begin
  if Raw.dataSize > 0 then
  begin
    rl := Raw.data;
    outputdebugstring(PChar(LSN2Str(lsn) + '==>' + inttostr(rl.fixedLen) + '==>' + inttostr(rl.OpCode)));
  end;
end;

procedure NotifySubscribe(lsn: Tlog_LSN; Raw: TMemory_data);
var
  rl: PRawLog;
  ridx: Integer;
  tmpBinStr:string;
begin
  if Raw.dataSize > 0 then
  begin
    rl := Raw.data;
    if frm_logdisplay <> nil then
    begin
      with frm_logdisplay.StringGrid1 do
      begin
        ridx := RowCount - 1;
        RowCount := RowCount + 1;
        Cells[0,ridx] := IntToStr(ridx);
        Cells[1,ridx] := LSN2Str(lsn);
        Cells[2,ridx] := OpcodeToStr(rl.OpCode);
        Cells[3,ridx] := contextCodeToStr(rl.ContextCode);
        Cells[4,ridx] := TranId2Str(rl.TransID);
        Cells[5,ridx] := IntToStr(rl.fixedLen);
        Cells[6,ridx] := IntToStr(Raw.dataSize);
        Cells[7,ridx] := LSN2Str(rl.PreviousLSN);
        Cells[8,ridx] := Format('%.4X', [rl.FlagBits]);
        tmpBinStr := bytestostr(Raw.data, Raw.dataSize, $FFFFFFFF, False, False);
        Cells[9,ridx] := StringReplace(tmpBinStr,' ','',[rfReplaceAll]);
        //Application.ProcessMessages;
      end;
    end;
  end;
end;

procedure NotifySubscribe3(lsn: Tlog_LSN; Raw: TMemory_data);
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
        //Values[ridx, 0] := LSN2Str(lsn);
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

