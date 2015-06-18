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

#include "rebind_table.h"
#include "XPFLog.h"

#include <spawn.h>
#include <sys/qos.h>
#include <dispatch/dispatch.h>
#include <Block.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <regex>

#define XPF_LIBSYSTEM_PATH "/usr/lib/libSystem.B.dylib"
#define XPF_FOUNDATION_PATH "/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"
#define XPF_APPKIT_PATH "/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit"
#define XPF_CF_PATH "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"


namespace xpf {

/*
 * Xcode 6.3 enables/disables broken 10.9 compatibility code based on the current system version; we supply
 * a patch that claims to be Yosemite 10.0.0.
 *
 * The version itself is cached in a number of locations after it is computed, necessitating that our patch
 * be in place before it's called by anyone.
 */
static unsigned int Yosemite_DVTCurrentSystemVersionAvailabilityForm () { return 101000; }
XPF_REBIND_ENTRY("_DVTCurrentSystemVersionAvailabilityForm", "@rpath/DVTFoundation.framework/Versions/A/DVTFoundation", NULL, (uintptr_t) &Yosemite_DVTCurrentSystemVersionAvailabilityForm);

static CFDictionaryRef Yosemite__CFCopySystemVersionDictionary () {
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(result, CFSTR("Build"), CFSTR("Build"));
    CFDictionarySetValue(result, CFSTR("Version"), CFSTR("Version"));
    
    CFDictionarySetValue(result, CFSTR("FullVersionString"), CFSTR("Version 10.10.0 (Build 13F1077)"));
    CFDictionarySetValue(result, CFSTR("ProductCopyright"), CFSTR("1983-2015 Apple Inc."));
    CFDictionarySetValue(result, CFSTR("ProductName"), CFSTR("Mac OS X"));
    CFDictionarySetValue(result, CFSTR("ProductUserVisibleVersion"), CFSTR("10.9.5"));

    CFDictionarySetValue(result, CFSTR("ProductVersion"), CFSTR("10.10.0"));
    CFDictionarySetValue(result, CFSTR("ProductBuildVersion"), CFSTR("14A389"));

    return result;
}
XPF_REBIND_ENTRY("__CFCopySystemVersionDictionary", XPF_CF_PATH, nullptr, (uintptr_t) &Yosemite__CFCopySystemVersionDictionary);
    
/*
 * We have to hook posix_spawn to ensure that our DYLD_* variables are conveyed to child processes.
 */
static int (*orig_posix_spawn) (pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]);
static int (*orig_posix_spawnp) (pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]);
    
static int xpf_posix_spawn_common (pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[], bool spawnp) {
    /* Find the path to our binary */
    Dl_info di;
    if (dladdr((const void *) &xpf_posix_spawn_common, &di) == 0) {
        XPFLog("Could not fetch Dl_info for our own image: %s", dlerror());
        abort();
    }

    /* Formulate the expected DYLD_INSERT_LIBRARIES values */
    auto insert_envp_value = std::string(di.dli_fname);
    auto insert_envp_set_variable = std::string("DYLD_INSERT_LIBRARIES=");
    auto insert_envp_full_string = insert_envp_set_variable + insert_envp_value;
    
    /* Determine the size of the envp array and allocate our replacement. */
    size_t envp_count = 0;
    for (envp_count = 0; envp[envp_count] != NULL; envp_count++);
    
    char **new_envp = (char **) malloc(sizeof(char *) * envp_count) + 1 /* in case we need to insert a DYLD_* variable */ + 1 /* trailing NULL */;

    /* Check for our DYLD_INSERT_LIBRARIES value */
    bool addInsertLibrariesVar = true;
    for (size_t i = 0; i < envp_count; i++) {
        std::string value = envp[i];
        
        /* If the variable isn't DYLD_INSERT_LIBRARIES -- or the value is already equal to our expected value -- we can just copy it directly. */
        if (strncmp("DYLD_INSERT_LIBRARIES=", value.c_str(), sizeof("DYLD_INSERT_LIBRARIES=") - 1) != 0 || insert_envp_full_string == value) {
            new_envp[i] = strdup(value.c_str());
            continue;
        } else {
            /* Otherwise, we know we found an DYLD_INSERT_LIBRARIES value, and we'll update it below. */
            addInsertLibrariesVar = false;
        }
        
        /* Remove the leading 'DYLD_INSERT_LIBRARIES=' prefix so that we can examine the set of paths */
        auto path_elems_string = value;
        path_elems_string.erase(0, insert_envp_set_variable.size());
        
        /* Search for our libraries path within the DYLD_INSERT_LIBRARIES path elements. */
        std::regex path_elem_regex(":?([^:]+):?");
        bool needs_lib_path_appended = true;
        for (auto i = std::sregex_iterator(path_elems_string.begin(), path_elems_string.end(), path_elem_regex, std::regex_constants::match_default); i != std::sregex_iterator(); i++) {
            auto elem = (*i)[1].str();
            
            /* If we find our library path, we don't need to append it below. */
            if (elem == insert_envp_value) {
                needs_lib_path_appended = false;
                break;
            }
        }
        
        /* Append and set the value */
        if (needs_lib_path_appended) {
            value += ":" + insert_envp_value;
        }
        
        new_envp[i] = strdup(value.c_str());
    }
    
    /* DYLD_INSERT_LIBRARIES is not set at all; we just need to add it (space for this variable is already allocated in new_envp) */
    if (addInsertLibrariesVar) {
        new_envp[envp_count] = strdup(insert_envp_full_string.c_str());
        envp_count++;
    }
    
    /* Add terminating NULL */
    new_envp[envp_count] = NULL;
    
    int result;
    if (spawnp) {
        result = orig_posix_spawnp(pid, path, file_actions, attrp, argv, new_envp);
    } else {
        result = orig_posix_spawn(pid, path, file_actions, attrp, argv, new_envp);
    }
    
    for (size_t i = 0; i < envp_count; i++)
        free(new_envp[i]);
    
    free(new_envp);
    return result;
}

