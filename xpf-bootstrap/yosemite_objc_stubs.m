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

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

#import "yosemite_objc_stubs.h"

/*
 * This file binds (via ObjC categories) Yosemite-only methods that are required to run Xcode.
 */

/* We're intentionally implementing methods that *would* be implemented in 10.10 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#define FACADE(_cls) @interface _cls (XPFYosemiteFacade) @end @implementation _cls (XPFYosemiteFacade)

FACADE(NSLayoutConstraint)
+ (void)activateConstraints:(NSArray *)constraints { }
+ (void)deactivateConstraints:(NSArray *)constraints { }
@end

FACADE(NSColor)
+ (NSColor *) labelColor { return [self controlTextColor]; }
+ (NSColor *) secondaryLabelColor { return [self disabledControlTextColor]; }
@end

FACADE(NSOperationQueue)
- (void) setQualityOfService:(NSQualityOfService)qualityOfService {}
@end

FACADE(NSThread)

static int XPF_NSThread_QOS = 0;
- (NSQualityOfService) qualityOfService {
    NSNumber *qos = objc_getAssociatedObject(self, &XPF_NSThread_QOS);
    if (qos == nil)
        return NSQualityOfServiceDefault;

    return (NSQualityOfService) [qos unsignedLongLongValue];
}
- (void) setQualityOfService:(NSQualityOfService)qualityOfService {
    objc_setAssociatedObject(self, &XPF_NSThread_QOS, @(qualityOfService), OBJC_ASSOCIATION_RETAIN);
}

@end

FACADE(NSOperation)
- (NSQualityOfService) qualityOfService {return NSQualityOfServiceDefault; }
- (void) setQualityOfService:(NSQualityOfService)qualityOfService {}
@end

FACADE(NSToolbarItem)
- (void) setWantsToBeCentered: (BOOL) centered { }
@end

FACADE(NSWindow)
- (void) setTitleVisibility: (BOOL) visibility {}
- (void) setTitlebarAppearsTransparent: (BOOL) appearsTransparent {}
- (void) setTitleMode: (NSUInteger) titleMode {}
@end

FACADE(NSTextView)
- (void) setUsesRolloverButtonForSelection: (BOOL) usesRolloverButtonForSelection {}
@end

FACADE(NSScrollView)
- (BOOL) automaticallyAdjustsContentInsets { return false; }
- (void) setAutomaticallyAdjustsContentInsets: (BOOL) automaticallyAdjustsContentInsets { }
@end

#pragma clang diagnostic pop