
.data
;extern domyWork : proc
extern domyWork_2 : proc

.CODE

; 1 �C data page�����ڱ�ʾ���ѱ��ۼ�������Ҷ�ӽڵ�
; 2 �C index page�����ڱ�ʾ���ۼ��������м�ڵ���߷Ǿۼ����������м���Ľڵ�
; 3 �C text mix page��
; 4 �C text tree page�����ڴ洢����Ϊ�ı��Ĵ��������
; 7 �C sort page�����ڴ洢����������м����ݽ��
; 8 �C GAM page�����ڴ洢ȫ�ַ���ӳ������GAM(Global Allocation Map����ÿһ�������ļ����ָ��4GB�Ŀռ�飨Chunk����ÿһ��Chunk����Ӧһ��GAM����ҳ��GAM����ҳ�����������ļ��ض���λ�ô���һ��bitӳ�䵱ǰChunk�е�һ������
; 9 �C SGAM page�����ڴ洢SGAMҳ(Shared GAM��
; 10 �C IAM page�����ڴ洢IAMҳ��Index Allocation Map��
; 11 �C PFS page�����ڴ洢PFSҳ��Page Free Space��
; 13 �C boot page�����ڴ洢���ݿ����Ϣ��ֻ��һ��Page��Page�ı�ʶ���ǣ�db_id:1:9��
; 15 �C file header page���洢�����ļ������ݣ����ݿ��ÿһ���ļ�����һ����Page�ı����0��
; 16 �C diff map page���洢���챸�ݵ�ӳ�䣬��ʾ����һ����������֮�󣬸����������Ƿ��޸Ĺ���
; 17 �C ML map page����ʾ����һ�α���֮���ڴ�������־��bulk-Logged�������ڼ䣬�����������Ƿ��޸Ĺ���This is what allows you to switch to bulk-logged mode for bulk-loads and index rebuilds without worrying about breaking a backup chain. 
; 18 �C a page that's be deallocated by DBCC CHECKDB during a repair operation.
; 19 �C the temporary page that ALTER INDEX �� REORGANIZE (or DBCC INDEXDEFRAG) uses when working on an index.
; 20 �C a page pre-allocated as part of a bulk load operation, which will eventually be formatted as a ��real' page.

hookfunc PROC
	; jmp�����ģ���ջ��ã���ֱ�ӵ���
	;pagedata = [[rcx]]
	;XdesRMFull = p9 = [rsp+48]
	;raw=[[[rbp+30]]+8]
	;raw=[[[rsp+70]]+8]
	push rbp
	push rax
	push rbx
	push rcx 
	push rdx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
	push rdi
	push rsi
	
	sub rsp,20h  ; shadow space

	;����¼dataҳ����
	mov rcx,[rcx]
	mov rcx,[rcx]
	mov al,[rcx+1]
	cmp al,1
	jz @doow
	cmp al,3
	jz @doow
	cmp al,4
	jz @doow
	jmp @tugi
	@doow:	

	mov rcx, [rsp+0E0h]		    ;p9: <&XdesRMFull::`vftable'>
	mov rdx, [rsp+108h]			;p14: new raw data
	call domyWork_2

	@tugi:
	add rsp,20h	
	pop rsi
	pop rdi
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rbx
	pop rax
	pop rbp

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
hookfuncEnd ENDP



END