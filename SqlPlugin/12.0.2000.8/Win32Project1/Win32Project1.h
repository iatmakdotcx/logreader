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


_API_STDCALL void domyWork(UINT_PTR eCount, UINT_PTR r14, UINT_PTR logHeader, UINT_PTR oldPageData);
_API_STDCALL int _Lc_doHook(UINT_PTR HookPnt);
_API_STDCALL void _Lc_unHook(void);
_API_STDCALL INT64 _Lc_HasBeenHooked(void);
_API_STDCALL PVOID _Lc_Get_PaddingData(void);
_API_STDCALL UINT_PTR _Lc_Get_PaddingDataCnt(void);
_API_STDCALL void _Lc_Set_Databases(INT64 dbId);
_API_STDCALL void PageSave2File(void);


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