static int xpf_posix_spawn (pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]) {
    return xpf_posix_spawn_common(pid, path, file_actions, attrp, argv, envp, true);
}

static int xpf_posix_spawnp (pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]) {
    return xpf_posix_spawn_common(pid, path, file_actions, attrp, argv, envp, false);
}

XPF_REBIND_ENTRY("_posix_spawn", XPF_LIBSYSTEM_PATH, (void **) &orig_posix_spawn, (uintptr_t) &xpf_posix_spawn);
XPF_REBIND_ENTRY("_posix_spawnp", XPF_LIBSYSTEM_PATH, (void **)  &orig_posix_spawnp, (uintptr_t) &xpf_posix_spawnp);

/*
 * NSVisualEffectView is used on Yosemite to produce the ugly blended translucency views. We provide a simple
 * no-op replacement.
 */
#if !defined(__i386__) || IPHONE_OS_TARGET
extern "C" void *OBJC_CLASS_$_XPF_NSVisualEffectView;
XPF_REBIND_ENTRY("_OBJC_CLASS_$_NSVisualEffectView", XPF_APPKIT_PATH, NULL, (uintptr_t) &OBJC_CLASS_$_XPF_NSVisualEffectView);
#endif

/*
 * Yosemite provides QoS extensions to posix_spawn() -- we can simply no-op the implementation.
 */
static int xpf_posix_spawnattr_set_qos_class_np (posix_spawnattr_t *attr, qos_class_t qos_class) { return 0; }
XPF_REBIND_ENTRY("_posix_spawnattr_set_qos_class_np", XPF_LIBSYSTEM_PATH, NULL, (uintptr_t) &xpf_posix_spawnattr_set_qos_class_np);

// XXX - Work around a bug in our QoS queue handling.
static void (*orig_dispatch_async_f) (dispatch_queue_t queue, dispatch_block_t block);
static void xpf_dispatch_async_f (dispatch_queue_t queue, dispatch_block_t block) {
    if (queue == nullptr) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            XPFLog("ERROR: dispatch_async_f() called with a NULL queue. This is due to a bug in our handling of Xcode's QoS queue lookup. Substituting a default-priority queue. This message will be logged only once.");
        });
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return orig_dispatch_async_f(queue, block);
}

XPF_REBIND_ENTRY("_dispatch_async_f", XPF_LIBSYSTEM_PATH, (void **) &orig_dispatch_async_f, (uintptr_t) &xpf_dispatch_async_f);

