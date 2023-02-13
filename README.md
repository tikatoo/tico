# tico - stack switching primitive for C #

Tico is a very small library,
providing the primitives necessary for changing the stack pointer.
Take note that the API is _not_ designed to be used directly,
but rather should be wrapped by a higher-level task library.

See [`include/tico.h`](include/tico.h) for API documentation.
The recommended method for including in your project
is to vendor this source code and use CMake's `add_subdirectory` command.


## Support ##

| Architecture    | Windows | Apple | Linux |
| --------------- | ------- | ----- | ----- |
| x86 (32-bit)    | --- | --- | --- |
| x86_64          | _planned_ | --- | GCC\* |
| AArch32 (armv7) | --- | --- | --- |
| AArch64 (armv8) | --- | --- | GCC\* |

> **\*** While Clang hasn't been tested for this target,
> if it truly is fully GCC-compatible then it is likely to work.

Since implementation of these primitives typically requires assembly crimes,
targets not listed cannot compile.
