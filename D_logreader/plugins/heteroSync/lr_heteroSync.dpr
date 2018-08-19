library lr_heteroSync;
//program lr_heteroSync;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

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
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  p_mainCfg in 'p_mainCfg.pas' {frm_mainCfg},
  Log4D in '..\..\..\Common\Log4D.pas',
  loglog in '..\..\..\Common\loglog.pas',
  p_impl in 'p_impl.pas' {frm_impl},
  dbcfg in 'dbcfg.pas' {frm_dbcfg},
  Des in 'H:\Delphi\�㷨\Des.pas',
  pppppp in 'pppppp.pas',
  plgSrcData in '..\..\..\Common\plgSrcData.pas';

const
  STATUS_SUCCESS = $00000000;   //�ɹ�

const
  CurrentPluginVersion = 100;


/// <summary>
/// �����Ϣ
/// </summary>
/// <param name="shortname">����������</param>
/// <returns>��ǰ����汾</returns>
function _Lr_PluginInfo(var shortname: PChar): integer; stdcall;
begin
  shortname := 'lr_heteroSync';
  Result := CurrentPluginVersion;
end;

/// <summary>
/// ��ʼ���������
/// </summary>
/// <param name="engineVersion">����ϵͳ�汾</param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginInit(engineVersion: Integer): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// �ͷŲ��
/// </summary>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginUnInit(): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// ��ȡ����е�������Ĵ���
/// </summary>
/// <param name="engineVersion">״̬��ʶ</param>
/// <returns>״̬��ʶ��������Ϣ</returns>
function _Lr_PluginGetErrMsg(StatusCode: Cardinal): PChar; stdcall;
begin
  if StatusCode = STATUS_SUCCESS then
  begin
    Result := '�ɹ�'
  end
  else
  begin
    Result := 'δ����Ĵ��󣡣�'
  end;
end;

/// <summary>
/// Sql���
/// </summary>
/// <param name="Sql"></param>
/// <returns></returns>
function _Lr_PluginRegXML(source:Pplg_source; Xml: PChar): integer; stdcall;
begin

  Result := STATUS_SUCCESS;
end;

function _Lr_PluginMenu(var Xml: PChar): integer; stdcall;
begin
  Xml := '<root><item caption="���"><item caption="�칹ͬ��"><item caption="���ݿ�����" actionid="1"></item></item></item></root>';
  Result := STATUS_SUCCESS;
end;

procedure _Lr_PluginMenuAction(source:Pplg_source; actionId: PChar); stdcall;
begin
  if actionId = '1' then
  begin
    frm_impl := Tfrm_impl.Create(nil);
    try
      frm_impl.source := source;
      frm_impl.ShowModal;
    finally
      frm_impl.Free;
    end;
  end;
end;

function _Lr_PluginMainGridData(source:Pplg_source; Xml: PChar): integer; stdcall;
var
  dd:string;
begin
  dd := PChar('<root><item caption="�칹ͬ��">'+inttostr(Random(10000))+'</item></root>');
  StrCopy(Xml, PChar(dd));
  Result := STATUS_SUCCESS;
end;

exports
  _Lr_PluginInfo,
  _Lr_PluginInit,
  _Lr_PluginUnInit,
  _Lr_PluginGetErrMsg,
  _Lr_PluginRegXML,
  _Lr_PluginMenuAction,
  _Lr_PluginMenu,
  _Lr_PluginMainGridData;

{$R *.res}

begin
//  Application.Initialize;
//  Application.MainFormOnTaskbar := True;
//  Application.CreateForm(Tfrm_impl, frm_impl);
//  Application.Run;
end.