/* Yosemite supports passing QoS constants to dispatch_get_global_queue() -- we have to map these to standard dispatch queue priorities */
static dispatch_queue_t (*orig_dispatch_get_global_queue) (long priority, unsigned long flags);
static dispatch_queue_t xpf_dispatch_get_global_queue (long priority, unsigned long flags) {
    long mapped_priority;
    switch (priority) {
        case QOS_CLASS_USER_INTERACTIVE:
            mapped_priority = DISPATCH_QUEUE_PRIORITY_HIGH;
            break;
            
        case QOS_CLASS_USER_INITIATED:
            mapped_priority = DISPATCH_QUEUE_PRIORITY_DEFAULT;
            break;
            
        case QOS_CLASS_BACKGROUND:
            mapped_priority = DISPATCH_QUEUE_PRIORITY_BACKGROUND;
            break;
            
        case QOS_CLASS_UTILITY:
            mapped_priority = DISPATCH_QUEUE_PRIORITY_LOW;
            break;
            
        case DISPATCH_QUEUE_PRIORITY_BACKGROUND:
        case DISPATCH_QUEUE_PRIORITY_DEFAULT:
        case DISPATCH_QUEUE_PRIORITY_HIGH:
        case DISPATCH_QUEUE_PRIORITY_LOW:
            mapped_priority = priority;
            break;
            
        default:
            mapped_priority = DISPATCH_QUEUE_PRIORITY_DEFAULT;
            break;
    }
    
    dispatch_queue_t queue = orig_dispatch_get_global_queue(mapped_priority, flags);
    if (queue == nullptr) {
        XPFLog("Failed to fetch a global queue with priority=%lu, flags=%lu. Falling back on default queue!", priority, flags);
        return orig_dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    return queue;
}
XPF_REBIND_ENTRY("_dispatch_get_global_queue", XPF_LIBSYSTEM_PATH, (void **) &orig_dispatch_get_global_queue, (uintptr_t) &xpf_dispatch_get_global_queue);
    
/*
 * Yosemite's libdispatch provides a set of block utility functions that support creating a custom block type that allows
 * the assignation of operations over GCD-specific block attributes.
 *
 * While some flags are ignorable, others, such as DISPATCH_BLOCK_BARRIER, define semantic invariants that we must
 * emulate. Currently, we log those instances; in the future, we'll need to attach attributes to the blocks in question,
 * and hook additional dispatch_* APIs to implement handling of those attributes.
 *
 * Alternatively, we could actually provide a backported copy of 10.10's libdispatch :-)
 */
static dispatch_block_t xpf_dispatch_block_create_with_qos_class (dispatch_block_flags_t flags, dispatch_qos_class_t qos_class, int relative_priority, dispatch_block_t block) {
    if ((flags & DISPATCH_BLOCK_BARRIER) == DISPATCH_BLOCK_BARRIER) {
        XPFLog("Warning! Ignoring unimplemented DISPATCH_BLOCK_BARRIER in dispatch_block_create(); this may result in thread-safety issues (such as deadlocks and crashes).");
    }
    return Block_copy(block);
}
XPF_REBIND_ENTRY("_dispatch_block_create_with_qos_class", XPF_LIBSYSTEM_PATH, NULL, (uintptr_t) &xpf_dispatch_block_create_with_qos_class);

static dispatch_block_t xpf_dispatch_block_create (dispatch_block_flags_t flags, dispatch_block_t block) {
    return xpf_dispatch_block_create_with_qos_class(flags, QOS_CLASS_DEFAULT, 0, block);
}
XPF_REBIND_ENTRY("_dispatch_block_create", XPF_LIBSYSTEM_PATH, NULL, (uintptr_t) &xpf_dispatch_block_create);

static void xpf_dispatch_block_cancel (dispatch_block_t block) {
    // TODO - emulate
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        XPFLog("Warning! Ignoring unimplemented dispatch_block_cancel(); this may result in unexpected behavior (such as deadlocks and crashes). This message will be logged only once.");
    });
}
XPF_REBIND_ENTRY("_dispatch_block_cancel", XPF_LIBSYSTEM_PATH, NULL, (uintptr_t) &xpf_dispatch_block_cancel);

long dispatch_block_testcancel(dispatch_block_t block) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        XPFLog("Warning! Ignoring unimplemented dispatch_block_testcancel(); this may result in unexpected behavior (such as deadlocks and crashes). This message will be logged only once.");
    });
    return 0;
}
XPF_REBIND_ENTRY("_dispatch_block_testcancel", XPF_LIBSYSTEM_PATH, NULL, (uintptr_t) &dispatch_block_testcancel);
    
} /* namespace xpf */
