	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 12, 0	sdk_version 12, 3
	.globl	_main                           ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$16, %rsp
	movl	$0, -4(%rbp)
	leaq	L_.str(%rip), %rdi
	movb	$0, %al
	callq	_printf
	leaq	L_.str.1(%rip), %rdi
	leaq	-8(%rbp), %rsi
	movb	$0, %al
	callq	_scanf
	leaq	L_.str.2(%rip), %rdi
	movb	$0, %al
	callq	_printf
	leaq	L_.str.1(%rip), %rdi
	leaq	-12(%rbp), %rsi
	movb	$0, %al
	callq	_scanf
	movl	-8(%rbp), %edi
	movl	-12(%rbp), %esi
	callq	_gt
	movl	%eax, %esi
	leaq	L_.str.3(%rip), %rdi
	movb	$0, %al
	callq	_printf
	xorl	%eax, %eax
	addq	$16, %rsp
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_gt                             ## -- Begin function gt
	.p2align	4, 0x90
_gt:                                    ## @gt
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	movl	%edi, -4(%rbp)
	movl	%esi, -8(%rbp)
	movl	-4(%rbp), %eax
	cmpl	-8(%rbp), %eax
	jle	LBB1_2
## %bb.1:
	movl	-4(%rbp), %eax
	movl	%eax, -12(%rbp)                 ## 4-byte Spill
	jmp	LBB1_3
LBB1_2:
	movl	-8(%rbp), %eax
	movl	%eax, -12(%rbp)                 ## 4-byte Spill
LBB1_3:
	movl	-12(%rbp), %eax                 ## 4-byte Reload
	popq	%rbp
	retq
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
