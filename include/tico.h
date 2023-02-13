/**
 * Copyright 2023 Tika <tika@tika.to>. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

#ifndef TICO_HEADER
#define TICO_HEADER

#include <stddef.h>


#define TICO_ENEXT      (int)(-2)
#define TICO_ESELF      (int)(-1)
#define TICO_SUSPENDED  (int)(0)
#define TICO_RETURNED   (int)(1)


/**
 * Opaque type representing coroutine information.
 * A `tico_t *` is a handle to a coroutine.
 */
typedef struct tico tico_t;

/**
 * Type of a coroutine main function.
 *
 * Such a function should call `tico_switch(self, NULL, ...)` ASAP.
 * This call will suspend the coroutine and return from `tico_init`.
 * If a non-NULL next is passed to the first call to `tico_switch`,
 * or if the main function returns before calling `tico_switch`,
 * then the caller of `tico_init` cannot be resumed.
 *
 * Generally, a caller of tico will only write one such main function.
 * The userdata argument `data` will usually include a pointer to a
 * more application-appropriate coroutine function,
 * and the one implementation of this signature will defer to that.
 *
 * The function MUST return a valid, suspended, non-NULL coroutine. Failing to
 * meet this requirement causes undefined behaviour (though likely a segfault).
 *
 * - data: Arbitrary pointer to supplied userdata.
 * - self: Handle to the current coroutine.
 *
 * Returns tico_t *: Handle to a coroutine to resume. That coroutine's call to
 *                   `tico_switch` (or `tico_init`) will return `TICO_RETURNED`.
 */
typedef tico_t *(*tico_main_t)(void *data, tico_t *self);

/**
 * Initialise a new coroutine with a given stack.
 *
 * The caller must allocate the stack, and include the appropriate size.
 * The `stack` argument is a pointer to the low address of the allocated stack,
 * regardless of how the machine prefers to grow the stack. The passed size
 * does not inherently limit the stack or provide useful feedback, however
 * it may be used to find the bottom of the stack, and if more stack space is
 * used then `tico_switch` may reject the handle as `self`.
 *
 * There are certain requirements on the behaviour of the main function `cb` -
 * see the documentation for `tico_main_t`.
 *
 * - stack: Pointer to the low end of the pre-allocated stack.
 * - ssize: Size (in bytes) of the pre-allocated stack.
 * - cb: Main function for the coroutine.
 * - data: Pointer passed as the first argument to `cb`.
 * - pnew: On return, `*pnew` will be a handle to the coroutine that just
 *         suspended and caused `tico_init` to return. If `cb` calls
 *         `tico_switch` with `next == NULL`, then `*pnew` will be a handle
 *         to the coroutine that `tico_init` created.
 *
 * Returns int: See `tico_switch`.
 */
int tico_init(
    void *stack, size_t ssize,
    tico_main_t cb, void *data,
    tico_t **pnew
);


/**
 * Switch from the current coroutine (`self`) into another (`next`).
 *
 * This function requires a handle to the currently running coroutine.
 * This handle is typically obtained via the `self` argument to a `tico_main_t`.
 * Generally, this should be passed via an argument to each function that
 * may suspend the coroutine (or, more likely, a higher-level framework will
 * have some kind of task context that is passed as an argument, which includes
 * the `self` handle). Callers desiring implicit suspend (like Go's goroutines)
 * can safely store this handle in a `thread_local` (though must be careful
 * to ensure that this variable is kept up-to-date).
 *
 * On call, the current coroutine will be suspended. When the coroutine is
 * resumed, `tico_switch` will return.
 *
 * - self: Handle to the active coroutine. NULL may be passed, though this is
 *         discouraged outside of the process/thread's main function.
 * - next: Handle to the coroutine to resume. If this is the first suspend of
 *         the current coroutine, this may be NULL.
 * - pprev: On return, `*pprev` will be a handle to the coroutine that just
 *          suspended and caused `tico_switch` to return.
 *
 * Returns TICO_ENEXT: The passed `next` cannot be resumed. If `next` is a
 *                     non-NULL, otherwise valid coroutine handle, this return
 *                     value indicates that `next` is already running (likely
 *                     on another thread).
 * Returns TICO_ESELF: The passed `self` is not the currently active coroutine.
 * Returns TICO_SUSPENDED: The current coroutine was suspended and subsequently
 *                         resumed. The coroutine given in `*pprev` has been
 *                         suspended, and should eventually be resumed.
 * Returns TICO_RETURNED: The current coroutine was suspended and subsequently
 *                        resumed. The coroutine given in `*pprev` has returned,
 *                        and associated resources should be freed. The
 *                        behaviour of attempting to resume `*pprev` is
 *                        undefined.
 */
int tico_switch(
    tico_t *self,
    tico_t *next,
    tico_t **pprev
);


#endif // include guard
