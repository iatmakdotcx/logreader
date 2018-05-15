
.data
;extern domyWork : proc
extern domyWork_2 : proc

.CODE

; 1 – data page，用于表示：堆表或聚集索引的叶子节点
; 2 – index page，用于表示：聚集索引的中间节点或者非聚集索引中所有级别的节点
; 3 – text mix page，4 – text tree page，用于存储类型为文本的大对象数据
; 7 – sort page，用于存储排序操作的中间数据结果
; 8 – GAM page，用于存储全局分配映射数据GAM(Global Allocation Map），每一个数据文件被分割成4GB的空间块（Chunk），每一个Chunk都对应一个GAM数据页，GAM数据页出现在数据文件特定的位置处，一个bit映射当前Chunk中的一个区。
; 9 – SGAM page，用于存储SGAM页(Shared GAM）
; 10 – IAM page，用于存储IAM页（Index Allocation Map）
; 11 – PFS page，用于存储PFS页（Page Free Space）
; 13 – boot page，用于存储数据库的信息，只有一个Page，Page的标识符是：db_id:1:9，
; 15 – file header page，存储数据文件的数据，数据库的每一个文件都有一个，Page的编号是0。
; 16 – diff map page，存储差异备份的映射，表示从上一次完整备份之后，该区的数据是否修改过。
; 17 – ML map page，表示从上一次备份之后，在大容量日志（bulk-Logged）操作期间，该区的数据是否被修改过，This is what allows you to switch to bulk-logged mode for bulk-loads and index rebuilds without worrying about breaking a backup chain. 
; 18 – a page that's be deallocated by DBCC CHECKDB during a repair operation.
; 19 – the temporary page that ALTER INDEX … REORGANIZE (or DBCC INDEXDEFRAG) uses when working on an index.
; 20 – a page pre-allocated as part of a bulk load operation, which will eventually be formatted as a ‘real' page.

hookfunc PROC
	; jmp过来的，堆栈完好，先直接调用
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
	push rbp
	sub rsp,20h  ; shadow space

	;仅记录data页数据
	mov al,[rcx+1]
	cmp al,1
	jz @doow
	cmp al,3
	jz @doow
	jmp @tugi
	@doow:
	;[rbp+58h] ;XdesRMReadWrite object 

	mov rcx, [rbp+58h]		;XdesRMReadWrite object 
	mov rdx, [rbp+0FB0h]		;new raw data
	call domyWork_2

	@tugi:
	add rsp,20h	
	pop rbp
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
	mov dword ptr [rsp+20h],r9d

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
	push rbp
	sub rsp,20h  ; shadow space

	;仅记录data页数据
	mov al,[rcx+1]
	cmp al,1
	jz @doow
	cmp al,3
	jz @doow
	jmp @tugi
	@doow:

	;[rbp+6C0]   ;XdesRMReadWrite object 
	;[rbp+550] 新的内容
	mov rcx, [rbp+6C0h]		;XdesRMReadWrite object 
	mov rdx, [rbp+550h]		;new raw data
	call domyWork_2

	@tugi:
	add rsp,20h
	pop rbp
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
		
	push rbp
	push r12
	push r13
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