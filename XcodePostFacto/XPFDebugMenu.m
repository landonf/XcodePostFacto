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

#import "XPFDebugMenu.h"
#import "XPFLog.h"


@implementation XPFDebugMenu {
@private
}

/**
 * Return the shared handler instance; this global variable is necessitated by Xcode's
 * use of a class method when resolving menu handlers.
 */
+ (instancetype) sharedHandler {
    static XPFDebugMenu *sharedHandler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHandler = [[self alloc] init];
    });
    
    return sharedHandler;
}

/**
 * Initialize a new instance.
 */
- (instancetype) init {
    if ((self = [super init]) == nil)
        return nil;
    
    return self;
}

// Returns the handler for a given action. This seemingly should already be available via
// the entries 'action' value; we need to spend some time reverse engineering the menu configuration
// options and how actions are mapped.
+ (id) handlerForAction: (SEL) action withSelectionSource: (id) src {
    return [self sharedHandler];
}

// XcodePostFacto.CmdHandler.ViewAnalyzerMenuEntry handler.
- (void) enableViewAnalyzer: (id) sender {
    // TODO -- pending F-Script integration
    
#if 0
    /* Fire up the analyzer window */
    if (_analyzerWindowController == nil)
        _analyzerWindowController = [[EXViewAnalyzerWindowController alloc] init];
    [_analyzerWindowController showWindow: nil];
    
    /*
     * F-Script compatibility patches
     *
     * Xcode's IDEInterfaceBuilderCocoaTouchIntegration includes an NSObject category that registers
     * an assortment of ib-related methods for abstract methods, and then triggers non-exception-based
     * abort() when they are called. This triggers a crash when F-Script introspects defined object
     * properties. This ugly hack works around the issue; we can re-evaluate this in favor for a more
     * surgical approach at later date.
     *
     * The IDEInterfaceBuilderCocoaTouchIntegration plugin may be loaded after our class, so we register
     * a future patch.
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSObject ex_patchFutureSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];
        [NSObject ex_patchInstanceSelector: @selector(ibExternalLastKnownCanvasFrameOrigin) withReplacementBlock: ^(EXPatchIMP *patch) { return NSZeroPoint; }];
    });
#endif
}

@end
