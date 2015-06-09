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

@class DVTVersion;
@class DVTPlugIn;

// Generated with class-dump
@interface DVTPlugInScanRecord : NSObject /* <DVTPropertyListEncoding> */
{
    NSString *_path;
    NSString *_bundlePath;
    NSBundle *_bundle;
    NSString *_identifier;
    BOOL _isApplePlugIn;
    NSString *_marketingVersion;
    NSDictionary *_bundleRawInfoPlist;
    NSDictionary *_plugInPlist;
    double _timestamp;
    NSSet *_requiredCapabilities;
    DVTVersion *_minimumRequiredSystemVersion;
    DVTVersion *_maximumAllowedSystemVersion;
    DVTPlugIn *_plugIn;
    NSSet *_plugInCompatibilityUUIDs;
}

+ (void)initialize;
@property(retain) DVTPlugIn *plugIn; // @synthesize plugIn=_plugIn;
@property(readonly) double timestamp; // @synthesize timestamp=_timestamp;
@property(readonly, copy) NSDictionary *plugInPlist; // @synthesize plugInPlist=_plugInPlist;
@property(readonly, copy) NSSet *plugInCompatibilityUUIDs; // @synthesize plugInCompatibilityUUIDs=_plugInCompatibilityUUIDs;
@property(readonly, copy) DVTVersion *maximumAllowedSystemVersion; // @synthesize maximumAllowedSystemVersion=_maximumAllowedSystemVersion;
@property(readonly, copy) DVTVersion *minimumRequiredSystemVersion; // @synthesize minimumRequiredSystemVersion=_minimumRequiredSystemVersion;
@property(readonly, copy) NSSet *requiredCapabilities; // @synthesize requiredCapabilities=_requiredCapabilities;
@property(readonly, copy) NSDictionary *bundleRawInfoPlist; // @synthesize bundleRawInfoPlist=_bundleRawInfoPlist;
@property(readonly, copy) NSString *marketingVersion; // @synthesize marketingVersion=_marketingVersion;
@property(readonly) BOOL isApplePlugIn; // @synthesize isApplePlugIn=_isApplePlugIn;
@property(readonly, copy) NSString *identifier; // @synthesize identifier=_identifier;
@property(readonly) NSBundle *bundle; // @synthesize bundle=_bundle;
@property(readonly, copy) NSString *bundlePath; // @synthesize bundlePath=_bundlePath;
@property(readonly, copy) NSString *path; // @synthesize path=_path;
// - (void).cxx_destruct;
- (BOOL)loadRequiredCapabilities:(id *)arg1;
- (BOOL)_loadBundleRawInfoPlist:(id *)arg1;
- (BOOL)loadPlugInPlist:(id *)arg1;
- (id)_contentsOfPlistAtURL:(id)arg1 error:(id *)arg2;
- (void)_instantiateBundleIfNecessary;
- (BOOL)isEquivalentToPlistRepresentation:(id)arg1;
- (void)encodeIntoPropertyList:(id)arg1;
- (void)awakeWithPropertyList:(id)arg1;
- (id)initWithPropertyList:(id)arg1 owner:(id)arg2;
@property(readonly, copy) NSString *description;
- (long long)compare:(id)arg1;
- (id)initWithPath:(id)arg1 bundle:(id)arg2 plugInPlist:(id)arg3 timestamp:(double)arg4;
- (id)initWithPath:(id)arg1 bundlePath:(id)arg2 plugInPlist:(id)arg3 timestamp:(double)arg4;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end
