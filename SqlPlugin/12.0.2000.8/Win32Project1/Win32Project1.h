// ���� ifdef ���Ǵ���ʹ�� DLL �������򵥵�
// ��ı�׼�������� DLL �е������ļ��������������϶���� WIN32PROJECT1_EXPORTS
// ���ű���ġ���ʹ�ô� DLL ��
// �κ�������Ŀ�ϲ�Ӧ����˷��š�������Դ�ļ��а������ļ����κ�������Ŀ���Ὣ
// WIN32PROJECT1_API ������Ϊ�Ǵ� DLL ����ģ����� DLL ���ô˺궨���
// ������Ϊ�Ǳ������ġ�
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