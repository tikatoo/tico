
	.text

	.globl tico_init
	.globl tico_switch


# struct tico {             // sizeof = $24
#    uint64_t magic;        // 0(%rxx)
#    void *stack_resume;    // 8(%rxx)
#    void *stack_limit      // 16(%rxx)
# };


# suspended/resumable = magic_value =   0x171d100410031174
#             running = ~magic_value =  0xe8e2effbeffcee8b
magic_value:
	.quad 0x171d100410031174


# int tico_init(
#    void *stack, size_t ssize,
#    tico_main_t cb, void *ud,
#    tico_t **pnew
# );
tico_init:
	movq	magic_value(%rip), %r10
	movq	%r10, %r11
	notq	%r11

	# Construct context at high end of stack (into %rsi/second arg)
	subq	$24, %rsi
	addq	%rdi, %rsi
	movq	%r11, 0(%rsi)
	movq	%rdi, 16(%rsi)
	# Don't need stack in %rdi anymore,
	# so put ud there (need it in first arg for call)
	movq	%rcx, %rdi

	# Construct temp context on current stack
	subq	$24, %rsp
	movq	%rsp, %r9
	movq	%r10, 0(%r9)
	movq	%rsp, 16(%r9)

	# Callee-saved registers
	pushq	%rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	# Save pnew for future (used like pprev in switch)
	pushq	%r8

	# Switch into new stack
	movq	%rsp, 8(%r9)
	movq	%r9, 8(%rsi)
	movq	%rsi, %rsp

	# cb(ud, new)
	call	*%rdx

	# Behave exactly like tico_switch's restore (next = ret)
	movq	%rax, %rsi
	movl	$1, %eax	# return 1 to indicate done

	# Will segfault if ret == NULL
	cmp	$0, %rsi
	je	_tcs_restore

	# Make sure that the returned coroutine is valid
	movq	magic_value(%rip), %rax
lock	cmpxchg	%r11, 0(%rsi)
	jne	_tci_fallback_null
	movl	$1, %eax
	jmp	_tcs_restore

_tci_fallback_null:
	# Else, fallback to restore with ret == NULL (i.e. segfault)
	movq	$0, %rsi
	movl	$1, %eax
	jmp	_tcs_restore



# int tico_switch(
#    tico_t *self,
#    tico_t *next,
#    tico_t **pprev
# )
tico_switch:
	# Load magic value:
	#   %r10 = ready to resume
	#   %r11 = currently active
	movq	magic_value(%rip), %r10
	movq	%r10, %r11
	notq	%r11

	# Allocate a temp self, just in case.
	subq	$24, %rsp

	# If self == NULL, create a temp self
	# to allow proper return.
	cmp	$0, %rdi
	je	_tcs_temp_self

_tcs_test_self:
	# Check that self is currently active
	cmp	%r11, 0(%rdi)
	jne	_tcs_invalid_self

	# If not (self > sp > self->limit),
	# then error.
	cmp	%rdi, %rsp
	ja	_tcs_invalid_self_range
	cmp	16(%rdi), %rsp
	jb	_tcs_invalid_self_range

	# If next == NULL, handle initial yield
	cmp	$0, %rsi
	je	_tcs_load_next

_tcs_test_next:
	# Try set next->magic to currently active,
	# iff next->magic is ready.
	movq	%r10, %rax
lock	cmpxchg	%r11, 0(%rsi)
	jne	_tcs_invalid_next

	# Set up normal "did a yield" return code
	# (done here so _tci_return can reuse _tcs_restore and return 1)
	movl	$0, %eax

_tcs_save:
	# Callee-saved registers
	pushq	%rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	# Save pprev for future
	pushq	%rdx
	# Save self stack pointer and make resumable
	movq	%r10, 0(%rdi)
	movq	%rsp, 8(%rdi)

_tcs_restore:
	# Restore next stack pointer
	movq	8(%rsi), %rsp
	# Restore out pointer to previous coroutine
	popq	%rdx
	# Pop callee-saved registers
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	popq	%rbp

	# Notify what the previous coroutine was
	cmp	$0, %rdx
	je	_tcs_ret
	movq	%rdi, (%rdx)
_tcs_ret:
	# Switch means coroutine yields, not returns
	addq	$24, %rsp
	ret


_tcs_load_next:
	# Load next from self
	movq	8(%rdi), %rsi
	jmp	_tcs_test_next


_tcs_temp_self:
	# Setup temp self
	movq	%r10, 0(%rsp)
	movq	%rsp, 16(%rsp)
	movq	%rsp, %rdi
	# endif unless next == NULL
	cmp	$0, %rsi
	jne	_tcs_test_next
	# next == NULL, which is bad
	movl	$-1, %eax
	addq	$24, %rsp
	ret


_tcs_invalid_next:
	# Next is probably already running.
	# Need to undo changes to self,
	# then return a specific error code.
	movq	%r11, 0(%rdi)
	movl	$-2, %eax
	addq	$24, %rsp
	ret

_tcs_invalid_self_range:
	# Restore magic for self
	movq	%r11, 0(%rdi)
_tcs_invalid_self:
	# Return error code
	movl	$-1, %eax
	addq	$24, %rsp
	ret
