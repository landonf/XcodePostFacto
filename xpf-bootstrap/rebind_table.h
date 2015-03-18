/*
 * Author: Landon Fuller <landon@landonf.org>
 *
 * Copyright (c) 2015 Landon Fuller <landon@landonf.org>
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include <string>
#include <stdlib.h>

#include <mach-o/loader.h>

/** __DATA section containing XPF rebind data */
#define XPF_REBIND_SECTION "__xpf_rebind"

/**
 * Rebind table entry.
 */
struct xpf_rebind_entry {
    /** Name of the symbol to rebind. */
    const char *symbol;
    
    /** Image containing the symbol to be rebound. */
    const char *image;
    
    /** Location to store the original symbol address, or NULL. */
    void **original;

    /** Replacement symbol address */
    uintptr_t replacement;
};

/* Generate a compilation-unit-unique name for a single entry */
#define _XPF_REBIND_ENTRY_NAME_1(_prefix, _counter) _prefix ## _counter
#define _XPF_REBIND_ENTRY_NAME(_prefix, _counter) _XPF_REBIND_ENTRY_NAME_1(_prefix, _counter)

/**
 * Define an XPF rebind entry.
 *
 * @param _sym Original symbol name.
 * @param _img Image exporting @a _sym, or an empty string to treat all references to @a _sym as if they were single-level bound.
 * @param _orig If non-NULL, the location to store the original address. This value *must* be initialized to NULL, which is
 * used as a sentinal to avoid updating the original value more than once.
 * @param _replacement The new address to which all references to @a _sym will be bound.
 */
#define XPF_REBIND_ENTRY(_sym, _img, _orig, _replacement) \
    __attribute__((used)) \
    __attribute__((section(SEG_DATA ", " XPF_REBIND_SECTION))) \
    static struct xpf_rebind_entry _XPF_REBIND_ENTRY_NAME(__xpf_rebind, __COUNTER__) = { \
        .symbol = _sym, \
        .image = _img, \
        .original = _orig, \
        .replacement = _replacement \
    }