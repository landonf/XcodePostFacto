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

#import "xpf_bootstrap.h"
#import <PLPatchMaster/SymbolBinder.hpp>

#import "rebind_table.h"
#import "cfbundle_rebind.h"

#import "XPFLog.h"

#import "DVTPlugInManager.h"
#import "dyld_priv.h"
#import <objc/runtime.h>
#import <mach-o/getsect.h>

using namespace patchmaster;

static const char *xpf_image_state_change (enum dyld_image_states state, uint32_t infoCount, const struct dyld_image_info info[]);
static void xpf_add_image_callback (const struct mach_header *header, intptr_t vm_slide);

static void image_rewrite_bind_opcodes (const LocalImage &image);
static void image_rebind_required_symbols (LocalImage &image);
static void image_insert_xcode_plugin_path ();

/** Our own mach header */
static const pl_mach_header_t *xpf_bootstrap_mh = nullptr;

/* Symbols to be marked as weak. */
static const struct weak_entry {
    const char *library;
    const char *symbol;
} weak_symbols[] = {
    { "/System/Library/Frameworks/SceneKit.framework/Versions/A/SceneKit", "_OBJC_CLASS_$_SCNParticlePropertyController" },
    { "/usr/lib/libSystem.B.dylib", "_posix_spawnattr_set_qos_class_np" }
};

/**
 * Pre-main initialization (non-ObjC).
 */
__attribute__((constructor)) static void xpf_prelaunch_initializer (void) {
    /* Fetch a persistent reference to our image's mach header. */
    Dl_info dli;
    if (dladdr((const void *) &xpf_prelaunch_initializer, &dli) == 0) {
        PMLog("Could not find our own image!");
        abort();
    }
    xpf_bootstrap_mh = (const pl_mach_header_t *) dli.dli_fbase;
    
    /* Register our state change callback */
    dyld_register_image_state_change_handler(dyld_image_state_rebased, true, xpf_image_state_change);
    
    /* Use the standard dyld callback for all other rebindings */
    _dyld_register_func_for_add_image(xpf_add_image_callback);
}

/**
 * Given a bound -- but not yet initialized -- image, apply symbol rebindings from the XPF_REBIND_SECTION.
 *
 * Note that this function will provide incorrect original addresses if the image has not already been bound.
 *
 * @param image Image to rebind.
 * @param table Rebind table to apply.
 */
static void image_rebind_required_symbols (LocalImage &image) {
    /* Fetch our rebind table, if any */
    unsigned long rebind_table_size;
    auto rebind_table = (const struct xpf_rebind_entry *) getsectiondata(xpf_bootstrap_mh, SEG_DATA, XPF_REBIND_SECTION, &rebind_table_size);
    if (rebind_table == nullptr) {
        PMLog("No rebind table found!");
        return;
    }
    
    /* Calculate the actual number of entries */
    size_t rebind_table_len = rebind_table_size / sizeof(xpf_rebind_entry);
    
    /* Loop over all symbol references in the image */
    image.rebind_symbols([&](const bind_opstream::symbol_proc &sp) {
        /* Iterate the bootstrap rebind table looking for a matching patch entry. */
        for (size_t i = 0; i < rebind_table_len; i++) {
            const struct xpf_rebind_entry &entry = rebind_table[i];

            /* Check for a symbol match */
            if (!sp.name().match(SymbolName(entry.image, entry.symbol)))
                continue;
    
            // XPFLog(@"Binding %s:%s in %s:%lx to %lx", sp.name().image().c_str(), sp.name().symbol().c_str(), image.path().c_str(), sp.bind_address(), entry.replacement);
            
            /* On match, save the previous value (if it hasn't already been saved) and insert the new value */
            uintptr_t *target = (uintptr_t * ) sp.bind_address();
            
            if (entry.original != NULL && *entry.original == NULL)
                *entry.original = (void *) *target;
            
            if (*target != entry.replacement)
                *target = entry.replacement;
        }
    });
}

/**
 * Our on-rebase state change callback; responsible for performing any modifications to the image that are necessary pre-bind.
 */
static const char *xpf_image_state_change (enum dyld_image_states state, uint32_t infoCount, const struct dyld_image_info info[]) {
    /* Rewrite all weak references. */
    for (uint32_t i = 0; i < infoCount; i++) {
        LocalImage image = LocalImage::Analyze(info[i].imageFilePath, (const pl_mach_header_t *) info[i].imageLoadAddress);
        image_rewrite_bind_opcodes(image);
    }

    return NULL;
}

/**
 * Image add callback; used to perform symbol rebinding and Objective-C patching after images have been fully loaded.
 */
static void xpf_add_image_callback (const struct mach_header *header, intptr_t vm_slide) {
    const char *name = nullptr;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) != header)
            continue;
        
        name = _dyld_get_image_name(i);
        break;
    }

    /* This would be odd ... */
    if (name == nullptr) {
        return;
    }

    /* Perform symbol rebinding. */
    auto image = LocalImage::Analyze(name, (const pl_mach_header_t *) header);
    image_rebind_required_symbols(image);
    
    /* Apply ObjC patch to any existing loaded images. */
    image_insert_xcode_plugin_path();
}


