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
#import <CoreData/CoreData.h>

#import "yosemite_objc_stubs.h"

/*
 * This file binds (via ObjC categories) Yosemite-only methods that are required to run Xcode to 
 * no-op stub methods.
 */

/* We're intentionally implementing methods that *would* be implemented in 10.10 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#define FACADE(_cls) @interface _cls (XPFYosemiteFacade) @end @implementation _cls (XPFYosemiteFacade)

FACADE(NSPersistentStoreCoordinator)
// XXX - We really need to fetch the real queue from the persistent store coordinator and dispatch
// on that
- (void) performBlock:(void (^)())block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self lock];
        block();
        [self unlock];
    });
}

- (void) performBlockAndWait:(void (^)())block {
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self lock];
        block();
        [self unlock];
    });
}
@end

FACADE(NSXPCConnection)
- (xpc_connection_t) _xpcConnection {
    xpc_connection_t conn;
    object_getInstanceVariable(self, "_xconnection", (void **) &conn);
    return conn;
}
@end

FACADE(NSString)
- (BOOL) localizedCaseInsensitiveContainsString:(NSString *)aString {
    return [self rangeOfString: aString options:NSCaseInsensitiveSearch range: NSMakeRange(0, self.length) locale: [NSLocale currentLocale]].location != NSNotFound;
}
@end

FACADE(NSCell)
- (void) setAccessibilityTitleUIElement:(id)accessibilityTitleUIElement { }
- (void) setAccessibilityChildren:(NSArray *)accessibilityChildren { }
- (void) setAccessibilityRoleDescription:(NSString *)accessibilityRoleDescription { }
- (void) setAccessibilityRole:(NSString *)accessibilityRole { }
- (void) setAccessibilityParent:(id)accessibilityParent { }
- (void) setAccessibilityIdentifier:(NSString *)accessibilityIdentifier { }
- (void) setAccessibilityTitle:(NSString *)accessibilityTitle { }
- (void) setAccessibilityLabel:(NSString *)accessibilityLabel { }
- (void) setAccessibilityValue:(id)accessibilityValue { }
@end

FACADE(NSView)
- (void) setAccessibilityTitleUIElement:(id)accessibilityTitleUIElement { }
- (void) setAccessibilityChildren:(NSArray *)accessibilityChildren { }
- (void) setAccessibilityRoleDescription:(NSString *)accessibilityRoleDescription { }
- (void) setAccessibilityRole:(NSString *)accessibilityRole { }
- (void) setAccessibilityParent:(id)accessibilityParent { }
- (void) setAccessibilityIdentifier:(NSString *)accessibilityIdentifier { }
- (void) setAccessibilityTitle:(NSString *)accessibilityTitle { }
- (void) setAccessibilityLabel:(NSString *)accessibilityLabel { }
- (void) setAccessibilityValue:(id)accessibilityValue { }
- (void) setAllowsVibrancy: (BOOL) v { }
@end

FACADE(NSViewController)
// XXX! This needs to actually work
- (void) removeFromParentViewController {}
@end

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
static int XPF_NSOperation_Name = 0;
- (NSQualityOfService) qualityOfService {return NSQualityOfServiceDefault; }
- (void) setQualityOfService:(NSQualityOfService)qualityOfService {}
- (void) setName: (NSString *) name { objc_setAssociatedObject(self, &XPF_NSOperation_Name, name, OBJC_ASSOCIATION_COPY); }
- (NSString *) name { return objc_getAssociatedObject(self, &XPF_NSOperation_Name); }
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