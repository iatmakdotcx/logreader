// Win32Project1.cpp : 定义 DLL 应用程序的导出函数。
//

#include "stdafx.h"
#include "Win32Project1.h"
#include "aax64.h"
#include <exception>  

using namespace std;

ULONGLONG Sqlmin_PageRef_ModifyColumnsInternal_Ptr = 0;
void* Sqlmin_PageRef_ModifyColumnsInternal_Data = NULL;
DWORD Sqlmin_PageRef_ModifyColumnsInternal_Len = 0;

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
	Sqlmin_PageRef_ModifyColumnsInternal_Data = malloc(0x100);
	InitializeCriticalSection(&_critical);
}

void f_finalization() {
	_Lc_unHook();
	DeleteCriticalSection(&_critical);
	free(Sqlmin_PageRef_ModifyColumnsInternal_Data);
}

bool checkRawPtr(UINT_PTR rawData) {
	if (IsBadReadPtr((void*)rawData, 8)) {
		return false;
	}
	rawData = *(UINT_PTR*)rawData;
	rawData = rawData + 8;
	if (IsBadReadPtr((void*)rawData, 8)) {
		return false;
	}
	rawData = *(UINT_PTR*)rawData;
	if (IsBadReadPtr((void*)rawData, 6)) {
		return false;
	}
	BYTE flag1 = *(BYTE*)rawData;
	if ((flag1 & 0x0F) != 0)
	{
		//not primary record.
		return false;
	}
	BYTE flag2 = *(BYTE*)(rawData+1);
	if (flag2 != 0)
	{
		//ghost forwarded record
		return false;
	}
	if ((*(WORD*)(rawData + 2) & 0x7FFF) > 0x2000)
	{
		//colCntoffset out of range
		return false;
	}
	return true;
}


bool checkXdesRMRWPtr(UINT_PTR XdesRMRW) {
	if (IsBadReadPtr((void*)XdesRMRW, 0x464)) {
		return false;
	}
	WORD dbid = *(WORD*)(XdesRMRW + 0x460);
	if (dbid & 0xff00)
	{
		//biger than 255
		return false;
	}	
	return true;
}

