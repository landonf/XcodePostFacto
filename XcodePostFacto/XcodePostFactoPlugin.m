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

#import "XcodePostFactoPlugin.h"
#import "XPFLog.h"


@implementation XcodePostFactoPlugin {
@private
}

// force loading of the plugin class upon bundle load
+ (void) load {
    asm("int3");
    [self defaultPlugin];
}

/**
 * Return the default plugin instance.
 */
+ (instancetype) defaultPlugin {
    static XcodePostFactoPlugin *defaultInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultInstance = [[self alloc] init];
    });
    
    return defaultInstance;
}

/**
 * Initialize a new instance.
 */
- (instancetype) init {
    if ((self = [super init]) == nil)
        return nil;
    
    XPFLog(@"Plugin loaded; starting up ...");
    
    return self;
}

// Returns the handler for a given action. This seemingly should already be available via
// the entries 'action' value; we need to spend some time reverse engineering the menu configuration
// options and how actions are mapped.
+ (id) handlerForAction: (SEL) action withSelectionSource: (id) src {
    return [self defaultPlugin];
}

// XCPF.CmdHandler.ViewAnalyzerMenuEntry handler.
- (void) enableViewAnalyzer: (id) sender {
    // TODO
}


@end
