//此单元用于注入sqlserver进程捕获update的log
unit pageCapture;

interface

uses
  Winapi.Windows;

type
  T_Lc_doHook = function(HookPnt: UINT_PTR): Integer; stdcall;

  T_Lc_unHook = procedure(); stdcall;

  T_Lc_HasBeenHooked = function: UINT_PTR; stdcall;

  T_Lc_Get_PaddingData = function: Pointer; stdcall;

  T_Lc_Get_PaddingDataCnt = function: Int64; stdcall;

  T_Lc_Set_Databases = procedure(databaseId: Int64); stdcall;

var
  _Lc_doHook: T_Lc_doHook;
  _Lc_unHook: T_Lc_unHook;
  _Lc_HasBeenHooked: T_Lc_HasBeenHooked;
  /// <summary>
  /// 获取待保存数据
  /// </summary>
  /// <returns></returns>
  _Lc_Get_PaddingData: T_Lc_Get_PaddingData;
  /// <summary>
  /// 待保存的数据总数
  /// </summary>
  /// <returns></returns>
  _Lc_Get_PaddingDataCnt: T_Lc_Get_PaddingDataCnt;
  /// <summary>
  /// 设置要捕获的数据库id
  /// </summary>
  _Lc_Set_Databases: T_Lc_Set_Databases;

procedure pageCapture_init(LcDll: string);

procedure pageCapture_finit();



implementation

uses
  System.SysUtils;

var
  dllHandle: THandle = 0;

procedure pageCapture_finit();
begin
  if dllHandle <> 0 then
  begin
    FreeLibrary(dllHandle);
  end;
  _Lc_doHook := nil;
  _Lc_unHook := nil;
  _Lc_HasBeenHooked := nil;
  _Lc_Get_PaddingData := nil;
  _Lc_Get_PaddingDataCnt := nil;
  _Lc_Set_Databases := nil;
end;

procedure pageCapture_init(LcDll: string);
var
  buffPath: array[0..MAX_PATH + 2] of Char;
  dbPath: string;
begin
  pageCapture_finit();
  GetModuleFileName(HInstance, buffPath, MAX_PATH);
  dbPath := ExtractFilePath(string(buffPath)) + LcDll;
  dllHandle := loadLibrary(PChar(dbPath));
  if dllHandle <> 0 then
  begin
    _Lc_doHook := GetProcAddress(dllHandle, '_Lc_doHook');
    _Lc_unHook := GetProcAddress(dllHandle, '_Lc_unHook');
    _Lc_HasBeenHooked := GetProcAddress(dllHandle, '_Lc_HasBeenHooked');
    _Lc_Get_PaddingData := GetProcAddress(dllHandle, '_Lc_Get_PaddingData');
    _Lc_Get_PaddingDataCnt := GetProcAddress(dllHandle, '_Lc_Get_PaddingDataCnt');
    _Lc_Set_Databases := GetProcAddress(dllHandle, '_Lc_Set_Databases');
  end;
end;


end.

