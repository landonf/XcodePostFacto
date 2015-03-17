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

#import <AppKit/AppKit.h>
#import <PLPatchMaster/PLPatchMaster.h>

#import "XcodePostFacto.h"
#import "XPFLog.h"
#import <dlfcn.h>

// from DVTFoundation -- partial API
@interface DVTVersion : NSObject <NSCopying>
+ (id)currentSystemVersion;
+ (id)versionWithStringValue:(id)arg1;
+ (id)versionWithStringValue:(id)arg1 buildNumber:(id)arg2;
@property(readonly, copy) NSString *stringValue;
@end

/* Replacement frameworks bundled with Xcode that are required for Mavericks */
static NSString* sharedFrameworks[] = {
    @"SceneKit.framework",
    @"PhysicsKit.framework",
    @"SpriteKit.framework"
};

@implementation XcodePostFacto

// from IDEInitialization protocol
+ (BOOL) ide_initializeWithOptions: (int) flags error: (NSError **) arg2 {
    NSError *error;

    /* Since we pretend to be 10.10, we have to implement shared framework loading ourselves.
     * This is normally done in IDEFoundation:__IDEInitializeLoadSharedFrameworksFor10_9 */
    XPFLog(@"Initializing Mavericks shared frameworks");
    for (size_t i = 0; i < sizeof(sharedFrameworks) / sizeof(sharedFrameworks[0]); i++) {
        NSString *framework = sharedFrameworks[i];
        NSString *path = [[[NSBundle mainBundle] sharedFrameworksPath] stringByAppendingPathComponent: framework];
        
        if (![[NSBundle bundleWithPath: path] loadAndReturnError: &error]) {
            NSLog(@"Failed to load %@: %@", framework, error);
        }
    }
    
    return YES;
}

#if 0

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

#endif

@end