void domyWork_2(UINT_PTR XdesRMReadWrite, UINT_PTR rawData) {	
	if (checkXdesRMRWPtr(XdesRMReadWrite))
	{
		WORD dbid = *(WORD*)(XdesRMReadWrite + 0x460);
		PLSN lsn = (PLSN)(XdesRMReadWrite + 0x32c);
		if (dbid > 0 && dbid < 64 && (((INT64)1 << (dbid - 1)) & CdbId) && lsn->LSN_1 > 0 && checkRawPtr(rawData))
		{
			rawData = *(UINT_PTR*)rawData + 8;			
			rawData = *(UINT_PTR*)rawData;
			WORD RowFlag = *(WORD*)rawData;
			UINT_PTR Endoffset = rawData + (*(WORD*)(rawData + 2) & 0x7FFF);
			WORD colCnt = *(WORD*)(Endoffset);
			Endoffset += 2;
			if (RowFlag & 0x10)
			{
				//null map
				Endoffset += (colCnt + 7) >> 3;
			}
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
			if (RowDatalength > 0x2000)
			{
				return;
			}

			PVOID slotData = malloc(RowDatalength);
			memcpy(slotData, (PVOID)rawData, RowDatalength);

			//PLSN lsn = (PLSN)(XdesRMReadWrite + 0x32c);
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

bool hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked() {
	if (Sqlmin_PageRef_ModifyColumnsInternal_Data!=NULL && 
		Sqlmin_PageRef_ModifyColumnsInternal_Len>0 && 
		Sqlmin_PageRef_ModifyColumnsInternal_Ptr>0 &&
		memcmp(Sqlmin_PageRef_ModifyColumnsInternal_Data, (void*)Sqlmin_PageRef_ModifyColumnsInternal_Ptr, Sqlmin_PageRef_ModifyColumnsInternal_Len)!=0 )
	{
		return true;
	}
	else {
		return false;
	}
}

void hook_sqlmin_PageRef_ModifyColumnsInternal_x64_unhook() {
	if (hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked()) {
		*(UINT_PTR*)Sqlmin_PageRef_ModifyColumnsInternal_Ptr = *(UINT_PTR*)Sqlmin_PageRef_ModifyColumnsInternal_Data;		
	}
}

void hook_sqlmin_PageRef_ModifyColumnsInternal_x64_near(UINT_PTR hook_Ptr) {
	if (!hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked()) {
		Sqlmin_PageRef_ModifyColumnsInternal_Ptr = hook_Ptr;
		*(UINT_PTR*)Sqlmin_PageRef_ModifyColumnsInternal_Data = *(UINT_PTR*)hook_Ptr;
		Sqlmin_PageRef_ModifyColumnsInternal_Len = 5;

		UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
		UINT_PTR hookfuncPntEnd = (UINT_PTR)&hookfuncEnd;
		
		ULONG backPntData = (hook_Ptr & 0xFFFFFFFF) - ((hookfuncPntEnd + Sqlmin_PageRef_ModifyColumnsInternal_Len) & 0xFFFFFFFF) ; // jmp code Length
		ULONG hookPntData = (hookfuncPnt & 0xFFFFFFFF) - (hook_Ptr & 0xFFFFFFFF) - 5; // jmp code Length
		DWORD dwOldP;
		VirtualProtect((LPVOID)hookfuncPntEnd, 0x20, PAGE_EXECUTE_READWRITE, &dwOldP);
		memcpy((void*)hookfuncPntEnd, (void*)hook_Ptr, Sqlmin_PageRef_ModifyColumnsInternal_Len);
		*(BYTE*)(hookfuncPntEnd + Sqlmin_PageRef_ModifyColumnsInternal_Len) = 0xE9;
		*(DWORD*)(hookfuncPntEnd + Sqlmin_PageRef_ModifyColumnsInternal_Len + 1) = backPntData;

		VirtualProtect((LPVOID)hook_Ptr, 8, PAGE_EXECUTE_READWRITE, &dwOldP);
		UINT_PTR interLockData = ((*(UINT_PTR*)hook_Ptr & 0xFFFFFF0000000000) | 0xE9) | ((UINT_PTR)hookPntData << 8);
		*(UINT_PTR*)hook_Ptr = interLockData;		
	}
}

void hook_sqlmin_PageRef_ModifyColumnsInternal_x64_far(UINT_PTR hook_Ptr, UINT_PTR sqlminBase) {
	if (!hook_sqlmin_PageRef_ModifyColumnsInternal_x64_hasHooked()) {
		Sqlmin_PageRef_ModifyColumnsInternal_Ptr = hook_Ptr;
		*(UINT_PTR*)Sqlmin_PageRef_ModifyColumnsInternal_Data = *(UINT_PTR*)hook_Ptr;

		UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
		UINT_PTR hookfuncPntEnd = (UINT_PTR)&hookfuncEnd;

		DWORD dwOldP;
		VirtualProtect((LPVOID)(sqlminBase + 0x20), 8, PAGE_READWRITE, &dwOldP);
		*(UINT_PTR*)(sqlminBase + 0x20) = hookfuncPnt;

		DWORD inlHCnt = 7;//改写的数量

		VirtualProtect((LPVOID)hookfuncPntEnd, 0x20, PAGE_EXECUTE_READWRITE, &dwOldP);
		memcpy((void*)hookfuncPntEnd, (void*)hook_Ptr, inlHCnt);
		*(DWORD*)(hookfuncPntEnd + inlHCnt) = 0x25FF;
		*(WORD*)(hookfuncPntEnd + inlHCnt + 4) = 0;
		*(UINT_PTR*)(hookfuncPntEnd + inlHCnt + 6) = (UINT_PTR)hook_Ptr + inlHCnt;

		VirtualProtect((LPVOID)hook_Ptr, 8, PAGE_EXECUTE_READWRITE, &dwOldP);

		ULONG hookPntData = ((sqlminBase + 0x20 - hook_Ptr) & 0xFFFFFFFF) - 6; // jmp code Length
		UINT_PTR interLockData = (*(UINT_PTR*)hook_Ptr & 0xFFFF000000000000) | 0x25FF;
		interLockData = interLockData | ((UINT_PTR)hookPntData << 16);
		*(UINT_PTR*)hook_Ptr = interLockData;

		Sqlmin_PageRef_ModifyColumnsInternal_Len = inlHCnt;
	}
}

void hook_sqlmin_PageRef_ModifyColumnsInternal_x64(UINT_PTR hook_Ptr, UINT_PTR sqlminBase) {
	UINT_PTR hookfuncPnt = (UINT_PTR)&hookfunc;
	if (hook_Ptr > hookfuncPnt)
	{
		if (hook_Ptr - hookfuncPnt > 0x7FFFFF00)
		{
			//far
			hook_sqlmin_PageRef_ModifyColumnsInternal_x64_far(hook_Ptr, sqlminBase);
		}
		else {
			hook_sqlmin_PageRef_ModifyColumnsInternal_x64_near(hook_Ptr);
		}
	}
	else {
		if (hookfuncPnt - hook_Ptr > 0x7FFFFF00)
		{
			//far
			hook_sqlmin_PageRef_ModifyColumnsInternal_x64_far(hook_Ptr, sqlminBase);
		}
		else {
			hook_sqlmin_PageRef_ModifyColumnsInternal_x64_near(hook_Ptr);
		}
	}
}

void _Lc_unHook(void) {
	EnterCriticalSection(&_critical);
	hook_sqlmin_PageRef_ModifyColumnsInternal_x64_unhook();	
	hooked = false;
	LeaveCriticalSection(&_critical);
}

int _Lc_doHook(UINT_PTR mRowPtr) {
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

	/*testHookPnt = testHookPnt ^ (UINT_PTR)&_critical;	
	if (testHookPnt >> 32)
	{
		//不在同一区域，hook失败！
		LeaveCriticalSection(&_critical);
		return 4;
	}*/
	hook_sqlmin_PageRef_ModifyColumnsInternal_x64((UINT_PTR)sqlminBase + mRowPtr, (UINT_PTR)sqlminBase);

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
	free(logRecd_first->val);
	logRecd_first->val = NULL;
	delete logRecd_first;
}