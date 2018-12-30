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
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  System.Contnrs,
  p_mainCfg in 'p_mainCfg.pas' {frm_mainCfg},
  loglog in '..\..\..\Common\loglog.pas',
  p_impl in 'p_impl.pas' {frm_impl},
  Des in 'H:\Delphi\算法\Des.pas',
  pppppp in 'pppppp.pas',
  plgSrcData in '..\..\..\Common\plgSrcData.pas',
  Xml.XMLIntf,
  Xml.XMLDoc,
  System.Variants,
  p_paramStyleHelp in 'p_paramStyleHelp.pas' {frm_paramStyleHelp},
  p_tblfieldsDisp in 'p_tblfieldsDisp.pas' {frm_TblFieldsDisp};

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
  StrCopy(shortname, 'lr_heteroSync');
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

procedure dd(ImplsManger:TImplsManger;XmlStr:string);
var
  Xml: IXMLDocument;
  details, rowNode, OPT: IXMLNode;
  optType, tableName: string;
  I,J:Integer;
  impi: TImplsItem;
begin
  Xml := TXMLDocument.Create(nil);
  Xml.LoadFromXML(XmlStr);
  details := Xml.DocumentElement.ChildNodes['details'];
  for I := 0 to details.ChildNodes.Count-1 do
  begin
    rowNode := details.ChildNodes[i];
    if (rowNode.NodeName = 'row') and rowNode.HasAttribute('type') and (rowNode.Attributes['type'] = 'dml') then
    begin
      OPT := rowNode.ChildNodes['opt'];
      if OPT.HasAttribute('type') then
      begin
        optType := OPT.Attributes['type'];
        tableName := OPT.Attributes['table'];

        for J := 0 to ImplsManger.items.Count-1 do
        begin
          impi := TImplsItem(ImplsManger.items[J]);
          if not impi.Paused then
            impi.RunSql(tableName, optType, OPT);
        end;

      end;
    end;
  end;
end;

/// <summary>
/// Sql语句
/// </summary>
/// <param name="Sql"></param>
/// <returns></returns>
function _Lr_PluginRegXML(source:Pplg_source; Xml: PChar): integer; stdcall;
var
  ImplsManger:TImplsManger;
begin
  //Defloger.add(xml);
  ImplsManger := LrSvrJob.Get(source);
  dd(ImplsManger, Xml);
  Result := STATUS_SUCCESS;
end;

function _Lr_PluginMenu(Xml: PChar): integer; stdcall;
begin
  StrCopy(Xml, '<root><item caption="插件"><item caption="异构同步" actionid="1"></item></item></root>');
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
  ImplsManger:TImplsManger;
begin
  ImplsManger := LrSvrJob.Get(source);
  if ImplsManger.items.Count > 0 then
  begin
    dd := PChar('<root><item caption="异构同步" width="60" align="center">√</item></root>');
  end else begin
    dd := PChar('');
  end;
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
