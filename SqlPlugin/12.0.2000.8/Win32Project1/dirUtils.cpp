#include "stdafx.h"
#include "dirUtils.h"
#include <io.h>  
#include <direct.h>  

bool dirExists(char* dir) {
	return _access(dir, 06) == 0;
}


bool dirCreate(char* dir) {

	//char buf[100] = "C:\\log\\1\\2";
	int result = 0;
	char *p;
	bool firstSym = true;
	bool hasNew = true;
	char tmpc[256] = "";
	for (p = dir; *p != '\0'; p++) {
		char cr[2] = "";
		cr[0] = *(char*)p;
		cr[1] = '\0';
		strcat_s(tmpc, 256, cr);
		hasNew = true;
		if (cr[0] == '\\')
		{
			if (firstSym)
			{
				firstSym = false;
			}
			else {
				printf("%s\r\n", tmpc);
				result = _mkdir(tmpc);
				if (result != 0)
				{
					return false;
				}
				hasNew = false;
			}
		}
	}
	if (hasNew)
	{
		result = _mkdir(tmpc);
		if (result != 0)
		{
			return false;
		}
	}
	return result == 0;
}