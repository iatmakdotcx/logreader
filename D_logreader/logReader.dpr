program logReader;

{$R 'res.res' 'res\res.rc'}

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
  //FastMM4Messages in 'H:\Delphi\FastMMnew\FastMM4Messages.pas',
  //FastMM4 in 'H:\Delphi\FastMMnew\FastMM4.pas',
  Forms,
  p_main in 'p_main.pas' {Form1},
  I_logReader in 'logReader\I_logReader.pas',
  Sql2014LogReader in 'logReader\Sql2014LogReader.pas',
  RemoteDbLogProvider in 'LogProvider\RemoteDbLogProvider.pas',
  LdfLogProvider in 'LogProvider\LdfLogProvider.pas',
  I_LogProvider in 'LogProvider\I_LogProvider.pas',
  LogSource in 'LogSource.pas',
  p_structDefine in 'p_structDefine.pas',
  LocalDbLogProvider in 'LogProvider\LocalDbLogProvider.pas',
  MakCommonfuncs in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\MakCommonfuncs.pas',
  Memory_Common in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Memory_Common.pas',
  databaseConnection in 'databaseConnection.pas',
  dbConnectionCfg in 'UI\dbConnectionCfg.pas' {frm_dbConnectionCfg},
  dbHelper in 'dbHelper.pas',
  comm_func in 'comm_func.pas',
  LogtransPkg in 'LogtransPkg.pas',
  OpCode in 'OpCode.pas',
  contextCode in 'contextCode.pas',
  Unit2 in 'tst\Unit2.pas' {Form2},
  plugins in 'plugins.pas',
  I_logAnalyzer in 'LogAnalyzer\I_logAnalyzer.pas',
  Sql2014logAnalyzer in 'LogAnalyzer\Sql2014logAnalyzer.pas',
  LogtransPkgMgr in 'LogtransPkgMgr.pas',
  hexValUtils in 'hexValUtils.pas',
  dbDict in 'dbDict.pas',
  BinDataUtils in 'BinDataUtils.pas',
  dbFieldTypes in 'dbFieldTypes.pas',
  SqlDDLs in 'LogAnalyzer\SqlDDLs.pas',
  Vcl.Dialogs,
  impConfig in 'impConfig.pas',
  ResHelper in 'res\ResHelper.pas',
  sqlextendedprocHelper in 'sqlextendedprocHelper.pas',
  winshellHelper in 'winshellHelper.pas',
  loglog in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\loglog.pas',
  Log4D in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Log4D.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if IsRunningAsAdmin then
  begin
    Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
  end else begin
    showmessage('���롰ʹ�ù���Ա��ݡ����б�����');
  end;
end.
