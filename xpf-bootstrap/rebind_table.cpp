/*
 * Author: Landon Fuller <landon@landonf.org>
 *
 * Copyright (c) 2015 Landon Fuller <landon@landonf.org>
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
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

#include "rebind_table.h"


namespace xpf {

/* Refer to the corresponding rebind entry below for documentation. */
extern "C"  unsigned int DVTCurrentSystemVersionAvailabilityForm();
static unsigned int Yosemite_DVTCurrentSystemVersionAvailabilityForm () { return 101000; }
extern "C"  void *OBJC_CLASS_$_NSView;

/**
 * All symbol rebindings necessary to bootstrap Xcode.
 */
const rebind_entry bootstrap_rebind_table[] = {
    /*
     * Xcode 6.3 enables/disables broken 10.9 compatibility code based on the current system version; we supply
     * a patch that claims to be Yosemite 10.0.0.
     *
     * The version itself is cached in a number of locations after it is computed, necessitating that our patch
     * be in place before it's called by anyone.
     *
     * TODO: We may want to investigate patching the code in-place, or finding an alternative method for dealing
     * with local DVTFoundation references to DVTCurrentSystemVersionAvailabilityForm().
     */
    { "_DVTCurrentSystemVersionAvailabilityForm",  "DVTFoundation",   (uintptr_t) &Yosemite_DVTCurrentSystemVersionAvailabilityForm },
    { "_OBJC_CLASS_$_NSVisualEffectView",          "AppKit",          (uintptr_t) OBJC_CLASS_$_NSView }
};

const size_t bootstrap_rebind_table_length = sizeof(bootstrap_rebind_table) / sizeof(bootstrap_rebind_table[0]);

} /* namespace xpf */
