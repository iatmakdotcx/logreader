// Win32Project1.cpp : ���� DLL Ӧ�ó���ĵ���������
//

#include "stdafx.h"
#include "Win32Project1.h"
#include "aax64.h"
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
volatile LONG PaddingDataCnt = 0;

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

//Ҫ��������ݿ�id
INT64 CdbId = 0;


void domyWork(UINT_PTR eCount, UINT_PTR r14, UINT_PTR logHeader, UINT_PTR oldPageData) {
	__try
	{
		if (eCount > 0)
		{
			//r14+460 database id
			//r14+32c lsn

			WORD dbid = *(WORD*)(r14 + 0x460);
			if (dbid > 0 && dbid < 64 && (((INT64)1 << (dbid - 1)) & CdbId))
			{
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
					LR->dbId = dbid;

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
					InterlockedAdd(&PaddingDataCnt, 1);	
					if (PaddingDataCnt > 10000)
					{
						if (PaddingDataCnt % 1000 == 0)
						{
							PageSave2File();
						}
					}
				}
			}
		}
	}
	__except (EXCEPTION_EXECUTE_HANDLER)
	{

	}
}

PVOID _Lc_Get_PaddingData(void) {
	PlogRecdItem LR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_first, NULL);
	if (LR)
	{
		//�ض�ĩβ
		logRecd_last = NULL;
		PaddingDataCnt = 0;
		return LR;
	}
	return NULL;
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
		PaddingDataCnt = 0;
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

void _Lc_unHook(void) {
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

void _Lc_doHook2(UINT_PTR HookPnt) {
	if (hooked)
	{
		return;
	}

	//TODO:Ч��sqlmin.dll�汾
	void* sqlminBase = GetModuleHandle(L"sqlmin.dll");	
	if (!sqlminBase)
	{
		return;
	}
			
	UINT_PTR hookPnt = (UINT_PTR)sqlminBase + 0x5FD30 + 0x5C1;
	UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
	UINT_PTR dwAdr = (UINT_PTR)&hookfuncEnd;
	if (((hookPnt >> 32) & 0xFFFFFFFF) != ((dwAdr >> 32) & 0xFFFFFFFF))
	{
		//����ͬһ����hookʧ�ܣ�
		return;
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
}

int _Lc_doHook(UINT_PTR HookPnt) {
	if (sQlHookPnt)
	{
		return 1;
	}	
	//TODO:Ч��sqlmin.dll�汾
	void* sqlminBase = GetModuleHandle(L"sqlmin.dll");
	if (!sqlminBase)
	{
		return 2;
	}
	//���ǰ�󼸸��ֽ��Ƿ���Ч
	UINT_PTR testHookPnt = HookPnt - 3;
	if (IsBadReadPtr((void*)testHookPnt, 0x10)) {
		return 3;
	}
	//�������Ƿ���ȷ
	if (*(INT64*)testHookPnt != 0x0001a090ffce8b49L || 
		*(INT64*)(testHookPnt+8) != 0x786d8b44185d8b00L) {
		return 4;
	}
	//UINT_PTR hookPnt = (UINT_PTR)sqlminBase + 0x5FD30 + 0x5C1;
	UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
	UINT_PTR dwAdr = (UINT_PTR)&hookfuncEnd;
	if (((sQlHookPnt >> 32) & 0xFFFFFFFF) != ((dwAdr >> 32) & 0xFFFFFFFF))
	{
		//����ͬһ����hookʧ�ܣ�
		return 5;
	}
	sQlHookPnt = HookPnt;

	ULONG backPnt = (sQlHookPnt & 0xFFFFFFFF) + 0x6;
	ULONG backPntData = backPnt - (dwAdr & 0xFFFFFFFF) - 5; // jmp code Length
	ULONG hookPntData = (hookfuncPnt & 0xFFFFFFFF) - (sQlHookPnt & 0xFFFFFFFF) - 5; // jmp code Length
	DWORD dwOldP;
	VirtualProtect((LPVOID)dwAdr, 0x10, PAGE_EXECUTE_READWRITE, &dwOldP);
	*(BYTE*)dwAdr = 0xE9;
	dwAdr += 1;
	*(DWORD*)dwAdr = backPntData;

	VirtualProtect((LPVOID)sQlHookPnt, 5, PAGE_EXECUTE_READWRITE, &dwOldP);
	UINT_PTR interLockData = 0x5D8B9000000000E9L;
	interLockData |= ((UINT_PTR)hookPntData << 8);
	sQlHookPntData = *(UINT_PTR*)sQlHookPnt;
	*(UINT_PTR*)sQlHookPnt = interLockData;

	//RunTimer();
	InitializeCriticalSection(&_critical);
	hooked = true;
	return 0;
}


INT64 _Lc_HasBeenHooked(void) {
	return sQlHookPnt;
}

UINT_PTR _Lc_Get_PaddingDataCnt(void) {
	return (INT64)PaddingDataCnt;
}

void _Lc_Set_Databases(INT64 dbId) {
	CdbId = dbId;
}