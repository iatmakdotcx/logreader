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
  contextCode in '..\..\contextCode.pas',
  p_structDefine in '..\..\p_structDefine.pas',
  OpCode in '..\..\OpCode.pas',
  Memory_Common in 'H:\Delphi\ͨ�õ��Զ��嵥Ԫ\Memory_Common.pas',
  Winapi.Windows;

const
  STATUS_SUCCESS = $00000000;   //�ɹ�

const
  CurrentPluginVersion = 100;


/// <summary>
/// �����Ϣ
/// </summary>
/// <param name="shortname">����������</param>
/// <returns>��ǰ����汾</returns>
function _Lr_PluginInfo(shortname: PChar): integer; stdcall;
begin
  StrCopy(shortname, 'lr_logView');
  Result := CurrentPluginVersion;
end;

/// <summary>
/// ��ʼ���������
/// </summary>
/// <param name="engineVersion">����ϵͳ�汾</param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginInit(engineVersion: Integer): integer; stdcall;
begin
  OutputDebugString('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
//  frm_logdisplay := Tfrm_logdisplay.Create(nil);
//  frm_logdisplay.Show;
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// �ͷŲ��
/// </summary>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginUnInit(): integer; stdcall;
begin
//  frm_logdisplay.Free;
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// ��ȡ����е�������Ĵ���
/// </summary>
/// <param name="StatusCode">״̬��ʶ</param>
/// <param name="eMsg">״̬��ʶ��������Ϣ</param>
/// <returns></returns>
function _Lr_PluginGetErrMsg(StatusCode: Cardinal; eMsg:PChar ): integer; stdcall;
begin
  if StatusCode = STATUS_SUCCESS then
  begin
    StrCopy(eMsg, '�ɹ�');
  end
  else
  begin
    StrCopy(eMsg, 'δ����Ĵ��󣡣�');
  end;
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// ע���ȡ����Ϣʱ�Ļص�
/// </summary>
/// <param name="lsn"></param>
/// <param name="Raw"></param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginRegLogRowRead(lsn: Plog_LSN; Raw: PMemory_data): integer; stdcall;
begin
  //NotifySubscribe(lsn^, Raw^);
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// ע�� ������ص�
/// </summary>
/// <param name="TransPkg"></param>
/// <returns>״̬��ʶ</returns>
function _Lr_PluginRegTransPkg(TransPkg: PMemory_data): integer; stdcall;
var
  tranId: PTrans_Id;
  RecCount: Integer;
begin
  //////////////////////////////////////////////////////////////////////////
  ///                             bin define
  /// |tranID|rowCount|ÿ�г��ȵ�����|������
  ///   4        2       4*rowCount       x
  ///
  //////////////////////////////////////////////////////////////////////////
  tranId := TransPkg.data;
  RecCount := PWord(UIntPtr(TransPkg.data) + SizeOf(TTrans_Id))^;
  outputdebugString(PChar(Format('tranId:%s, len:%d', [TranId2Str(tranId^), RecCount])));
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// Sql���
/// </summary>
/// <param name="Sql"></param>
/// <returns></returns>
function _Lr_PluginRegSQL(Sql: PChar): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// XML�����¼
/// </summary>
/// <param name="Xml"></param>
/// <returns></returns>
function _Lr_PluginRegXML(Xml: PChar): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

exports
  _Lr_PluginInfo,
  _Lr_PluginInit,
  _Lr_PluginUnInit,
  _Lr_PluginGetErrMsg,
  _Lr_PluginRegTransPkg,
  _Lr_PluginRegLogRowRead,
  _Lr_PluginRegSQL,
  _Lr_PluginRegXML;

begin


end.

