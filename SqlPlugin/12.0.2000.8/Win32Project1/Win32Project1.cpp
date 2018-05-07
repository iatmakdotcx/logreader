// Win32Project1.cpp : 定义 DLL 应用程序的导出函数。
//

#include "stdafx.h"
#include "Win32Project1.h"
#include "aax64.h"
#include <exception>  
#include <time.h> 
#include <process.h>
#include <strsafe.h> 

using namespace std;

ULONGLONG Sqlmin_Page_ModifyRow_Ptr = 0;
ULONGLONG Sqlmin_Page_ModifyRow_Data = 0;

ULONGLONG Sqlmin_Page_ModifyColumns_Ptr = 0;
ULONGLONG Sqlmin_Page_ModifyColumns_Data = 0;
bool hooked = false;
PTransPkg list_TransPkg = NULL;

volatile PlogRecdItem logRecd_first = NULL;
volatile PlogRecdItem logRecd_last = NULL;
volatile LONG PaddingDataCnt = 0;

//临界对象，防止多个线程同时写入文件
CRITICAL_SECTION  _critical;

//要捕获的数据库id
INT64 CdbId = 0;


void f_initialization() {
	InitializeCriticalSection(&_critical);
}

void f_finalization() {
	_Lc_unHook();
	DeleteCriticalSection(&_critical);
}

