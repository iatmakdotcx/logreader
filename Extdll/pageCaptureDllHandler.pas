//hookdllインターフェース
unit pageCaptureDllHandler;

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
  T_Lc_Get_Databases = function:Int64; stdcall;

  T_Lc_Free_PaddingData = procedure(Pnt: Pointer); stdcall;

var
  _Lc_doHook: T_Lc_doHook;
  _Lc_unHook: T_Lc_unHook;
  /// <summary>
  /// hookdll是否已生效
  /// </summary>
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
  _Lc_Get_Databases:T_Lc_Get_Databases;
  /// <summary>
  /// 释放PaddingData中的单个对象
  /// </summary>
  _Lc_Free_PaddingData:T_Lc_Free_PaddingData;

procedure pageCapture_init(LcDll: string);


implementation

uses
  System.SysUtils, pluginlog;

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
  _Lc_Get_Databases := nil;
  _Lc_Free_PaddingData := nil;
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
    if not Assigned(_Lc_doHook) then
    begin
      loger.Add(dbPath + '._Lc_doHook 无效！');
    end;
    _Lc_unHook := GetProcAddress(dllHandle, '_Lc_unHook');
    if not Assigned(_Lc_unHook) then
    begin
      loger.Add(dbPath + '._Lc_unHook 无效！');
    end;
    _Lc_HasBeenHooked := GetProcAddress(dllHandle, '_Lc_HasBeenHooked');
    if not Assigned(_Lc_HasBeenHooked) then
    begin
      loger.Add(dbPath + '._Lc_HasBeenHooked 无效！');
    end;
    _Lc_Get_PaddingData := GetProcAddress(dllHandle, '_Lc_Get_PaddingData');
    if not Assigned(_Lc_Get_PaddingData) then
    begin
      loger.Add(dbPath + '._Lc_Get_PaddingData 无效！');
    end;
    _Lc_Get_PaddingDataCnt := GetProcAddress(dllHandle, '_Lc_Get_PaddingDataCnt');
    if not Assigned(_Lc_Get_PaddingDataCnt) then
    begin
      loger.Add(dbPath + '._Lc_Get_PaddingDataCnt 无效！');
    end;
    _Lc_Set_Databases := GetProcAddress(dllHandle, '_Lc_Set_Databases');
    if not Assigned(_Lc_Set_Databases) then
    begin
      loger.Add(dbPath + '._Lc_Set_Databases 无效！');
    end;
    _Lc_Get_Databases := GetProcAddress(dllHandle, '_Lc_Get_Databases');
    if not Assigned(_Lc_Get_Databases) then
    begin
      loger.Add(dbPath + '._Lc_Get_Databases 无效！');
    end;
    _Lc_Free_PaddingData := GetProcAddress(dllHandle, '_Lc_Free_PaddingData');
    if not Assigned(_Lc_Free_PaddingData) then
    begin
      loger.Add(dbPath + '._Lc_Free_PaddingData 无效！');
    end;
  end;
end;


initialization

finalization
  pageCapture_finit;

end.

