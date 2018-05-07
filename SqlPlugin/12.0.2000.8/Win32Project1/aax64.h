#ifndef __ASMCODE_H  
#define __ASMCODE_H  

extern "C"
{
	void _stdcall hookfunc(void);
	void _stdcall hookfuncEnd(void);
	void _stdcall hookfunc_2(void);
	void _stdcall hookfuncEnd_2(void);
}

#endif  