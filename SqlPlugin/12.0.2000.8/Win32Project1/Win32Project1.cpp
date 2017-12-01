// Win32Project1.cpp : ���� DLL Ӧ�ó���ĵ���������
//

#include "stdafx.h"
#include "Win32Project1.h"
#include "aax64.h"
#include "dirUtils.h"
#include <exception>  
#include <time.h> 
#include <process.h>
#include <strsafe.h> 

using namespace std;

ULONGLONG sQlHookPnt = 0;
ULONGLONG sQlHookPntData = 0;
bool hooked = false;
PTransPkg list_TransPkg = NULL;

volatile PlogRecdItem logRecd_first = NULL;
volatile PlogRecdItem logRecd_last = NULL;

// Ŀ¼
LPCWSTR lpPageFilePath = L"C:\\log\\";
//�Ѵ򿪵��ļ����
HANDLE hFile = 0;
//�ٽ���󣬷�ֹ����߳�ͬʱд���ļ�
CRITICAL_SECTION  _critical;

//�����߳��Ƿ���ֹ
volatile int sthde_terminated = 1;
//����log�߳̾��
HANDLE sthde = 0;

#define XP_NOERROR              0
#define XP_ERROR                1
#define MAXCOLNAME				50
#define MAXNAME					25
#define MAXTEXT					255

typedef int (__cdecl *Tsrv_rpcparams)(SRV_PROC*);
typedef int (__cdecl *Tsrv_sendmsg)(SRV_PROC  * srvproc,
	int	        msgtype,
	long int	    msgnum,
	BYTE   msgclass,
	BYTE   state,
	char	  * rpcname,
	int	        rpcnamelen,
	USHORT linenum,
	char	  * message,
	int	        msglen);

typedef int (__cdecl *Tsrv_senddone)(SRV_PROC* srvproc, USHORT status, USHORT curcmd, long int count);
typedef int (__cdecl *Tsrv_describe)(SRV_PROC*, int, char*, int, long int, long int, long int, long int, void*);
typedef int (__cdecl *Tsrv_paraminfo)(SRV_PROC*, int, BYTE*, ULONG*, ULONG*, BYTE*, BOOL*);
typedef int (__cdecl *Tsrv_setcoldata)(SRV_PROC* srvproc, int column, void* data);
typedef int (__cdecl *Tsrv_setcollen)(SRV_PROC* srvproc, int column, int len);

typedef int (__cdecl *Tsrv_sendrow)(SRV_PROC* srvproc);


Tsrv_rpcparams wsrv_rpcparams = NULL;
Tsrv_sendmsg wsrv_sendmsg = NULL;
Tsrv_senddone wsrv_senddone = NULL;
Tsrv_describe wsrv_describe = NULL;
Tsrv_paraminfo wsrv_paraminfo = NULL;
Tsrv_setcoldata wsrv_setcoldata = NULL;
Tsrv_setcollen wsrv_setcollen = NULL;
Tsrv_sendrow wsrv_sendrow = NULL;



