
.data
extern domyWork : proc
extern domyWork_2 : proc

.CODE

hookfunc PROC
	; jmp过来的，堆栈完好，先直接调用
	call qword ptr [rax+1A0h]
	push rax
	push rcx  ;rcx,rdx 貌似后面都直接覆盖了，这先保存，待调试
	push rdx
	push r8
	push r9

	mov eax, [rbp+8D0h]     ;Header of Log
	cmp eax,40h				;小于40的都不是更新数据
	jb @ee
	
	mov rcx, r13			;elements count
	mov rdx, r14			;XdesRMReadWrite object
	mov r8, [rbp+120h]		;list of elements
	mov r9, [rbp+70h]		;old page Data
	call domyWork

	@ee:
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rax
hookfunc ENDP

hookfuncEnd PROC
	;空间留够，用于返回原函数
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret
hookfuncEnd ENDP


hookfunc_2 PROC
	; jmp过来的，堆栈完好，先直接调用

	push rax
	push rcx  ;rcx,rdx 貌似后面都直接覆盖了，这先保存，待调试
	push rdx
	;[rbp+6C0]   ;XdesRMReadWrite object 
	;[rbp+550] 新的内容
	mov rcx, [rbp+6C0h]		;XdesRMReadWrite object 
	mov rdx, [rbp+550h]		;new raw data
	call domyWork_2

	pop rdx
	pop rcx
	pop rax
		
	push rbp
	push r12
	push r13
	push r14
	push r15
hookfunc_2 ENDP

hookfuncEnd_2 PROC
	;空间留够，用于返回原函数

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret
hookfuncEnd_2 ENDP


END