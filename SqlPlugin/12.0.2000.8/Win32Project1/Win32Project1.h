// 下列 ifdef 块是创建使从 DLL 导出更简单的
// 宏的标准方法。此 DLL 中的所有文件都是用命令行上定义的 WIN32PROJECT1_EXPORTS
// 符号编译的。在使用此 DLL 的
// 任何其他项目上不应定义此符号。这样，源文件中包含此文件的任何其他项目都会将
// WIN32PROJECT1_API 函数视为是从 DLL 导入的，而此 DLL 则将用此宏定义的
// 符号视为是被导出的。
#ifdef WIN32PROJECT1_EXPORTS
#define WIN32PROJECT1_API __declspec(dllexport)
#define _API_STDCALL extern "C" _declspec(dllexport)
#else
#define WIN32PROJECT1_API __declspec(dllimport)
#endif


_API_STDCALL void domyWork_2(UINT_PTR XdesRMReadWrite, UINT_PTR rawData);

_API_STDCALL int _Lc_doHook(UINT_PTR mRowPtr);
_API_STDCALL void _Lc_unHook(void);
_API_STDCALL INT64 _Lc_HasBeenHooked(void);
_API_STDCALL PVOID _Lc_Get_PaddingData(void);
_API_STDCALL UINT_PTR _Lc_Get_PaddingDataCnt(void);
_API_STDCALL void _Lc_Set_Databases(INT64 dbId);
_API_STDCALL INT64 _Lc_Get_Databases(void);


void f_initialization();
void f_finalization();

#pragma pack (push)
#pragma pack (1)

typedef struct LSN
{
	DWORD LSN_1;
	DWORD LSN_2;
	WORD LSN_3;
} *PLSN;

typedef struct logRecdItem
{
	logRecdItem* n;

	DWORD TranID_1;
	WORD TranID_2;
	LSN lsn;
	DWORD length;
	WORD dbId;
	void* val;

} *PlogRecdItem;

#pragma pack (pop)

typedef struct LSNItem
{
	LSNItem* p;
	LSNItem* n;

	LSN lsn;

	int length;
	void* val;
} *PLSNItem;

typedef struct TransPkg
{
	TransPkg* p;
	TransPkg* n;

	DWORD TranID_1;
	WORD TranID_2;

	PLSNItem item;
} *PTransPkg;

_API_STDCALL void _Lc_Free_PaddingData(PlogRecdItem logRecd_first);
