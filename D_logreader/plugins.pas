unit plugins;

interface

uses
  SysUtils, p_structDefine;

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
    _Lr_PluginRegTransPkg: T_Lr_PluginRegTransPkg;
    _Lr_PluginUnInit:T_Lr_PluginUnInit;
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

    procedure onTransPkgRev(mm:TMemory_data);
  end;

var
  PluginsMgr: TPluginsMgr;

implementation

uses
  Windows, Classes, MakCommonfuncs, pluginlog;

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
  plgName: PChar;
  resV: DWORD;
  I: Integer;
begin
  Result := -1;
  pluginMREW.BeginRead;
  try
    for I := 0 to length(plugins) - 1 do
    begin
      //����Ƿ��Ѿ����ع� �˲��
      if UpperCase(ExtractFileName(dllname)) = UpperCase(plugins[I].dllname) then
      begin
        Result := I;
        Loger.Add('%s ��� %s �Ѽ��ع�.', [dllname, plugins[I].name]);
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
    plgVers := _Lr_PluginInfo(plgName);
    if plgVers > PDK_VERSION then
    begin
      Loger.Add('%s ��� %s �������ڵ�ǰ�汾��SysVers:%d, plgVers:%d', [dllname, strpas(plgName), PDK_VERSION, plgVers]);
      FreeLibrary(dlHandle);
    end
    else
    begin
      Loger.Add('%s ��� %s �Ѽ���.', [dllname, strpas(plgName)]);
      _Lr_PluginGetErrMsg := GetProcAddress(dlHandle, '_Lr_PluginGetErrMsg');
      _Lr_PluginInit := GetProcAddress(dlHandle, '_Lr_PluginInit');
      if Assigned(_Lr_PluginInit) then
      begin
        resV := _Lr_PluginInit(PDK_VERSION);
        if not Succeeded(resV) then
        begin
          if not Assigned(_Lr_PluginGetErrMsg) then
          begin
            Loger.Add('%s ��� %s �Ѽ���.����ʼ��ʧ�ܣ�Code��%d', [dllname, strpas(plgName), resV]);
          end
          else
          begin
            Loger.Add('%s ��� %s �Ѽ���.����ʼ��ʧ�ܣ�Code��%d(%s)', [dllname, strpas(plgName), resV, strpas(_Lr_PluginGetErrMsg(resV))]);
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
        plugins[Result].name := plgName;
        plugins[Result]._Lr_PluginGetErrMsg := _Lr_PluginGetErrMsg;
        plugins[Result]._Lr_PluginRegLogRowRead := GetProcAddress(dlHandle, '_Lr_PluginRegLogRowRead');
        plugins[Result]._Lr_PluginUnInit := GetProcAddress(dlHandle, '_Lr_PluginUnInit');
        plugins[Result]._Lr_PluginRegTransPkg := GetProcAddress(dlHandle, '_Lr_PluginRegTransPkg');
      finally
        pluginMREW.EndWrite;
      end;
    end;
  end;
end;

procedure TPluginsMgr.onTransPkgRev(mm: TMemory_data);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    try
      if Assigned(plugins[i]._Lr_PluginRegTransPkg) then
      begin
        plugins[i]._Lr_PluginRegTransPkg(@mm);
      end;
    except
    end;
  end;
end;

initialization
  PluginsMgr := TPluginsMgr.Create;
  PluginsMgr.load;

finalization
  PluginsMgr.Free;

end.