/*
 * This is the only Objective-C patch that /must/ be applied early on at the bootstrap level -- we swizzle DVTPlugInManager,
 * appending our embedded Xcode developer directory to the default path list; this ensures
 * that our embedded Xcode plugin gets picked up at IDEInitialization time. 
 */
static id (*orig_DVTPlugInManager_init) (DVTPlugInManager *self, SEL _cmd);
static id xpf_DVTPlugInManager_init (DVTPlugInManager *self, SEL _cmd) {
    if ((self = orig_DVTPlugInManager_init(self, _cmd)) == nil)
        return nil;
    
    NSBundle *bundle = [NSBundle bundleWithIdentifier: @"org.landonf.xpf-bootstrap"];
    NSString *embeddedDevDir = [[bundle resourcePath] stringByAppendingPathComponent: @"Xcode"];
    [self.mutableSearchPaths addObject: embeddedDevDir];
    
    return self;
}

/**
 * Called upon image load to perform swizzling of DVTPlugInManager, if necessary.
 */
static void image_insert_xcode_plugin_path () {
    /* Already patched */
    if (orig_DVTPlugInManager_init != nullptr)
        return;
    
    /* Check for the class. */
    Class cls = objc_getClass("DVTPlugInManager");
    if (cls == nil)
        return;
    
    /* If available, perform the swap */
    Method m = class_getInstanceMethod(cls, @selector(init));
    if (m == NULL)
        return;

    /* Save the old implementation, insert the new. */
    orig_DVTPlugInManager_init = (decltype(orig_DVTPlugInManager_init)) method_getImplementation(m);
    IMP newIMP = (IMP) xpf_DVTPlugInManager_init;
    
    if (!class_addMethod(cls, @selector(init), newIMP, method_getTypeEncoding(m))) {
        /* Method already exists in subclass, we just need to swap the IMP */
        method_setImplementation(m, newIMP);
    }
}


/**
 * Rewrite the bind instructions of a newly loaded image, detecting and marking as weak any missing
 * symbols.
 */
static void image_rewrite_bind_opcodes (const LocalImage &image) {
    /* Find the LINKEDIT segment; we need this to be able to reset memory protections
     * back to their original values. */
    const pl_segment_command_t *linkedit = nullptr;
    {
        for (auto &&segment : *image.segments()) {
            if (strcmp(segment->segname, SEG_LINKEDIT) != 0)
                continue;
            
            linkedit = segment;
        }

        if (linkedit == nullptr) {
            PMLog("Could not find the __LINKEDIT segment; cannot rebind opcodes for %s", image.path().c_str());
            return;
        }
    }
    
    /* Mark the LINKEDIT segment as writable */
    if (mprotect((void *) (linkedit->vmaddr + image.vmaddr_slide()), linkedit->vmsize, linkedit->initprot|PROT_WRITE) != 0) {
        PMLog("mprotect(__LINKEDIT, PROT_WRITE) failed; cannot rebind opcodes for %s: %s", image.path().c_str(), strerror(errno));
        return;
    }

    /* Iterate over all opcode streams in the image, looking for (and correcting)
     * non-weak references to undefined symbols. */
    for (auto &&opcodes : *image.bindOpcodes()) {
        bind_opstream ops = opcodes;
        
        /* Points to the last instance of BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM (if any). */
        const uint8_t *symbol_decl_pc = nullptr;
        
        /* Check for an undefined symbol */
        auto check_def = [&](const bind_opstream::symbol_proc &sp) {
            /* Skip any symbols not explicitly marked for weak rewriting */
            bool found = false;
            for (size_t i = 0; i < sizeof(weak_symbols) / sizeof(weak_symbols[0]); i++) {
                if (strcmp(weak_symbols[i].symbol, sp.name().symbol()) != 0)
                    continue;
                
                if (strcmp(weak_symbols[i].library, sp.name().image()) != 0)
                    continue;
                
                found = true;
                break;
            }

            /* Mark the sumbol as weak if it's not already */
            if (!(sp.flags() & BIND_SYMBOL_FLAGS_WEAK_IMPORT)) {
                /* Rewrite the symbol flags */
                *((uint8_t *) symbol_decl_pc) = BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM | sp.flags() | BIND_SYMBOL_FLAGS_WEAK_IMPORT;
            }
        };
    
        /* Step the VM, keeping track of symbol definition state so that we can rewrite
         * any SET_SYMBOL opcodes that reference unknown symbols. */
        const uint8_t *last_pc = ops.position();
        uint8_t opcode = BIND_OPCODE_DONE;
        while (!ops.isEmpty() && (opcode = ops.step(image, check_def)) != BIND_OPCODE_DONE) {
            /* Save the opcode address */
            if (opcode == BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM) {
                symbol_decl_pc = last_pc;
            }
            
            /* Update our PC state */
            last_pc = ops.position();
        }
    }
    
    /* Restore the LINKEDIT segment's initial protections. */
    if (mprotect((void *) (linkedit->vmaddr + image.vmaddr_slide()), linkedit->vmsize, linkedit->initprot) != 0) {
        PMLog("mprotect(__LINKEDIT, initprot) failed; could not restore expected protections for %s: %s", image.path().c_str(), strerror(errno));
        return;
    }
}
