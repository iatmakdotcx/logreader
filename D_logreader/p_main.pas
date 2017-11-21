unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Memo1: TMemo;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Button11: TButton;
    Button12: TButton;
    Button13: TButton;
    Button14: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
  private
    { Private declarations }
  public
    logsource: TLogSource;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common, plugins,
  MakCommonfuncs;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
begin
  logsource.Fdbc.refreshDict;
end;

procedure TForm1.Button11Click(Sender: TObject);
begin
  ShowMessage(hexToAnsiiData('0x28283132332929'));
end;

procedure TForm1.Button12Click(Sender: TObject);
begin
  logsource.saveToFile('d:\1.bin');
end;

procedure TForm1.Button13Click(Sender: TObject);
begin
  logsource.loadFromFile('d:\1.bin');
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  frm_dbConnectionCfg := Tfrm_dbConnectionCfg.create(nil);
  try
    if frm_dbConnectionCfg.ShowModal = mrOk then
    begin
      logsource.SetConnection(frm_dbConnectionCfg.databaseConnection);
    end
    else
      frm_dbConnectionCfg.databaseConnection.Free;
  finally
    frm_dbConnectionCfg.free;
  end;
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  oum: TMemory_data;
  mmp: TMemoryStream;
begin
  logsource.cpyFile(2, oum);
  mmp := TMemoryStream.Create;
  mmp.WriteBuffer(oum.data^, oum.dataSize);
  mmp.Seek(0, 0);
  mmp.SaveToFile('d:\2_log.bin');
  mmp.Free;
  FreeMem(oum.data);
end;

procedure TForm1.Button8Click(Sender: TObject);
var
  lsn: Tlog_lsn;
begin
//  lsn.LSN_1 := $1f7;
//  lsn.LSN_2 := $1e8;
//  lsn.LSN_3 := 2;

//  lsn.LSN_1 := $2b;
//  lsn.LSN_2 := $300;
//  lsn.LSN_3 := $0001;

  lsn.LSN_1 := $2b;
  lsn.LSN_2 := $258;
  lsn.LSN_3 := $52;

  logsource.Create_picker(lsn);
end;

procedure TForm1.Button9Click(Sender: TObject);
begin
  logsource.Stop_picker;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  logsource := TLogSource.create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  logsource.Free;
end;

end.

