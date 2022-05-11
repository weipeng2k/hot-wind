	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 12, 0	sdk_version 12, 3
	.intel_syntax noprefix
	.globl	_main                           ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	sub	rsp, 16
	mov	dword ptr [rbp - 4], 0
	lea	rdi, [rip + L_.str]
	mov	al, 0
	call	_printf
	lea	rdi, [rip + L_.str.1]
	lea	rsi, [rbp - 8]
	mov	al, 0
	call	_scanf
	lea	rdi, [rip + L_.str.2]
	mov	al, 0
	call	_printf
	lea	rdi, [rip + L_.str.1]
	lea	rsi, [rbp - 12]
	mov	al, 0
	call	_scanf
	mov	edi, dword ptr [rbp - 8]
	mov	esi, dword ptr [rbp - 12]
	call	_gt
	mov	esi, eax
	lea	rdi, [rip + L_.str.3]
	mov	al, 0
	call	_printf
	xor	eax, eax
	add	rsp, 16
	pop	rbp
	ret
	.cfi_endproc
                                        ## -- End function
	.globl	_gt                             ## -- Begin function gt
	.p2align	4, 0x90
_gt:                                    ## @gt
	.cfi_startproc
## %bb.0:
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
	mov	dword ptr [rbp - 4], edi
	mov	dword ptr [rbp - 8], esi
	mov	eax, dword ptr [rbp - 4]
	cmp	eax, dword ptr [rbp - 8]
	jle	LBB1_2
## %bb.1:
	mov	eax, dword ptr [rbp - 4]
	mov	dword ptr [rbp - 12], eax       ## 4-byte Spill
	jmp	LBB1_3
LBB1_2:
	mov	eax, dword ptr [rbp - 8]
	mov	dword ptr [rbp - 12], eax       ## 4-byte Spill
LBB1_3:
	mov	eax, dword ptr [rbp - 12]       ## 4-byte Reload
	pop	rbp
	ret
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
L_.str:                                 ## @.str
	.asciz	"\350\276\223\345\205\245\347\254\254\344\270\200\344\270\252\346\225\260\357\274\232"

L_.str.1:                               ## @.str.1
	.asciz	"%d"

L_.str.2:                               ## @.str.2
	.asciz	"\350\276\223\345\205\245\347\254\254\344\272\214\344\270\252\346\225\260\357\274\232"

L_.str.3:                               ## @.str.3
	.asciz	"\350\276\203\345\244\247\347\232\204\346\225\260\346\230\257\357\274\232%d\n"

.subsections_via_symbols
