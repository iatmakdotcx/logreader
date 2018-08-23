unit p_tblfieldsDisp;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls,
  Data.DB, Data.Win.ADODB;

type
  Tfrm_TblFieldsDisp = class(TForm)
    ListView1: TListView;
    pnl1: TPanel;
    CheckBox1: TCheckBox;
    edt_filter: TEdit;
    ADOQuery1: TADOQuery;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edt_filterKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
  private
    ssl:TStringList;
    procedure RefreshTablelist;
    { Private declarations }
  public
    cfgForm:Tform;
    { Public declarations }
    procedure RefreshTableColumns(aTableName:string);
  end;

var
  frm_TblFieldsDisp: Tfrm_TblFieldsDisp;

implementation
uses
  p_mainCfg;

{$R *.dfm}

{ Tfrm_TblFieldsDisp }

function XML_SafeNodeName(aVal: string): string;
var
  dstmpStr:string;
  I: Integer;
  wcc:Word;
begin
  dstmpStr := '';
  for I := 1 to Length(aVal) do
  begin
    wcc := Word(aVal[I]);
    if (wcc >= 48) and (wcc <= 57) then
    begin
      if I = 1 then
        dstmpStr := '_';
      dstmpStr := dstmpStr + aVal[I];
    end
    else if ((wcc >= 65) and (wcc <= 90)) or ((wcc >= 97) and (wcc <= 122)) or (wcc = 95) or (wcc > 255) then
    begin
      dstmpStr := dstmpStr + aVal[I];
    end
    else
    begin
      dstmpStr := dstmpStr + '_';
    end;
  end;
  Result := dstmpStr;
end;

procedure Tfrm_TblFieldsDisp.CheckBox1Click(Sender: TObject);
begin
  RefreshTablelist;
end;

procedure Tfrm_TblFieldsDisp.edt_filterKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  RefreshTablelist;
end;

procedure Tfrm_TblFieldsDisp.FormCreate(Sender: TObject);
begin
  ssl := TStringList.create;
end;

procedure Tfrm_TblFieldsDisp.FormDestroy(Sender: TObject);
begin
  ssl.free;
end;

procedure Tfrm_TblFieldsDisp.FormShow(Sender: TObject);
begin
  edt_filter.Clear;
  RefreshTablelist;
end;

procedure Tfrm_TblFieldsDisp.ListView1DblClick(Sender: TObject);
begin
  if ListView1.Selected<>nil then
  begin
    Tfrm_mainCfg(cfgForm).fieldlstClick(ListView1.Selected.Caption, ListView1.Selected.SubItems[0]);
  end;
end;

procedure Tfrm_TblFieldsDisp.RefreshTableColumns(aTableName: string);
var
  fieldName,paramName:string;
  I: Integer;
begin
  ADOQuery1.Close;
  ADOQuery1.SQL.Text := 'select name from sys.all_columns where object_id=object_id('''+aTableName+''')';
  ADOQuery1.Open;
  ssl.clear;
  ADOQuery1.first;
  while not ADOQuery1.eof do
  begin
    fieldName := ADOQuery1.fields[0].AsString;
    paramName := XML_SafeNodeName(fieldName);
    if ssl.IndexOfName(paramName) > -1 then
    begin
      for I := 0 to 10000 do
      begin
        if ssl.IndexOfName(paramName + '_' + IntToStr(I)) = -1 then
        begin
          paramName := paramName + '_' + IntToStr(I);
          Break;
        end;
      end;
    end;
    fieldName := '['+fieldName.Replace(']',']]',[rfReplaceAll])+']';
    ssl.Values[paramName] := fieldName;
    ADOQuery1.next;
  end;
  ADOQuery1.Close;
  RefreshTablelist;
end;

procedure Tfrm_TblFieldsDisp.RefreshTablelist;
var
  I: Integer;
begin
  ListView1.Clear;
  if edt_filter.Text='' then
  begin
    //all
    for I := 0 to ssl.Count-1 do
    begin
      with ListView1.Items.Add do
      begin
        Caption := ssl.ValueFromIndex[i];
        if CheckBox1.Checked then
          SubItems.Add('@$'+ssl.Names[i])
        else
          SubItems.Add('@'+ssl.Names[i]);
      end;
    end;
  end else begin
    for I := 0 to ssl.Count-1 do
    begin
      if pos(edt_filter.Text, ssl[i])>0 then
      begin
        with ListView1.Items.Add do
        begin
          Caption := ssl.ValueFromIndex[i];
          if CheckBox1.Checked then
            SubItems.Add('@$'+ssl.Names[i])
          else
            SubItems.Add('@'+ssl.Names[i]);
        end;
      end;
    end;
  end;
end;

end.
