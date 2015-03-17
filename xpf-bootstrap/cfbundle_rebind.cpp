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

#include "cfbundle_rebind.h"

namespace xpf {

/*
 * HIServices checks for a LSMinimumSystemVersion in the application bundle, and
 * if out-of-range for the host, helpfully aborts.
 *
 * We patch out the relevant CFBundle* APIs here, rewriting the LSMinimumSystemVersion
 * to 10.9.
 */

static CFStringRef kLSMinimumSystemVersionKey = CFSTR("LSMinimumSystemVersion");
static CFStringRef kSupportedSystemVersion = CFSTR("10.9");

/**
 * Return a representation of @a infoDictionary where kLSMinimumSystemVersionKey, if set, has
 * been patched to be equal to 10.9.
 */
static CFDictionaryRef xpf_patch_info_dictionary (CFDictionaryRef info) {
    if (!CFDictionaryContainsKey(info, kLSMinimumSystemVersionKey))
        return info;
    
    CFMutableDictionaryRef patched = CFDictionaryCreateMutableCopy(nullptr, 0, info);
    CFDictionarySetValue(patched, kLSMinimumSystemVersionKey, kSupportedSystemVersion);
    CFAutorelease(patched);
    
    return patched;
}

/* Patch CFBundleGetValueForInfoDictionaryKey() */
static CFTypeRef (*orig_CFBundleGetValueForInfoDictionaryKey) (CFBundleRef bundle, CFStringRef key);
static CFTypeRef xpf_CFBundleGetValueForInfoDictionaryKey (CFBundleRef bundle, CFStringRef key) {
    if (!CFEqual(key, kLSMinimumSystemVersionKey))
        return orig_CFBundleGetValueForInfoDictionaryKey(bundle, key);

    return kSupportedSystemVersion;
}


/* Patch CFBundleGetInfoDictionary() */
static CFDictionaryRef (*orig_CFBundleGetInfoDictionary) (CFBundleRef bundle);
static CFDictionaryRef xpf_CFBundleGetInfoDictionary (CFBundleRef bundle) {
    return xpf_patch_info_dictionary(orig_CFBundleGetInfoDictionary(bundle));
}

/* Patch CFBundleGetLocalInfoDictionary() */
static CFDictionaryRef (*orig_CFBundleGetLocalInfoDictionary)(CFBundleRef bundle);
static CFDictionaryRef xpf_CFBundleGetLocalInfoDictionary (CFBundleRef bundle) {
    return xpf_patch_info_dictionary(orig_CFBundleGetInfoDictionary(bundle));
}


/**
 * All CFBundle rebindings
 */
const rebind_entry cfbundle_rebind_table[] = {
    { "_CFBundleGetValueForInfoDictionaryKey",  "CoreFoundation",   (void **) &orig_CFBundleGetValueForInfoDictionaryKey,   (uintptr_t) &xpf_CFBundleGetValueForInfoDictionaryKey },
    { "_CFBundleGetInfoDictionary",             "CoreFoundation",   (void **) &orig_CFBundleGetInfoDictionary,              (uintptr_t) &xpf_CFBundleGetInfoDictionary },
    { "_CFBundleGetLocalInfoDictionary",        "CoreFoundation",   (void **) &orig_CFBundleGetLocalInfoDictionary,         (uintptr_t) &xpf_CFBundleGetLocalInfoDictionary },
};

/**
 * Length of the CFBundle rebind table.
 */
const size_t cfbundle_rebind_table_length = sizeof(cfbundle_rebind_table) / sizeof(cfbundle_rebind_table[0]);

}