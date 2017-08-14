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
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button4Click(Sender: TObject);
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
  dbConnectionCfg, databaseConnection;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  //logsource.init_LDF('C:\Users\Chin\Desktop\SQlDBG\si_test_log.ldf');
  logsource.init_LDF('C:\Users\Chin\Desktop\dbt_log.ldf');
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

procedure TForm1.FormCreate(Sender: TObject);
begin
  logsource:= TLogSource.create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  logsource.Free;
end;

end.
