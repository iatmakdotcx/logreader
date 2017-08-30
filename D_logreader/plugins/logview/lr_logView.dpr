library lr_logView;

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
  SysUtils,
  Classes,
  logdisplay in 'logdisplay.pas' {frm_logdisplay},
  p_structDefine in '..\..\p_structDefine.pas',
  contextCode in '..\..\contextCode.pas',
  OpCode in '..\..\OpCode.pas';

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
  shortname := 'lr_logView';
  Result := CurrentPluginVersion;
end;

/// <summary>
/// ��ʼ���������
/// </summary>
/// <param name="engineVersion">����ϵͳ�汾</param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginInit(engineVersion: Integer): integer; stdcall;
begin
  frm_logdisplay := Tfrm_logdisplay.Create(nil);
  frm_logdisplay.Show;
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// �ͷŲ��
/// </summary>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginUnInit(): integer; stdcall;
begin
  frm_logdisplay.Free;
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
/// ע���ȡ����Ϣʱ�Ļص�
/// </summary>
/// <param name="lsn"></param>
/// <param name="Raw"></param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginRegLogRowRead(lsn: Plog_LSN; Raw: PMemory_data): integer; stdcall;
begin
  NotifySubscribe(lsn^, Raw^);
  Result := STATUS_SUCCESS;
end;

exports
  _Lr_PluginInfo,
  _Lr_PluginInit,
  _Lr_PluginUnInit,
  _Lr_PluginGetErrMsg,
  _Lr_PluginRegLogRowRead;

begin

end.

