program logReader;

uses
  FastMM4 in 'H:\Delphi\FastMMnew\FastMM4.pas',
  FastMM4Messages in 'H:\Delphi\FastMMnew\FastMM4Messages.pas',
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
  pluginlog in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\pluginlog.pas',
  MakCommonfuncs in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\MakCommonfuncs.pas',
  Memory_Common in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Memory_Common.pas',
  databaseConnection in 'databaseConnection.pas',
  dbConnectionCfg in 'UI\dbConnectionCfg.pas' {frm_dbConnectionCfg},
  dbHelper in 'dbHelper.pas',
  ConstString in 'ConstString.pas',
  comm_func in 'comm_func.pas',
  MakStrUtils in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\MakStrUtils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
