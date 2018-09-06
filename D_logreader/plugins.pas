unit plugins;

interface

uses
  SysUtils, p_structDefine, plgSrcData;

const
  PDK_VERSION = 100;

type
  TPluginItem = record
    dllname: string;
    filepath: string;
    hmodule: thandle;
    name: string;
    pluginversion: integer;
    enabled: boolean;
    nextid: integer;
    _Lr_PluginGetErrMsg: T_Lr_PluginGetErrMsg;
    _Lr_PluginRegLogRowRead: T_Lr_PluginRegLogRowRead;
    _Lr_PluginRegTransPkg:T_Lr_PluginRegTransPkg;
    _Lr_PluginRegSQL:T_Lr_PluginRegSQL;
    _Lr_PluginRegXML:T_Lr_PluginRegXML;
    _Lr_PluginUnInit:T_Lr_PluginUnInit;
    _Lr_PluginMenu:T_Lr_PluginMenu;
    _Lr_PluginMenuAction:T_Lr_PluginMenuAction;
    _Lr_PluginMainGridData:T_Lr_PluginMainGridData;
  end;

type
  TPluginsMgr = class
  private
    fP_path: string;
    pluginMREW: TMultiReadExclusiveWriteSynchronizer;
    plugins: array of TPluginItem;
    function Getplugin(pluginid: integer): TPluginItem;

  public
    constructor Create;
    destructor Destroy; override;
    procedure load();
    function LoadPlugin(dllname: string): integer;
    property Items[pluginid: Integer]: TPluginItem read Getplugin; default;
    function Count: Integer;

    procedure onTransPkgRev(source:Pplg_source; mm:TMemory_data);
    procedure onTranSql(source:Pplg_source;data:string);
    procedure onTransXml(source:Pplg_source;data:string);
  end;

var
  PluginsMgr: TPluginsMgr;

implementation

uses
  Windows, Classes, MakCommonfuncs, loglog;

const
  PluginsPath = 'plugins';

{ TPluginsMgr }

function TPluginsMgr.Count: Integer;
begin
  Result := Length(plugins);
end;

constructor TPluginsMgr.Create;
var
  S: array[0..255] of char;
