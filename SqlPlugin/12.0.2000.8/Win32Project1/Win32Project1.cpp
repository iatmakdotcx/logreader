// Win32Project1.cpp : 定义 DLL 应用程序的导出函数。
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
	HMODULE hMod = LoadLibrary(L"opends60.dll");//dll路径
	if (!wsrv_sendrow)
	{
		wsrv_rpcparams = (Tsrv_rpcparams)GetProcAddress(hMod, (("srv_rpcparams")));//直接使用原工程函数名 
		wsrv_sendmsg = (Tsrv_sendmsg)GetProcAddress(hMod, (("srv_sendmsg")));//直接使用原工程函数名 
		wsrv_senddone = (Tsrv_senddone)GetProcAddress(hMod, (("srv_senddone")));//直接使用原工程函数名 
		wsrv_describe = (Tsrv_describe)GetProcAddress(hMod, (("srv_describe")));//直接使用原工程函数名 
		wsrv_paraminfo = (Tsrv_paraminfo)GetProcAddress(hMod, (("srv_paraminfo")));//直接使用原工程函数名 
		wsrv_setcoldata = (Tsrv_setcoldata)GetProcAddress(hMod, (("srv_setcoldata")));//直接使用原工程函数名 
		wsrv_setcollen = (Tsrv_setcollen)GetProcAddress(hMod, (("srv_setcollen")));//直接使用原工程函数名 
		wsrv_sendrow = (Tsrv_sendrow)GetProcAddress(hMod, (("srv_sendrow")));//直接使用原工程函数名 
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
		_snprintf_s(spText, MAXTEXT, "ERROR. 必须填写路径.");
		wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

		// Signal the client that we are finished.
		wsrv_senddone(srvproc, SRV_DONE_FINAL, (DBUSMALLINT)0, (DBINT)0);

		return XP_NOERROR;
	}

	BOOL bNull;
	BYTE bType;
	ULONG uLen;
	ULONG uMaxLen;
	//获取第一个参数信息
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, NULL, &bNull);
	//为参数分配空间
	BYTE* Data = new BYTE[uLen+2];
	memset(Data, '\0', uLen+2);
	//获取参数内容
	wsrv_paraminfo(srvproc, 1, &bType, &uMaxLen, &uLen, Data, &bNull);

	_snprintf_s(spText, MAXTEXT, "路径：%s" ,(char*)Data);
	wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);

	if (!dirExists((char*)Data)) {
		_snprintf_s(spText, MAXTEXT, "目录不存在或无访问权限！");
		wsrv_sendmsg(srvproc, SRV_MSG_INFO, 0, (DBTINYINT)0, (DBTINYINT)0, NULL, 0, 0, spText, SRV_NULLTERM);
		if (!dirCreate((char*)Data)) {
			_snprintf_s(spText, MAXTEXT, "创建目录失败");
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

	_snprintf_s(spText, MAXTEXT, "设置完成");
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
