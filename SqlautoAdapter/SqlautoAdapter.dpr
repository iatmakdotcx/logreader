program SqlautoAdapter;

uses
  Vcl.Forms,
  main in 'main.pas' {frm_main},
  DbgHelp in 'DbgHelp.pas',
  Log4D in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Log4D.pas',
  loglog in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\loglog.pas',
  dbcfg in 'dbcfg.pas' {frm_dbcfg},
  dbhelper in '..\Extdll\dbhelper.pas',
  HashHelper in '..\Common\HashHelper.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(Tfrm_main, frm_main);
  Application.Run;
end.