begin
  GetModuleFileName(HInstance, S, 255);
  fP_path := ExtractFilePath(StringReplace(trim(S), '\\?\', '', [])) + PluginsPath;

  pluginMREW := TMultiReadExclusiveWriteSynchronizer.Create;
end;

destructor TPluginsMgr.Destroy;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    if Assigned(plugins[i]._Lr_PluginUnInit) then
    begin
      plugins[i]._Lr_PluginUnInit;
    end;
  end;
  pluginMREW.Free;
  inherited;
end;

function TPluginsMgr.Getplugin(pluginid: integer): TPluginItem;
begin
  result := plugins[pluginid];
end;

procedure TPluginsMgr.load;
var
  dllList: TStringList;
  I: Integer;
begin
  dllList := searchAllFile(fP_path + '\*.dll');
  try
    for I := 0 to dllList.Count - 1 do
    begin
      LoadPlugin(dllList[I]);
    end;
  finally
    dllList.Free;
  end;
end;

function TPluginsMgr.LoadPlugin(dllname: string): integer;
var
  _Lr_PluginInfo: T_Lr_PluginInfo;
  _Lr_PluginInit: T_Lr_PluginInit;
  _Lr_PluginGetErrMsg: T_Lr_PluginGetErrMsg;
  dlHandle: THandle;
  plgVers: Integer;
  plgBuf: PChar;
  plgNameStr:string;
  resV: DWORD;
  I: Integer;
begin
  Result := -1;
  pluginMREW.BeginRead;
  try
    for I := 0 to length(plugins) - 1 do
    begin
      //检查是否已经加载过 此插件
      if UpperCase(ExtractFileName(dllname)) = UpperCase(plugins[I].dllname) then
      begin
        Result := I;
        Loger.Add('%s 插件 %s 已加载过.', [dllname, plugins[I].name]);
        exit;
      end;
    end;
  finally
    pluginMREW.EndRead;
  end;

  dlHandle := LoadLibrary(PChar(dllname));
  if dlHandle <> 0 then
  begin
    _Lr_PluginInfo := GetProcAddress(dlHandle, '_Lr_PluginInfo');
    if not Assigned(_Lr_PluginInfo) then
    begin
      FreeLibrary(dlHandle);
      Exit;
    end;
    plgBuf := GetMemory($1000);
    plgVers := _Lr_PluginInfo(plgBuf);
    plgNameStr := string(plgBuf);
    FreeMem(plgBuf);
    if plgVers > PDK_VERSION then
    begin
      Loger.Add('%s 插件 %s 不适用于当前版本。SysVers:%d, plgVers:%d', [dllname, plgNameStr, PDK_VERSION, plgVers]);
      FreeLibrary(dlHandle);
    end
    else
    begin
      Loger.Add('%s 插件 %s 已加载.', [dllname, plgNameStr]);
      _Lr_PluginGetErrMsg := GetProcAddress(dlHandle, '_Lr_PluginGetErrMsg');
      _Lr_PluginInit := GetProcAddress(dlHandle, '_Lr_PluginInit');
      if Assigned(_Lr_PluginInit) then
      begin
        resV := _Lr_PluginInit(PDK_VERSION);
        if not Succeeded(resV) then
        begin
          if not Assigned(_Lr_PluginGetErrMsg) then
          begin
            Loger.Add('%s 插件 %s 已加载.但初始化失败！Code：%d', [dllname, plgNameStr, resV]);
          end
          else
          begin
            plgBuf := GetMemory($1000);
            _Lr_PluginGetErrMsg(resV, plgBuf);
            Loger.Add('%s 插件 %s 已加载.但初始化失败！Code：%d(%s)', [dllname, plgNameStr, resV, string(plgBuf)]);
            FreeMem(plgBuf);
          end;
          FreeLibrary(dlHandle);
        end;
      end;

      pluginMREW.BeginWrite;
      try
        Result := length(plugins);
        setlength(plugins, Result + 1);
        plugins[Result].pluginversion := plgVers;
        plugins[Result].dllname := ExtractFileName(dllname);
        plugins[Result].filepath := dllname;
        plugins[Result].hmodule := dlHandle;
        plugins[Result].name := plgNameStr;
        plugins[Result]._Lr_PluginGetErrMsg := _Lr_PluginGetErrMsg;
        plugins[Result]._Lr_PluginRegLogRowRead := GetProcAddress(dlHandle, '_Lr_PluginRegLogRowRead');
        plugins[Result]._Lr_PluginUnInit := GetProcAddress(dlHandle, '_Lr_PluginUnInit');
        plugins[Result]._Lr_PluginRegTransPkg := GetProcAddress(dlHandle, '_Lr_PluginRegTransPkg');
        //解析内容
        plugins[Result]._Lr_PluginRegSQL := GetProcAddress(dlHandle, '_Lr_PluginRegSQL');
        plugins[Result]._Lr_PluginRegXML := GetProcAddress(dlHandle, '_Lr_PluginRegXML');
        //菜单
        plugins[Result]._Lr_PluginMenu := GetProcAddress(dlHandle, '_Lr_PluginMenu');
        plugins[Result]._Lr_PluginMenuAction := GetProcAddress(dlHandle, '_Lr_PluginMenuAction');
        //主表格
        plugins[Result]._Lr_PluginMainGridData := GetProcAddress(dlHandle, '_Lr_PluginMainGridData');
      finally
        pluginMREW.EndWrite;
      end;
    end;
  end;
end;

procedure TPluginsMgr.onTransPkgRev(source:Pplg_source; mm: TMemory_data);
var
  I: Integer;
begin
  pluginMREW.BeginRead;
  try
    for I := 0 to Count - 1 do
    begin
      try
        if Assigned(plugins[i]._Lr_PluginRegTransPkg) then
        begin
          plugins[i]._Lr_PluginRegTransPkg(source, @mm);
        end;
      except
      end;
    end;
  finally
    pluginMREW.EndRead;
  end;
end;

procedure TPluginsMgr.onTranSql(source:Pplg_source;data:string);
var
  I: Integer;
  begt:Cardinal;
begin
  pluginMREW.BeginRead;
  try
    for I := 0 to Count - 1 do
    begin
      try
        if Assigned(plugins[i]._Lr_PluginRegSQL) then
        begin
          try
            begt := GetTickCount;
            plugins[i]._Lr_PluginRegSQL(source, PChar(data));
            begt := GetTickCount-begt;
            if begt > 1000 then
            begin
              loger.Add('插件 %s._Lr_PluginRegSQL 执行时间大于1000ms(%d ms)(响应过慢可能导致整体解析效率下降！)',[plugins[i].filepath, begt], LOG_IMPORTANT or LOG_WARNING);
            end;
          except
          end;
        end;
      except
      end;
    end;
  finally
    pluginMREW.EndRead;
  end;
end;

procedure TPluginsMgr.onTransXml(source:Pplg_source;data:string);
var
  I: Integer;
  begt:Cardinal;
begin
  pluginMREW.BeginRead;
  try
    for I := 0 to Count - 1 do
    begin
      try
        if Assigned(plugins[i]._Lr_PluginRegXML) then
        begin
          try
            begt := GetTickCount;
            plugins[I]._Lr_PluginRegXML(source, PChar(data));
            begt := GetTickCount-begt;
            if begt > 1000 then
            begin
              loger.Add('插件 %s._Lr_PluginRegXML 执行时间大于1000ms(%d ms)(响应过慢可能导致整体解析效率下降！)',[plugins[i].filepath, begt], LOG_IMPORTANT or LOG_WARNING);
            end;
          except
          end;
        end;
      except
      end;
    end;
  finally
    pluginMREW.EndRead;
  end;
end;

initialization
  PluginsMgr := TPluginsMgr.Create;
  PluginsMgr.load;

finalization
  PluginsMgr.Free;

end.

