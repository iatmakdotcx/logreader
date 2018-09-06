library lr_fullSync;

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
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  dbhelper in 'dbhelper.pas',
  Des in 'H:\Delphi\算法\Des.pas',
  cfgForm in 'cfgForm.pas' {frm_cfg},
  plgSrcData in '..\..\..\Common\plgSrcData.pas',
  Log4D in '..\..\..\Common\Log4D.pas',
  loglog in '..\..\..\Common\loglog.pas';

const
  STATUS_SUCCESS = $00000000;   //成功

const
  CurrentPluginVersion = 100;


/// <summary>
/// 插件信息
/// </summary>
/// <param name="shortname">输出插件名称</param>
/// <returns>当前插件版本</returns>
function _Lr_PluginInfo(shortname: PChar): integer; stdcall;
begin
  StrCopy(shortname, 'lr_fullSync');
  Result := CurrentPluginVersion;
end;

/// <summary>
/// 初始化插件调用
/// </summary>
/// <param name="engineVersion">调用系统版本</param>
/// <returns>状态标识</returns>
function _Lr_PluginInit(engineVersion: Integer): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// 释放插件
/// </summary>
/// <returns>状态标识</returns>
function _Lr_PluginUnInit(): integer; stdcall;
begin
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// 获取插件中单独定义的错误
/// </summary>
/// <param name="StatusCode">状态标识</param>
/// <param name="eMsg">状态标识的描述信息</param>
/// <returns></returns>
function _Lr_PluginGetErrMsg(StatusCode: Cardinal; eMsg:PChar ): integer; stdcall;
begin
  if StatusCode = STATUS_SUCCESS then
  begin
    StrCopy(eMsg, '成功');
  end
  else
  begin
    StrCopy(eMsg, '未定义的错误！！');
  end;
  Result := STATUS_SUCCESS;
end;

/// <summary>
/// Sql语句
/// </summary>
/// <param name="Sql"></param>
/// <returns></returns>
function _Lr_PluginRegSQL(source:Pplg_source; Sql: PChar): integer; stdcall;
begin
  RunSql(source.dbID, Sql);
  Result := STATUS_SUCCESS;
end;

function _Lr_PluginMenu(Xml: PChar): integer; stdcall;
begin
  StrCopy(Xml, '<root><item caption="插件"><item caption="全库同步"><item caption="数据库设置" actionid="1"></item></item></item></root>');
  Result := STATUS_SUCCESS;
end;

procedure _Lr_PluginMenuAction(source:Pplg_source; actionId: PChar); stdcall;
begin
  if actionId = '1' then
  begin
    frm_cfg := Tfrm_cfg.Create(nil);
    frm_cfg.source := source;
    frm_cfg.ShowModal;
    frm_cfg.Free;
  end;
end;

function _Lr_PluginMainGridData(source:Pplg_source; Xml: PChar): integer; stdcall;
var
  dd:string;
begin
  if TransEnable[source.dbid] then
  begin
    dd := PChar('<root><item caption="整库同步">√</item></root>');
  end else begin
    dd := PChar('');
  end;
  StrCopy(Xml, PChar(dd));
  Result := STATUS_SUCCESS;
end;

{$R *.res}

exports
  _Lr_PluginInfo,
  _Lr_PluginInit,
  _Lr_PluginUnInit,
  _Lr_PluginGetErrMsg,
  _Lr_PluginRegSQL,
  _Lr_PluginMenuAction,
  _Lr_PluginMenu,
  _Lr_PluginMainGridData;

begin



end.
