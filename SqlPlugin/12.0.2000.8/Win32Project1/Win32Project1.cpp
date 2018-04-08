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

//�ٽ���󣬷�ֹ����߳�ͬʱд���ļ�
CRITICAL_SECTION  _critical;

//Ҫ��������ݿ�id
INT64 CdbId = 0;


void f_initialization() {
	InitializeCriticalSection(&_critical);
}

void f_finalization() {
	_Lc_unHook();
	DeleteCriticalSection(&_critical);
}

void domyWork(UINT_PTR eCount, UINT_PTR r14, UINT_PTR logHeader, UINT_PTR oldPageData) {
	__try
	{
		//10w����δ�����Ͳ���¼����Ķ����ˣ����ƶ�����
		if (eCount > 0 && PaddingDataCnt < 100000)
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

void _Lc_unHook(void) {
	EnterCriticalSection(&_critical);
	if (sQlHookPnt)
	{
		//��ԭhook
		*(ULONGLONG*)sQlHookPnt = sQlHookPntData;
		//��ձ���
		sQlHookPnt = 0;
		sQlHookPntData = 0; 
		hooked = false;
		CdbId = 0;
	}
	LeaveCriticalSection(&_critical);
}

int _Lc_doHook(UINT_PTR HookPnt) {
	EnterCriticalSection(&_critical);
	if (sQlHookPnt)
	{
		LeaveCriticalSection(&_critical);
		return 1;
	}	
	//TODO:Ч��sqlmin.dll�汾
	void* sqlminBase = GetModuleHandle(L"sqlmin.dll");
	if (!sqlminBase)
	{
		LeaveCriticalSection(&_critical);
		return 2;
	}
	//���ǰ�󼸸��ֽ��Ƿ���Ч
	UINT_PTR testHookPnt = (UINT_PTR)sqlminBase + HookPnt - 3;
	if (IsBadReadPtr((void*)testHookPnt, 0x10)) {
		LeaveCriticalSection(&_critical);
		return 3;
	}
	//�������Ƿ���ȷ
	if (*(INT64*)testHookPnt != 0x0001a090ffce8b49L || 
		*(INT64*)(testHookPnt+8) != 0x786d8b44185d8b00L) {
		LeaveCriticalSection(&_critical);
		return 4;
	}
	//UINT_PTR hookPnt = (UINT_PTR)sqlminBase + 0x5FD30 + 0x5C1;
	UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
	UINT_PTR dwAdr = (UINT_PTR)&hookfuncEnd;
	if (((testHookPnt >> 32) & 0xFFFFFFFF) != ((dwAdr >> 32) & 0xFFFFFFFF))
	{
		//����ͬһ����hookʧ�ܣ�
		LeaveCriticalSection(&_critical);
		return 5;
	}

	sQlHookPnt = (UINT_PTR)sqlminBase + HookPnt;

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

	hooked = true;
	LeaveCriticalSection(&_critical);
	return 99;
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

INT64 _Lc_Get_Databases(void) {
	return CdbId;
}

void _Lc_Free_PaddingData(PlogRecdItem logRecd_first) {
	delete logRecd_first;
}