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

/* Implements enough of the 10.10 ViewController API additions to allow execution */

// TODO - We're going to need more than viewDidLoad :-)

@interface NSViewController (XPFYosemite)
@end
@implementation NSViewController (XPFYosemite)

/* We're intentionally implementing methods that *would* be implemented in 10.10 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
- (void) viewDidLoad {}
- (void) viewWillAppear {}
- (void) viewDidAppear {}
#pragma clang diagnostic pop

+ (void) load {
    /* On 10.10, a nil nibName attempts to load a nib matching the class name. We emulate that by supplying
     * a non-nil nibName. */
    [NSViewController pl_patchInstanceSelector: @selector(nibName) withReplacementBlock: ^(PLPatchIMP *patch) {
        NSViewController *self = PLPatchGetSelf(patch);

        NSString *nibName = PLPatchIMPFoward(patch, NSString *(*)(id, SEL));
        if (nibName != nil)
            return nibName;
        
        return NSStringFromClass([self class]);
    }];
    
    /* Inject view lifetime cycle management */
    [NSViewController pl_patchInstanceSelector: @selector(setView:) withReplacementBlock: ^(PLPatchIMP *patch, NSView *view) {
        NSViewController *self = PLPatchGetSelf(patch);

        PLPatchIMPFoward(patch, void (*)(id, SEL, NSView *), view);
        [self viewDidLoad];
        // TODO - We should probably trigger this in a smarter way
        [self viewWillAppear];
        [self viewDidAppear];
    }];
}


@end