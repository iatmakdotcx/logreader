//hookdll���󥿩`�ե��`��
unit pageCaptureDllHandler;

interface

uses
  Winapi.Windows;

type
  T_Lc_doHook = function(mRowPtr: UINT_PTR; mColumnsPtr: UINT_PTR): Integer; stdcall;

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
  /// hookdll�Ƿ�����Ч
  /// </summary>
  _Lc_HasBeenHooked: T_Lc_HasBeenHooked;
  /// <summary>
  /// ��ȡ����������
  /// </summary>
  /// <returns></returns>
  _Lc_Get_PaddingData: T_Lc_Get_PaddingData;
  /// <summary>
  /// ���������������
  /// </summary>
  /// <returns></returns>
  _Lc_Get_PaddingDataCnt: T_Lc_Get_PaddingDataCnt;
  /// <summary>
  /// ����Ҫ��������ݿ�id
  /// </summary>
  _Lc_Set_Databases: T_Lc_Set_Databases;
  _Lc_Get_Databases:T_Lc_Get_Databases;
  /// <summary>
  /// �ͷ�PaddingData�еĵ�������
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
  GetModuleFileName(HInstance, buffPath, MAX_PATH);
  dbPath := ExtractFilePath(string(buffPath)) + LcDll;
  dllHandle := loadLibrary(PChar(dbPath));
  if dllHandle <> 0 then
  begin
    _Lc_doHook := GetProcAddress(dllHandle, '_Lc_doHook');
    if not Assigned(_Lc_doHook) then
    begin
      loger.Add(dbPath + '._Lc_doHook ��Ч��');
    end;
    _Lc_unHook := GetProcAddress(dllHandle, '_Lc_unHook');
    if not Assigned(_Lc_unHook) then
    begin
      loger.Add(dbPath + '._Lc_unHook ��Ч��');
    end;
    _Lc_HasBeenHooked := GetProcAddress(dllHandle, '_Lc_HasBeenHooked');
    if not Assigned(_Lc_HasBeenHooked) then
    begin
      loger.Add(dbPath + '._Lc_HasBeenHooked ��Ч��');
    end;
    _Lc_Get_PaddingData := GetProcAddress(dllHandle, '_Lc_Get_PaddingData');
    if not Assigned(_Lc_Get_PaddingData) then
    begin
      loger.Add(dbPath + '._Lc_Get_PaddingData ��Ч��');
    end;
    _Lc_Get_PaddingDataCnt := GetProcAddress(dllHandle, '_Lc_Get_PaddingDataCnt');
    if not Assigned(_Lc_Get_PaddingDataCnt) then
    begin
      loger.Add(dbPath + '._Lc_Get_PaddingDataCnt ��Ч��');
    end;
    _Lc_Set_Databases := GetProcAddress(dllHandle, '_Lc_Set_Databases');
    if not Assigned(_Lc_Set_Databases) then
    begin
      loger.Add(dbPath + '._Lc_Set_Databases ��Ч��');
    end;
    _Lc_Get_Databases := GetProcAddress(dllHandle, '_Lc_Get_Databases');
    if not Assigned(_Lc_Get_Databases) then
    begin
      loger.Add(dbPath + '._Lc_Get_Databases ��Ч��');
    end;
    _Lc_Free_PaddingData := GetProcAddress(dllHandle, '_Lc_Free_PaddingData');
    if not Assigned(_Lc_Free_PaddingData) then
    begin
      loger.Add(dbPath + '._Lc_Free_PaddingData ��Ч��');
    end;
  end;
end;


initialization

finalization
  pageCapture_finit;

end.

