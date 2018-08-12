program SqlautoAdapter;

uses
  EMemLeaks,
  EResLeaks,
  EDialogWinAPIMSClassic,
  EDialogWinAPIEurekaLogDetailed,
  EDialogWinAPIStepsToReproduce,
  EDebugExports,
  EFixSafeCallException,
  EMapWin32,
  EAppVCL,
  ExceptionLog7,
  Vcl.Forms,
  main in 'main.pas' {frm_main},
  DbgHelp in 'DbgHelp.pas',
  Log4D in 'H:\Delphi\通用的自定义单元\Log4D.pas',
  loglog in 'H:\Delphi\通用的自定义单元\loglog.pas',
  dbcfg in 'dbcfg.pas' {frm_dbcfg},
  dbhelper in '..\Extdll\dbhelper.pas',
  HashHelper in '..\Common\HashHelper.pas',
  p_structDefine in '..\D_logreader\p_structDefine.pas',
  Memory_Common in 'H:\Delphi\通用的自定义单元\Memory_Common.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(Tfrm_main, frm_main);
  Application.Run;
end.
