
.data
extern domyWork : proc

.CODE

hookfunc PROC
	; jmp�����ģ���ջ��ã���ֱ�ӵ���
	call qword ptr [rax+1A0h]
	push rax
	push rcx  ;rcx,rdx ò�ƺ��涼ֱ�Ӹ����ˣ����ȱ��棬������
	push rdx
	push r8
	push r9

	mov eax, [rbp+8D0h]     ;Header of Log
	cmp eax,40h				;С��40�Ķ����Ǹ�������
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
	;�ռ����������ڷ���ԭ����
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ret
hookfuncEnd ENDP

END