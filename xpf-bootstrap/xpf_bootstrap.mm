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

#import "xpf_bootstrap.h"
#import <PLPatchMaster/PLPatchMaster.h>
#import <PLPatchMaster/SymbolBinder.hpp>
#import <AppKit/AppKit.h>

#import "rebind_table.h"

#import "dyld_priv.h"
#import "XPFLog.h"

using namespace patchmaster;

namespace xpf {

static const char *xpf_image_state_change (enum dyld_image_states state, uint32_t infoCount, const struct dyld_image_info info[]);
static void image_rewrite_bind_opcodes (const LocalImage &image);
static void image_rebind_required_symbols (LocalImage &image);

/**
 * Pre-main initialization (non-ObjC).
 */
__attribute__((constructor)) static void xpf_prelaunch_initializer (void) {
    /* Register our state change callback */
    dyld_register_image_state_change_handler(dyld_image_state_rebased, true, xpf_image_state_change);
    
    /* Perform immediate rebinding on already loaded images. */
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        auto image = LocalImage::Analyze(_dyld_get_image_name(i), (const pl_mach_header_t *) _dyld_get_image_header(i));
        image_rebind_required_symbols(image);
    }
}


/**
 * Given a bound -- but not yet initialized -- image, apply symbol rebindings required to bootstrap Xcode.
 */
static void image_rebind_required_symbols (LocalImage &image) {
    /* Loop over all symbol references in the image */
    image.rebind_symbols([&](const bind_opstream::symbol_proc &sp) {
        /* Iterate the bootstrap rebind table looking for a matching patch entry. */
        for (size_t i = 0; i < bootstrap_rebind_table_length; i++) {
            const rebind_entry &entry = bootstrap_rebind_table[i];

            /* Check for a symbol match */
            if (!sp.name().match(SymbolName(entry.image, entry.symbol)))
                continue;
    
            XPFLog(@"Binding %s:%s in %s:%lx", sp.name().image().c_str(), sp.name().symbol().c_str(), image.path().c_str(), sp.bind_address());
            
            /* On match, insert the new value */
            uintptr_t *target = (uintptr_t * ) sp.bind_address();
            if (*target != entry.replacement)
                *target = entry.replacement;
        }
    });
}

/**
 * Our on-rebase state change callback; responsible for performing any modifications to the image that are necessary pre-bind.
 */
static const char *xpf_image_state_change (enum dyld_image_states state, uint32_t infoCount, const struct dyld_image_info info[]) {
    for (uint32_t i = 0; i < infoCount; i++) {
        LocalImage image = LocalImage::Analyze(info[i].imageFilePath, (const pl_mach_header_t *) info[i].imageLoadAddress);

        switch (state) {
            case dyld_image_state_rebased:
                /* Rewrite all weak references. */
                image_rewrite_bind_opcodes(image);
                break;
                
            case dyld_image_state_bound:
                /* Rebind required symbols */
                image_rebind_required_symbols(image);
                break;

            default:
                break;
        }
    }
    return NULL;
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

            /*
             * Ideally, we'd check for symbol availability and log missing symbols before flagging them as weak,
             * but to do so, we need to be able to perform symbol lookups without recursively calling into dyld, e.g.,
             * by writing our own export interpreter.
             *
             * As a stop-gap to aid in development, we could print a list of missing symbols by re-running our validation
             * mechanism *after* all the images are loaded.
             *
             * There are good reasons to support this other than simplifying finding of weak symbols; for example,
             * we could automatically rewrite missing classes and selectors to no-op implementations.
             *
             * For now, we just blindly make the universe weak. Weak, right? :-)
             */
            if (!(sp.flags() & BIND_SYMBOL_FLAGS_WEAK_IMPORT)) {
                /* Rewrite the symbol flags */
                *((uint8_t *) symbol_decl_pc) = BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM | sp.flags() | BIND_SYMBOL_FLAGS_WEAK_IMPORT;
            }

#if TODO_NEED_NONRECUSIVE_SYMBOL_LOOKUP_SUPPORT
            /* Determine the appropriate handle to use for lookups, depending on whether this is a two-level or flat symbol reference. */
            void *handle = RTLD_DEFAULT;
            if (sp.name().image().length() != 0) {
                /* Two-level image -- fetch a proper handle */
                handle = dlopen(sp.name().image().c_str(), RTLD_LAZY|RTLD_FIRST);
                if (handle == nullptr) {
                    PMLog("Unexpected error opening library dependency: %s", dlerror());
                    PMLog("Current image: %s", image.path().c_str());
                    PMLog("Failed image: %s", sp.name().image().c_str());
                    abort();
                }
            }
            
            /* Check for the symbol. If it doesn't exist -- and it's not already marked as weak -- we need to
             * rewrite this symbol proc to use weak binding. */
            const char *target_symbol = sp.name().symbol().c_str();
            if (dlsym(handle, target_symbol+1 /* skip leading underscore */) == nullptr) {
                PMLog("Warning -- missing symbol: %s:%s", sp.name().image().c_str(), sp.name().symbol().c_str());

                /* We always warn -- it's useful for tracking down incompatibilities -- but we don't actually
                 * need to patch symbols that are already marked as weak imports. */
                if (!(sp.flags() & BIND_SYMBOL_FLAGS_WEAK_IMPORT)) {                    
                    /* Rewrite the symbol flags */
                    *((uint8_t *) symbol_decl_pc) = (
                        BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM |
                        (sp.flags() & BIND_SYMBOL_FLAGS_WEAK_IMPORT)
                    );
                }
            }
            
            /* Clean up */
            if (handle != RTLD_DEFAULT)
                dlclose(handle);
#endif
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

} /* namespace xpf */