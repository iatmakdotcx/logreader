unit p_main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, LogSource;

type
  TForm1 = class(TForm)
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    logsource: TLogSource;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  //logsource.init_LDF('C:\Users\Chin\Desktop\SQlDBG\si_test_log.ldf');
  logsource.init_LDF('C:\Users\Chin\Desktop\dbt_log.ldf');
  //logsource.init_LDF('h:\BPMS_log.LDF');
  //logsource.init_LDF('h:\hh_data_stx0414_1.LDF');
  logsource.listBigLogBlock;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  logsource:= TLogSource.create;
end;

end.