void initApiFunc(void) {
	HMODULE hMod = LoadLibrary(L"opends60.dll");//dll·��
	if (!wsrv_sendrow)
	{
		wsrv_rpcparams = (Tsrv_rpcparams)GetProcAddress(hMod, (("srv_rpcparams")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_sendmsg = (Tsrv_sendmsg)GetProcAddress(hMod, (("srv_sendmsg")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_senddone = (Tsrv_senddone)GetProcAddress(hMod, (("srv_senddone")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_describe = (Tsrv_describe)GetProcAddress(hMod, (("srv_describe")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_paraminfo = (Tsrv_paraminfo)GetProcAddress(hMod, (("srv_paraminfo")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_setcoldata = (Tsrv_setcoldata)GetProcAddress(hMod, (("srv_setcoldata")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_setcollen = (Tsrv_setcollen)GetProcAddress(hMod, (("srv_setcollen")));//ֱ��ʹ��ԭ���̺����� 
		wsrv_sendrow = (Tsrv_sendrow)GetProcAddress(hMod, (("srv_sendrow")));//ֱ��ʹ��ԭ���̺����� 
	}
}

RETCODE xp_example(SRV_PROC *srvproc)
{
	DBCHAR spText[MAXTEXT];
	DBCHAR colname[MAXCOLNAME];

	// Check that there are the correct number of parameters.
	if (wsrv_rpcparams(srvproc) != 1)
	{
		// If there is not exactly one parameter, send an error to the client.
		_snprintf_s(spText, MAXTEXT, "ERROR. You need to pass one parameter.");
		wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

		// Signal the client that we are finished.
		wsrv_senddone(srvproc, SRV_DONE_ERROR, (DBUSMALLINT)0, (DBINT)0);

		return XP_ERROR;
	}

	// Define column 1
	_snprintf_s(colname, MAXCOLNAME, "ID");
	wsrv_describe(srvproc, 1, colname, SRV_NULLTERM, SRVINT4, sizeof(DBSMALLINT), SRVINT2, sizeof(DBSMALLINT), 0);

	// Define column 2
	_snprintf_s(colname, MAXCOLNAME, "Hello World");
	wsrv_describe(srvproc, 2, colname, SRV_NULLTERM, SRVCHAR, MAXTEXT, SRVCHAR, 0, NULL);

	BOOL bNull;
	BYTE bType;
	ULONG uLen;
	ULONG uMaxLen;

	// Get the info about the parameter.  
	// Note pass NULL for the pbData parameter to get information rather than the parameter itself.
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, NULL, &bNull);


	// Create some memory to get the parameter in to.
	BYTE* Data = new BYTE[uLen];
	memset(Data, '\0', uLen);

	// Get the parameter
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, Data, &bNull);

	// Convert the parameter into a long from the byte*
	long numRows = (long)*Data;


	// Generate "numRows" output rows.
	for (long i = 1; i <= numRows; i++)
	{
		// Set the first column to be the count.
		wsrv_setcoldata(srvproc, 1, &i);

		// Set the second column to be a text string
		int ColLength = _snprintf_s(spText, MAXTEXT, "Hello from the extended stored procedure. %d", i);
		wsrv_setcoldata(srvproc, 2, spText);
		wsrv_setcollen(srvproc, 2, ColLength);

		// Send the row back to the client
		wsrv_sendrow(srvproc);
	}

	// Tell the client we're done and return the number of rows returned.
	wsrv_senddone(srvproc, SRV_DONE_MORE | SRV_DONE_COUNT, (DBUSMALLINT)0, (DBINT)numRows);

	// Tidy up.
	delete[]Data;

	return XP_NOERROR;
}

int test(void)
{
	initApiFunc();
	return 14;
}

RETCODE SetSavePath(SRV_PROC *srvproc) {
	DBCHAR spText[MAXTEXT];
	if (wsrv_rpcparams(srvproc) != 1)
	{
		// If there is not exactly one parameter, send an error to the client.
		_snprintf_s(spText, MAXTEXT, "ERROR. ������д·��.");
		wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

		// Signal the client that we are finished.
		wsrv_senddone(srvproc, SRV_DONE_FINAL, (DBUSMALLINT)0, (DBINT)0);

		return XP_NOERROR;
	}

	BOOL bNull;
	BYTE bType;
	ULONG uLen;
	ULONG uMaxLen;
	//��ȡ��һ��������Ϣ
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, NULL, &bNull);
	//Ϊ��������ռ�
	BYTE* Data = new BYTE[uLen+2];
	memset(Data, '\0', uLen+2);
	//��ȡ��������
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, Data, &bNull);

	_snprintf_s(spText, MAXTEXT, "·����%s" ,(char*)Data);
	wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

	if (!dirExists((char*)Data)) {
		_snprintf_s(spText, MAXTEXT, "Ŀ¼�����ڻ��޷���Ȩ�ޣ�");
		wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);
		if (!dirCreate((char*)Data)) {
			_snprintf_s(spText, MAXTEXT, "����Ŀ¼ʧ��");
			wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);
			wsrv_senddone(srvproc, SRV_DONE_FINAL, (DBUSMALLINT)0, (DBINT)0);
			delete[]Data;
			return XP_NOERROR;
		}
	}

	int wlen = MultiByteToWideChar(CP_ACP, 0, (char*)Data, -1, NULL, 0);
	wchar_t *w_string = new wchar_t[wlen];
	memset(w_string, 0, sizeof(wchar_t)*wlen);
	MultiByteToWideChar(CP_ACP, 0, (char*)Data, -1, w_string, wlen);

	delete[]lpPageFilePath;
	lpPageFilePath = w_string;

	_snprintf_s(spText, MAXTEXT, "�������");
	wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

	delete[]Data;
	return XP_NOERROR;
}
RETCODE GetSavePath(SRV_PROC *srvproc) {
	DBCHAR spText[MAXTEXT];

	int wlen = WideCharToMultiByte(CP_ACP, 0, lpPageFilePath, -1, NULL, 0, NULL, NULL);
	char *w_string = new char[wlen];
	memset(w_string, 0, wlen);
	WideCharToMultiByte(CP_ACP, 0, lpPageFilePath, -1, w_string, wlen, NULL, NULL);
	
	_snprintf_s(spText, MAXTEXT, w_string);
	wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);
	delete[]w_string;
	return XP_NOERROR;
}


void domyWork(UINT_PTR eCount, UINT_PTR r14, UINT_PTR logHeader, UINT_PTR oldPageData) {
	__try
	{
		if (eCount > 0)
		{
			//r14+460 database id
			//r14+32c lsn

			PLSN lsn = (PLSN)(r14 + 0x32c);

			DWORD TranID_1 = *(DWORD*)(logHeader + 0x10);
			WORD TranID_2 = *(WORD*)(logHeader + 0x14);
			WORD slot = *(WORD*)(logHeader + 0x1E);

			WORD PageSoltCnt = *(WORD*)(oldPageData + 0x16);
			if (slot < PageSoltCnt)
			{
				//��ʼλ��
				UINT_PTR RowDataOffset = oldPageData + *(WORD*)((oldPageData + 0x2000) - ((slot + 1) * 2));
				//����log����
				WORD RowFlag = *(WORD*)RowDataOffset;
				UINT_PTR Endoffset = RowDataOffset + (*(WORD*)(RowDataOffset + 2) & 0x7FFF);				
				if (RowFlag & 0x10)
				{
					//null map
					WORD colCnt = *(WORD*)(Endoffset);
					Endoffset += (colCnt + 7) >> 3;
				}
				Endoffset += 2;
				if (RowFlag & 0x20)
				{
					//variants fields
					WORD varColCnt = *(WORD*)(Endoffset);
					Endoffset += varColCnt * 2;
					Endoffset = RowDataOffset + *(WORD*)(Endoffset);					
				}
				if (RowFlag & 0x40)
				{
					//???
					Endoffset += 0xE;
				}
				
				DWORD RowDatalength = (DWORD)(Endoffset - RowDataOffset);

				BYTE* slotData = new BYTE[RowDatalength];
				memcpy(slotData, (PVOID)RowDataOffset, RowDatalength);

				PlogRecdItem LR = new logRecdItem;
				LR->TranID_1 = TranID_1;
				LR->TranID_2 = TranID_2;
				LR->lsn.LSN_1 = lsn->LSN_1;
				LR->lsn.LSN_2 = lsn->LSN_2;
				LR->lsn.LSN_3 = lsn->LSN_3;

				LR->length = RowDatalength;
				LR->val = slotData;
				LR->n = NULL;

				PlogRecdItem oldLR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_last, LR);
				if (oldLR)
				{
					oldLR->n = LR;
				}
				else {
					logRecd_first = LR;
				}
			}
		
		}
	}
	__except (EXCEPTION_EXECUTE_HANDLER)
	{

	}
}

void getNewFileName(LPWSTR res) {
	time_t timep;
	time(&timep); 
	LPWSTR resT = new WCHAR[512];
	wsprintf(resT, L"m_%d.lgpg", timep);
	wcscpy_s(res, 512, lpPageFilePath);
	int l = lstrlenW(lpPageFilePath);
	wcscat_s(res + l,512 - l, resT);
	delete resT;
}

void closeAndCraeteNewFile() {
	if (hFile != 0)
	{
		CloseHandle(hFile);
	}
	LPWSTR fname = new WCHAR[512];
	getNewFileName(fname);
	hFile = CreateFile(fname, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
	if (hFile == INVALID_HANDLE_VALUE) {
		hFile = 0;
	}
	delete fname;
}

void writeBuffDataToFile(void* data, DWORD length) {
	EnterCriticalSection(&_critical);
	__try
	{
		if (hFile == 0)
		{
			closeAndCraeteNewFile();
		}
		else {
			DWORD fSize = GetFileSize(hFile, NULL);
			if (fSize > 10485760)  //10MB
			{
				closeAndCraeteNewFile();
			}
		}
		if (hFile != 0)
		{
			DWORD wSIZE = 0;
			SetFilePointer(hFile, 0, 0, FILE_END);
			WriteFile(hFile, data, length, &wSIZE, NULL);
		}
	}
	__finally {
		LeaveCriticalSection(&_critical);
	}
}

void PageSave2File(void){
	PlogRecdItem LR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_first, NULL);
	if (LR)
	{
		//�ض�ĩβ
		logRecd_last = NULL;
		BYTE* Tempbuffer = new BYTE[0x2000];//һ��ҳ������ô��
		DWORD Tempbuffer_Posi = 0;
		while (LR)
		{
			//20=sizeof(LR->TranID_1)+sizeof(LR->TranID_2) + sizeof(LR->LSN_1)+sizeof(LR->LSN_2)+sizeof(LR->LSN_3) + sizeof(LR->length)
			//20=4+2 + 4+4+2 + 4
			if (LR->length+20 < (0x2000 - Tempbuffer_Posi))
			{
				//�������㹻
				memcpy(&Tempbuffer[Tempbuffer_Posi], &LR->TranID_1, 20);
				Tempbuffer_Posi += 20;
				memcpy(&Tempbuffer[Tempbuffer_Posi], LR->val, LR->length);
				Tempbuffer_Posi += LR->length;
			}else {
				//����������
				if (Tempbuffer_Posi == 0)
				{
					//����logRecdItem���ݴ���0x2000Ӧ������Ч����
				}
				else {
					//��������С���㣬��д���ļ�һ��					
					writeBuffDataToFile(Tempbuffer, Tempbuffer_Posi); 
					Tempbuffer_Posi = 0;
					continue;
				}
			}
			//�ͷ���ʹ�õĶ���
			PlogRecdItem tmpLR = LR;
			LR = LR->n;
			delete tmpLR->val;
			delete tmpLR;
		}

		if (Tempbuffer_Posi > 0)
		{
			//�����ȡ��ɣ�����������������ݣ�д���ļ�һ��
			writeBuffDataToFile(Tempbuffer, Tempbuffer_Posi);
		}
		delete Tempbuffer;
	}
}

unsigned int __stdcall PageSave2FileThread(LPVOID lpParam) {
	//�߳��˳���־��������ʱ����0��ֹͣ��ʱ����1
	while (!sthde_terminated)
	{
		PageSave2File();
		//ÿ���һ�Σ���ͣ1��
		for (int i = 0; i < 10; i++)
		{
			Sleep(100);
			if (sthde_terminated)
			{
				return 0;
			}
		}
	}
	return 0;
}

void RunTimer() {
	int state = InterlockedExchange((unsigned int*)&sthde_terminated, 0);
	if (state == 0)
	{
		//ԭֵ=0˵���߳��Ѿ�����
	}
	else {
		sthde = (HANDLE)_beginthreadex(NULL, 0, PageSave2FileThread, NULL, 0, NULL);
	}
}
void StopTimer() {
	int state = InterlockedExchange((unsigned int*)&sthde_terminated, 1);
	if (state == 0)
	{
		//�ȴ��߳��˳�
		WaitForSingleObject(sthde, INFINITE);
	}
	else {
		//ԭֵ������0˵���߳��Ѿ�ֹͣ
	}
}

bool doUnHook(void) {
	if (hooked)
	{
		if (sQlHookPnt)
		{
			*(ULONGLONG*)sQlHookPnt = sQlHookPntData;
			sQlHookPnt = 0;
			sQlHookPntData = 0; 
			hooked = false;
			StopTimer();
			DeleteCriticalSection(&_critical);
		}
	}
	return true;
}

bool doHook(void) {
	if (hooked)
	{
		return true;
	}

	//TODO:Ч��sqlmin.dll�汾
	void* sqlminBase = GetModuleHandle(L"sqlmin.dll");	
	if (!sqlminBase)
	{
		return false;
	}
			
	UINT_PTR hookPnt = (UINT_PTR)sqlminBase + 0x5FD30 + 0x5C1;
	UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
	UINT_PTR dwAdr = (UINT_PTR)&hookfuncEnd;
	if (((hookPnt >> 32) & 0xFFFFFFFF) != ((dwAdr >> 32) & 0xFFFFFFFF))
	{
		//����ͬһ����hookʧ�ܣ�
		return false;
	}

	ULONG backPnt = (hookPnt & 0xFFFFFFFF) + 0x6;
	ULONG backPntData = backPnt - (dwAdr & 0xFFFFFFFF) - 5; // jmp code Length
	ULONG hookPntData = (hookfuncPnt & 0xFFFFFFFF) - (hookPnt & 0xFFFFFFFF) - 5; // jmp code Length
	DWORD dwOldP;
	VirtualProtect((LPVOID)dwAdr, 0x10, PAGE_EXECUTE_READWRITE, &dwOldP);
	*(BYTE*)dwAdr = 0xE9;
	dwAdr += 1;
	*(DWORD*)dwAdr = backPntData;

	VirtualProtect((LPVOID)hookPnt, 5, PAGE_EXECUTE_READWRITE, &dwOldP);	
	UINT_PTR interLockData = 0x5D8B9000000000E9L;
	interLockData |= ((UINT_PTR)hookPntData << 8);
	sQlHookPntData = *(UINT_PTR*)hookPnt;
	*(UINT_PTR*)hookPnt = interLockData;

	sQlHookPnt = hookPnt;

	RunTimer();
	InitializeCriticalSection(&_critical);
	hooked = true;
	return true;
}
