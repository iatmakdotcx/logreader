
.data
extern domyWork : proc

.CODE

hookfunc PROC
	; jmp过来的，堆栈完好，先直接调用
	call qword ptr [rax+1A0h]
	push rax
	push rcx  ;rcx,rdx 貌似后面都直接覆盖了，这先保存，待调试
	push rdx
	push r8
	push r9

	mov rcx, r13			;elements count
	lea rdx, [rbp+8D0h]		;pre elements length
	lea r8, [rbp+120h]		;list of elements
	mov r9, [rbp+70h]		;old page Data
	call domyWork
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
	ret
hookfuncEnd ENDP

END