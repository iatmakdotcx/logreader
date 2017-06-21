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


_API_STDCALL int test(void);
_API_STDCALL void domyWork(ULONGLONG eCount, void* eLength, void* eData, void* oldPageData);
_API_STDCALL bool doHook(void);
_API_STDCALL bool doUnHook(void);

_API_STDCALL void SetSavePath(LPCWSTR srvproc);
_API_STDCALL LPCWSTR GetSavePath();

typedef struct LSNItem
{
	LSNItem* p;
	LSNItem* n;

	DWORD LSN_1;
	DWORD LSN_2;
	WORD LSN_3;

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


#pragma pack (push)
#pragma pack (1)

typedef struct logRecdItem
{
	logRecdItem* n;

	DWORD TranID_1;
	WORD TranID_2;
	DWORD LSN_1;
	DWORD LSN_2;
	WORD LSN_3;
	DWORD length;
	void* val;

} *PlogRecdItem;

#pragma pack (pop)