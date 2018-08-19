unit plgSrcData;

interface

uses
  Winapi.Windows;


type
  /// <remarks>
  /// 用于给插件传输数据源内容
  /// </remarks>
  Pplg_source = ^Tplg_source;
  Tplg_source = record
     host:PChar;
     user:PChar;
     pass:PChar;
     dbName:PChar;
     dbID: Integer;
     dbVer_Major: Integer;
     dbVer_Minor: Integer;
     dbVer_BuildNumber: Integer;
     dbIs64bit:Boolean;
  end;

type
  T_Lr_PluginInfo = function(var shortname: PChar): integer; stdcall;

  T_Lr_PluginInit = function(engineVersion: Integer): integer; stdcall;

  T_Lr_PluginUnInit = function(): integer; stdcall;

  T_Lr_PluginGetErrMsg = function(StatusCode: Cardinal): PChar; stdcall;

  //T_Lr_PluginRegLogRowRead = function(source:Pplg_source; lsn: Plog_LSN; Raw: PMemory_data): integer; stdcall;
  T_Lr_PluginRegLogRowRead = function(source:Pplg_source; lsn: Pointer; Raw: Pointer): integer; stdcall;

  //T_Lr_PluginRegTransPkg = function(source:Pplg_source; TransPkg: PMemory_data): integer; stdcall;
  T_Lr_PluginRegTransPkg = function(source:Pplg_source; TransPkg: Pointer): integer; stdcall;

  T_Lr_PluginRegSQL = function(source:Pplg_source; Sql: PChar): integer; stdcall;

  T_Lr_PluginRegXML = function(source:Pplg_source; Xml: PChar): integer; stdcall;

  T_Lr_PluginMenu = function(var Xml: PChar): integer; stdcall;
  T_Lr_PluginMenuAction = procedure(source:Pplg_source; actionId: PChar); stdcall;

  T_Lr_PluginMainGridData = function(source:Pplg_source; Xml: PChar): integer; stdcall;

implementation

end.
