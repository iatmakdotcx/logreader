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
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
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
  dbConnectionCfg, databaseConnection, p_structDefine, Memory_Common, plugins;

{$R *.dfm}

procedure TForm1.Button10Click(Sender: TObject);
begin
  logsource.Fdbc.refreshDict;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  //logsource.init_LDF('C:\Users\Chin\Desktop\SQlDBG\si_test_log.ldf');
//  logsource.init_LDF('C:\Users\Chin\Desktop\dbt_log.ldf');
  //logsource.init_LDF('h:\BPMS_log.LDF');
  //logsource.init_LDF('h:\hh_data_stx0414_1.LDF');
  logsource.listVlfs;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  logsource.init_Process(1952,$D04);
  logsource.listVlfs;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  frm_dbConnectionCfg:= Tfrm_dbConnectionCfg.create(nil);
  try
    if frm_dbConnectionCfg.ShowModal = mrOk then
    begin
      logsource.init(frm_dbConnectionCfg.databaseConnection);
    end else
      frm_dbConnectionCfg.databaseConnection.Free;
  finally
    frm_dbConnectionCfg.free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  logsource.listLogBlock(502);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  logsource.listVlfs;
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  lsn:Tlog_lsn;
  oum:TMemory_data;
begin
  lsn.LSN_1 := 497;
  lsn.LSN_2 := 240;
  lsn.LSN_3 := 2;
  logsource.GetRawLogByLSN(lsn, oum);
  if oum.dataSize>0 then
  begin
    PluginsMgr.Items[0]._Lr_PluginRegLogRowRead(@lsn, @oum);
    Memo1.Text := bytestostr(oum.data, oum.dataSize);
    FreeMem(oum.data);
  end;
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  oum:TMemory_data;
  mmp:TMemoryStream;
begin
  logsource.cpyFile(2,oum);
  mmp:=TMemoryStream.Create;
  mmp.WriteBuffer(oum.data^, oum.dataSize);
  mmp.Seek(0,0);
  mmp.SaveToFile('d:\2_log.bin');
  mmp.Free;
  FreeMem(oum.data);
end;

procedure TForm1.Button8Click(Sender: TObject);
var
  lsn:Tlog_lsn;
begin
//  lsn.LSN_1 := $1f7;
//  lsn.LSN_2 := $1e8;
//  lsn.LSN_3 := 2;

//  lsn.LSN_1 := $28;
//  lsn.LSN_2 := $298;
//  lsn.LSN_3 := $e;

  lsn.LSN_1 := $29;
  lsn.LSN_2 := $f8;
  lsn.LSN_3 := $2;

  logsource.Create_picker(lsn);
end;

procedure TForm1.Button9Click(Sender: TObject);
begin
  logsource.Stop_picker;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  logsource:= TLogSource.create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  logsource.Free;
end;

end.
