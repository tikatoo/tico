// Copyright 2023 Tika <tika@tika.to>. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.


	.text

	.globl tico_init
	.globl tico_switch


// suspended/resumable = magic_value =   0x171d100410031174
//             running = ~magic_value =  0xe8e2effbeffcee8b
magic_value:
	.quad 0x171d100410031174


// int tico_init(
//    void *stack,      // x0
//    size_t ssize,     // x1
//    tico_main_t cb,   // x2
//    void *data,       // x3
//    tico_t **pnew     // x4
// );
tico_init:
	stp	x29, lr, [sp, #-16]!
	mov	x29, sp

	// Pre-load magic values
	ldr	x10, magic_value
	orn	x11, xzr, x10

	// Create new coroutine header
	sub	x1, x1, #32
	add	x1, x1, x0
	str	x11, [x1, #0]
	str	x0, [x1, #16]
	// arg1 of cb = data
	mov	x0, x3

	// Create temp self
	sub	sp, sp, #32
	mov	x12, sp
	str	x10, [x12, #0]
	str	x12, [x12, #16]
	// Callee-saved registers
	stp	x19, x20, [sp, #-16]!
	stp	x21, x22, [sp, #-16]!
	stp	x23, x24, [sp, #-16]!
	stp	x25, x26, [sp, #-16]!
	stp	x27, x28, [sp, #-16]!
	stp	x29, x4, [sp, #-16]!    // Also save a copy of pnew

	// Save current stack info
	mov	x9, sp
	str	x9, [x12, #8]
	str	x12, [x1, #8]
	// Switch to new stack
	mov	sp, x1
	mov	x19, x1         // Will need coroutine handler later

	// cb(data, newco)
	blr	x2
	// x1 is next (returned) and x3 is self (saved)
	mov	x1, x0
	mov	x3, x19
	// tico_switch returns TICO_RETURNED
	mov	w0, #1
	// If return NULL, segfault
	cbz	x1, _tcs_restore

	// Double-check that ret is valid
	ldr	x10, magic_value
	ldxr	x9, [x1, #0]
	cmp	x9, x10
	b.ne	_tci_fallback_null
	orn	x11, xzr, x10
	stxr	w9, x11, [x1, #0]
	cbz	w9, _tcs_restore        // Restore if possible
_tci_fallback_null:
	// ret is invalid, same behaviour as return NULL
	mov	x1, #0
	b	_tcs_restore



// int tico_switch(
//    tico_t *self,     // x0
//    tico_t *next,     // x1
//    tico_t **pprev    // x2
// );
tico_switch:
	stp	x29, lr, [sp, #-16]!
	mov	x29, sp

	// Pre-load magic values
	ldr	x10, magic_value
	orn	x11, xzr, x10
	// Allocate a temp self, just in case.
	sub	sp, sp, #32

	// If self == NULL, create a temp self
	// to allow proper return.
	cbz	x0, _tcs_temp_self
_tcs_test_self:
	// Check that self is the active coroutine.
	// a) self->magic must be currently active
	ldr	x9, [x0, #0]
	cmp	x9, x11
	b.ne	_tcs_invalid_self
	// b) self > sp > self->limit
	cmp	sp, x0
	b.gt	_tcs_invalid_self_range
	ldr	x9, [x0, #16]
	cmp	sp, x9
	b.lt	_tcs_invalid_self_range

	// If next == NULL, handle initial yield
	cbz	x1, _tcs_load_next
_tcs_test_next:
	// Try set next->magic to currently active,
	// iff next->magic is ready.
	ldxr	x9, [x1, #0]
	cmp	x9, x10
	b.ne	_tcs_invalid_next
	stxr	w9, x11, [x1, #0]
	cbnz	w9, _tcs_invalid_next

	// Setup return TICO_SUSPENDED
	// (we want to reuse _tcs_restore for other return values)
	// And now x3 is self
	mov	x3, x0
	mov	w0, #0
_tcs_save:
	// Callee saved registers
	stp	x19, x20, [sp, #-16]!
	stp	x21, x22, [sp, #-16]!
	stp	x23, x24, [sp, #-16]!
	stp	x25, x26, [sp, #-16]!
	stp	x27, x28, [sp, #-16]!
	stp	x29, x2, [sp, #-16]!    // Also save a copy of pprev for later
	// Save stack pointer and make self resumable
	mov	x9, sp
	stp	x10, x9, [x3, #0]

_tcs_restore:
	// Restore stack pointer of next.
	// Now, we're returning from next's call to tico_switch.
	ldr	x9, [x1, #8]
	mov	sp, x9
	// Load callee-saved registers
	ldp	x29, x2, [sp], #16
	ldp	x27, x28, [sp], #16
	ldp	x25, x26, [sp], #16
	ldp	x23, x24, [sp], #16
	ldp	x21, x22, [sp], #16
	ldp	x19, x20, [sp], #16

	// If pprev != NULL, output just-suspended coroutine handle
	cbz	x2, _tcs_ret
	str	x3, [x2]
_tcs_ret:
	mov	sp, x29
	ldp	x29, lr, [sp], #16
	ret


_tcs_load_next:
	// next == NULL, probably first call in coroutine main.
	// Try retrieving next from self.
	ldr	x1, [x0, #8]
	b	_tcs_test_next

_tcs_temp_self:
	// self == NULL, so construct a temporary self so that
	// this stack can be resumed.
	mov	x0, sp
	str	x10, [x0, #0]
	str	x0, [x0, #16]
	cbnz	x1, _tcs_test_next
	// If next == NULL too, then that was wrong
	mov	w0, #-1
	mov	sp, x29
	ldp	x29, lr, [sp], #16
	ret

_tcs_invalid_next:
	clrex
	// next wasn't resumable
	mov	w0, #-2
	mov	sp, x29
	ldp	x29, lr, [sp], #16
	ret

_tcs_invalid_self_range:
_tcs_invalid_self:
	// self isn't the currently-running coroutine
	mov	w0, #-1
	mov	sp, x29
	ldp	x29, lr, [sp], #16
	ret