void domyWork_2(UINT_PTR XdesRMReadWrite, UINT_PTR rawData) {
	__try
	{
		//10w数据未处理，就不记录后面的东西了，估计都挂了
		if (PaddingDataCnt < 100000)
		{
			WORD dbid = *(WORD*)(XdesRMReadWrite + 0x460);
			if (dbid > 0 && dbid < 64 && (((INT64)1 << (dbid - 1)) & CdbId))
			{
				PLSN lsn = (PLSN)(XdesRMReadWrite + 0x32c);

				WORD RowFlag = *(WORD*)rawData;
				UINT_PTR Endoffset = rawData + (*(WORD*)(rawData + 2) & 0x7FFF);
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
					Endoffset = rawData + (*(WORD*)(Endoffset) & 0x7FFF);
				}
				if (RowFlag & 0x40)
				{
					//versioning tag
					Endoffset += 0xE;
				}

				DWORD RowDatalength = (DWORD)(Endoffset - rawData);

				BYTE* slotData = new BYTE[RowDatalength];
				memcpy(slotData, (PVOID)rawData, RowDatalength);

				PlogRecdItem LR = new logRecdItem;
				LR->TranID_1 = 0;
				LR->TranID_2 = 0;
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
	__except (EXCEPTION_EXECUTE_HANDLER)
	{}
}

void domyWork(UINT_PTR eCount, UINT_PTR r14, UINT_PTR logHeader, UINT_PTR oldPageData) {
	__try
	{
		//10w数据未处理，就不记录后面的东西了，估计都挂了
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
					//开始位置
					UINT_PTR RowDataOffset = oldPageData + *(WORD*)((oldPageData + 0x2000) - ((slot + 1) * 2));
					//计算log长度
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
						//TODO:bug

						Endoffset = RowDataOffset + (*(WORD*)(Endoffset) & 0x7FFF);
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
		//截断末尾
		logRecd_last = NULL;
		PaddingDataCnt = 0;
		return LR;
	}
	return NULL;
}

bool hook_sqlmin_Page_ModifyColumns_x64_hasHooked(UINT_PTR hook_Ptr) {
	UINT_PTR origindata = 0x564155415441f5ffL;
	//sqlmin!Page::ModifyColumns:
	// fff5  push rbp
	// 4154  push r12
	// 4155  push r13
	// 4156  push r14
	UINT_PTR nowdata = *(UINT_PTR*)hook_Ptr;
	return origindata != nowdata;
}

void hook_sqlmin_Page_ModifyColumns_x64(UINT_PTR hook_Ptr) {
	if (!hook_sqlmin_Page_ModifyColumns_x64_hasHooked(hook_Ptr)) {
		UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc_2;
		UINT_PTR hookfuncPntEnd = (UINT_PTR)&hookfuncEnd_2;

		ULONG backPnt = (hook_Ptr & 0xFFFFFFFF) + 0x6;
		ULONG backPntData = backPnt - (hookfuncPntEnd & 0xFFFFFFFF) - 5; // jmp code Length
		ULONG hookPntData = (hookfuncPnt & 0xFFFFFFFF) - (hook_Ptr & 0xFFFFFFFF) - 5; // jmp code Length
		DWORD dwOldP;
		VirtualProtect((LPVOID)hookfuncPntEnd, 0x10, PAGE_EXECUTE_READWRITE, &dwOldP);
		*(BYTE*)hookfuncPntEnd = 0xE9;
		hookfuncPntEnd += 1;
		*(DWORD*)hookfuncPntEnd = backPntData;

		VirtualProtect((LPVOID)hook_Ptr, 5, PAGE_EXECUTE_READWRITE, &dwOldP);
		UINT_PTR interLockData = 0x56419000000000E9L | ((UINT_PTR)hookPntData << 8);
		Sqlmin_Page_ModifyColumns_Data = *(UINT_PTR*)hook_Ptr;
		*(UINT_PTR*)hook_Ptr = interLockData;

		Sqlmin_Page_ModifyColumns_Ptr = hook_Ptr;
	}
}

void hook_sqlmin_Page_ModifyColumns_x64_unhook() {
	if (Sqlmin_Page_ModifyColumns_Ptr && hook_sqlmin_Page_ModifyColumns_x64_hasHooked(Sqlmin_Page_ModifyColumns_Ptr)) {
		*(ULONGLONG*)Sqlmin_Page_ModifyColumns_Ptr = Sqlmin_Page_ModifyColumns_Data;
		Sqlmin_Page_ModifyColumns_Ptr = 0;
		Sqlmin_Page_ModifyColumns_Data = 0;
	}
}

bool hook_sqlmin_Page_ModifyRow_x64_hasHooked(UINT_PTR hook_Ptr) {
	UINT_PTR origindata = 0x44894420244c8944L;
	//sqlmin!Page::ModifyRow:
	//44894c2420      mov     dword ptr[rsp + 20h], r9d
	//4489442418      mov     dword ptr[rsp + 18h], r8d
	UINT_PTR nowdata = *(UINT_PTR*)hook_Ptr;
	return origindata != nowdata;
}

void hook_sqlmin_Page_ModifyRow_x64(UINT_PTR hook_Ptr) {
	if (!hook_sqlmin_Page_ModifyRow_x64_hasHooked(hook_Ptr)) {
		UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
		UINT_PTR hookfuncPntEnd = (UINT_PTR)&hookfuncEnd;

		ULONG backPnt = (hook_Ptr & 0xFFFFFFFF) + 0x6;
		ULONG backPntData = backPnt - (hookfuncPntEnd & 0xFFFFFFFF) - 6; // jmp code Length
		ULONG hookPntData = (hookfuncPnt & 0xFFFFFFFF) - (hook_Ptr & 0xFFFFFFFF) - 5; // jmp code Length
		DWORD dwOldP;
		VirtualProtect((LPVOID)hookfuncPntEnd, 0x10, PAGE_EXECUTE_READWRITE, &dwOldP);
		*(BYTE*)hookfuncPntEnd = 0xE9;
		hookfuncPntEnd += 1;
		*(DWORD*)hookfuncPntEnd = backPntData;

		VirtualProtect((LPVOID)hook_Ptr, 5, PAGE_EXECUTE_READWRITE, &dwOldP);
		UINT_PTR interLockData = 0x44894400000000E9L | ((UINT_PTR)hookPntData << 8);
		Sqlmin_Page_ModifyRow_Data = *(UINT_PTR*)hook_Ptr;
		*(UINT_PTR*)hook_Ptr = interLockData;

		Sqlmin_Page_ModifyRow_Ptr = hook_Ptr;
	}
}

void hook_sqlmin_Page_ModifyRow_x64_unhook() {
	if (Sqlmin_Page_ModifyRow_Ptr && hook_sqlmin_Page_ModifyRow_x64_hasHooked(Sqlmin_Page_ModifyRow_Ptr)) {
		*(ULONGLONG*)Sqlmin_Page_ModifyRow_Ptr = Sqlmin_Page_ModifyRow_Data;
		Sqlmin_Page_ModifyRow_Ptr = 0;
		Sqlmin_Page_ModifyRow_Data = 0;
	}
}

void _Lc_unHook(void) {
	EnterCriticalSection(&_critical);
	hook_sqlmin_Page_ModifyRow_x64_unhook();
	hook_sqlmin_Page_ModifyColumns_x64_unhook();
	LeaveCriticalSection(&_critical);
}

int _Lc_doHook(UINT_PTR mRowPtr, UINT_PTR mColumnsPtr) {
	EnterCriticalSection(&_critical);
	if (hooked)
	{
		LeaveCriticalSection(&_critical);
		return 1;
	}	
	//TODO:效验sqlmin.dll版本
	void* sqlminBase = GetModuleHandle(L"sqlmin.dll");
	if (!sqlminBase)
	{
		LeaveCriticalSection(&_critical);
		return 2;
	}
	//检测前后几个字节是否有效
	UINT_PTR testHookPnt = (UINT_PTR)sqlminBase + mRowPtr - 3;
	if (IsBadReadPtr((void*)testHookPnt, 0x10)) {
		LeaveCriticalSection(&_critical);
		return 3;
	}
	testHookPnt = (UINT_PTR)sqlminBase + mColumnsPtr - 3;
	if (IsBadReadPtr((void*)testHookPnt, 0x10)) {
		LeaveCriticalSection(&_critical);
		return 3;
	}
	testHookPnt = testHookPnt ^ (UINT_PTR)&_critical;
	testHookPnt = testHookPnt >> 32;
	if (testHookPnt)
	{
		//不在同一区域，hook失败！
		LeaveCriticalSection(&_critical);
		return 4;
	}
	hook_sqlmin_Page_ModifyRow_x64((UINT_PTR)sqlminBase + mRowPtr);
	hook_sqlmin_Page_ModifyColumns_x64((UINT_PTR)sqlminBase + mColumnsPtr);

	hooked = true;
	LeaveCriticalSection(&_critical);
	return 99;
}

INT64 _Lc_HasBeenHooked(void) {
	return hooked;
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