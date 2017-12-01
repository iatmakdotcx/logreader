// Win32Project1.cpp : 定义 DLL 应用程序的导出函数。
//

#include "stdafx.h"
#include "Win32Project1.h"
#include "aax64.h"
#include <exception>  
#include <time.h> 
#include <process.h>
using namespace std;

ULONGLONG sQlHookPnt = 0;
ULONGLONG sQlHookPntData = 0;
bool hooked = false;
PTransPkg list_TransPkg = NULL;

volatile PlogRecdItem logRecd_first = NULL;
volatile PlogRecdItem logRecd_last = NULL;

// 目录
LPCWSTR lpPageFilePath = L"C:\\log\\";
//已打开的文件句柄
HANDLE hFile = 0;
//临界对象，防止多个线程同时写入文件
CRITICAL_SECTION  _critical;

//保存线程是否终止
volatile int sthde_terminated = 1;
//保存log线程句柄
HANDLE sthde = 0;

int test(void)
{
	return 14;
}

void SetSavePath(LPCWSTR srvproc) {
	lpPageFilePath = srvproc;

}
LPCWSTR GetSavePath() {
	return lpPageFilePath;
}


//void domyWork2(ULONGLONG eCount, void* eLength, void* eData, void* oldPageData) {
//	__try
//	{
//		if (eCount > 0)
//		{
//			if (*(ULONG*)eLength > 0x1E)
//			{
//				ULONGLONG logHeaderData = *(ULONGLONG*)eData;
//
//				DWORD TranID_1 = *(DWORD*)(logHeaderData + 0x10);
//				WORD TranID_2 = *(WORD*)(logHeaderData + 0x14);
//				WORD slot = *(WORD*)(logHeaderData + 0x1E);
//				DWORD LSN_1 = *(DWORD*)(logHeaderData + 0x24);
//				DWORD LSN_2 = *(DWORD*)(logHeaderData + 0x28);
//				WORD LSN_3 = *(WORD*)(logHeaderData + 0x2C);
//				WORD PageSoltCnt = *(WORD*)((ULONGLONG)oldPageData + 0x16);
//				if (slot < PageSoltCnt)
//				{
//					ULONGLONG RowDataOffset = *(WORD*)(((ULONGLONG)oldPageData + 0x2000) - ((slot + 1) * 2));
//					WORD RowDataEnd = 0;
//					if (slot + 1 == PageSoltCnt)
//					{//最后一行
//						RowDataEnd = *(WORD*)((ULONGLONG)oldPageData + 0x1E);  //m_freeData
//					}
//					else {
//						RowDataEnd = *(WORD*)(((ULONGLONG)oldPageData + 0x2000) - ((slot + 2) * 2)); //NextRow
//					}
//					RowDataEnd = RowDataEnd - (WORD)RowDataOffset;
//					RowDataOffset = RowDataOffset + (ULONGLONG)oldPageData;
//
//					BYTE* slotData = new BYTE[RowDataEnd];
//					memcpy(slotData, (PVOID)RowDataOffset, RowDataEnd);
//
//					PTransPkg aTransPkg = list_TransPkg;
//					//查找列表中是否包含此事务的数据
//					while (aTransPkg)
//					{
//						if (aTransPkg->TranID_1 == TranID_1 && aTransPkg->TranID_2 == TranID_2)
//						{
//							break;
//						}
//						aTransPkg = aTransPkg->n;
//					}
//
//					PLSNItem aLSNItem = new LSNItem();
//					aLSNItem->LSN_1 = LSN_1;
//					aLSNItem->LSN_2 = LSN_2;
//					aLSNItem->LSN_3 = LSN_3;
//
//					aLSNItem->length = RowDataEnd;
//					aLSNItem->val = slotData;
//
//					if (!aTransPkg)
//					{
//						//列表中不存在
//						//新增一个，
//						aTransPkg = new TransPkg();
//						aTransPkg->item = aLSNItem;
//						if (!list_TransPkg)
//						{
//							list_TransPkg = aTransPkg;
//						}
//						else {
//							//加到末尾
//							PTransPkg lastItem = list_TransPkg;
//							while (1)
//							{
//								if (!lastItem->n) {
//									lastItem->n = aTransPkg;
//									break;
//								}
//								lastItem = lastItem->n;
//							}
//						}
//					}
//					else {
//						//加到末尾
//						PLSNItem lastlsnItem = aTransPkg->item;
//						while (1)
//						{
//							if (!lastlsnItem->n) {
//								lastlsnItem->n = aLSNItem;
//								break;
//							}
//							lastlsnItem = lastlsnItem->n;
//						}
//					}
//				}
//			}
//		}
//	}
//	__except (EXCEPTION_EXECUTE_HANDLER)
//	{
//
//	}
//}
//
//void domyWork_old(ULONGLONG eCount, void* eLength, void* eData, void* oldPageData) {
//	__try
//	{
//		if (eCount > 0)
//		{
//			if (*(ULONG*)eLength > 0x1E)
//			{
//				ULONGLONG logHeaderData = *(ULONGLONG*)eData;
//
//				DWORD TranID_1 = *(DWORD*)(logHeaderData + 0x10);
//				WORD TranID_2 = *(WORD*)(logHeaderData + 0x14);
//				WORD slot = *(WORD*)(logHeaderData + 0x1E);
//				DWORD LSN_1 = *(DWORD*)(logHeaderData + 0x24);
//				DWORD LSN_2 = *(DWORD*)(logHeaderData + 0x28);
//				WORD LSN_3 = *(WORD*)(logHeaderData + 0x2C);
//				WORD PageSoltCnt = *(WORD*)((ULONGLONG)oldPageData + 0x16);
//				if (slot < PageSoltCnt)
//				{
//					ULONGLONG RowDataOffset = *(WORD*)(((ULONGLONG)oldPageData + 0x2000) - ((slot + 1) * 2));
//					WORD RowDataEnd = 0;
//					if (slot + 1 == PageSoltCnt)
//					{//最后一行
//						RowDataEnd = *(WORD*)((ULONGLONG)oldPageData + 0x1E);  //m_freeData
//					}
//					else {
//						RowDataEnd = *(WORD*)(((ULONGLONG)oldPageData + 0x2000) - ((slot + 2) * 2)); //NextRow
//					}
//					RowDataEnd = RowDataEnd - (WORD)RowDataOffset;
//					RowDataOffset = RowDataOffset + (ULONGLONG)oldPageData;
//
//					BYTE* slotData = new BYTE[RowDataEnd];
//					memcpy(slotData, (PVOID)RowDataOffset, RowDataEnd);
//
//					PlogRecdItem LR = new logRecdItem;
//					LR->TranID_1 = TranID_1;
//					LR->TranID_2 = TranID_2;
//					LR->LSN_1 = LSN_1;
//					LR->LSN_2 = LSN_2;
//					LR->LSN_3 = LSN_3;
//
//					LR->length = RowDataEnd;
//					LR->val = slotData;
//					LR->n = NULL;
//					//断链
//					PlogRecdItem oldLR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_last, LR);					
//					//接链
//					if (oldLR)
//					{
//						oldLR->n = LR;	
//					}
//					else {
//						logRecd_first = LR;
//					}			
//				}
//			}
//		}
//	}
//	__except (EXCEPTION_EXECUTE_HANDLER)
//	{
//
//	}
//}

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
				UINT_PTR RowDataOffset = *(WORD*)((oldPageData + 0x2000) - ((slot + 1) * 2));
				WORD RowDataEnd = 0;
				if (slot + 1 == PageSoltCnt)
				{//最后一行
					RowDataEnd = *(WORD*)(oldPageData + 0x1E);  //m_freeData
				}
				else {
					RowDataEnd = *(WORD*)((oldPageData + 0x2000) - ((slot + 2) * 2)); //NextRow
				}
				//行数据长度
				RowDataEnd = RowDataEnd - (WORD)RowDataOffset;
				RowDataOffset = RowDataOffset + oldPageData;

				BYTE* slotData = new BYTE[RowDataEnd];
				memcpy(slotData, (PVOID)RowDataOffset, RowDataEnd);

				PlogRecdItem LR = new logRecdItem;
				LR->TranID_1 = TranID_1;
				LR->TranID_2 = TranID_2;
				LR->lsn.LSN_1 = lsn->LSN_1;
				LR->lsn.LSN_2 = lsn->LSN_2;
				LR->lsn.LSN_3 = lsn->LSN_3;

				LR->length = RowDataEnd;
				LR->val = slotData;
				LR->n = NULL;
				//断链
				PlogRecdItem oldLR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_last, LR);
				//接链
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
	//Interlocked 掉，防止被其它线程重复提取
	PlogRecdItem LR = (PlogRecdItem)InterlockedExchangePointer((PVOID*)&logRecd_first, NULL);	
	if (LR)
	{
		//截断末尾
		logRecd_last = NULL;
		BYTE* Tempbuffer = new BYTE[0x2000];//一个页最大就这么多
		DWORD Tempbuffer_Posi = 0;
		while (LR)
		{
			//20=sizeof(LR->TranID_1)+sizeof(LR->TranID_2) + sizeof(LR->LSN_1)+sizeof(LR->LSN_2)+sizeof(LR->LSN_3) + sizeof(LR->length)
			//20=4+2 + 4+4+2 + 4
			if (LR->length+20 < (0x2000 - Tempbuffer_Posi))
			{
				//缓冲区足够
				memcpy(&Tempbuffer[Tempbuffer_Posi], &LR->TranID_1, 20);
				Tempbuffer_Posi += 20;
				memcpy(&Tempbuffer[Tempbuffer_Posi], LR->val, LR->length);
				Tempbuffer_Posi += LR->length;
			}else {
				//缓冲区不够
				if (Tempbuffer_Posi == 0)
				{
					//单条logRecdItem内容大于0x2000应该是无效数据
				}
				else {
					//缓冲区大小不足，先写入文件一次					
					writeBuffDataToFile(Tempbuffer, Tempbuffer_Posi); 
					Tempbuffer_Posi = 0;
					continue;
				}
			}
			//释放已使用的对象
			PlogRecdItem tmpLR = LR;
			LR = LR->n;
			delete tmpLR->val;
			delete tmpLR;
		}

		if (Tempbuffer_Posi > 0)
		{
			//链表读取完成，如果缓冲区还有数据，写入文件一次
			writeBuffDataToFile(Tempbuffer, Tempbuffer_Posi);
		}
		delete Tempbuffer;
	}
}

unsigned int __stdcall PageSave2FileThread(LPVOID lpParam) {
	//线程退出标志，启动的时候置0，停止的时候置1
	while (!sthde_terminated)
	{
		PageSave2File();
		//每完成一次，暂停1秒
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
		//原值=0说明线程已经启动
	}
	else {
		sthde = (HANDLE)_beginthreadex(NULL, 0, PageSave2FileThread, NULL, 0, NULL);
	}
}
void StopTimer() {
	int state = InterlockedExchange((unsigned int*)&sthde_terminated, 1);
	if (state == 0)
	{
		//等待线程退出
		WaitForSingleObject(sthde, INFINITE);
	}
	else {
		//原值不等于0说明线程已经停止
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

	//TODO:效验sqlmin.dll版本
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
		//不在同一区域，hook失败！
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
