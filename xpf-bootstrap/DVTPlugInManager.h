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

// Generated with class-dump

@class DVTPlugInLocator;
@interface DVTPlugInManager : NSObject

+ (void)_setDefaultPlugInManager:(id)arg1;
+ (BOOL)enumerateExtensionDataForPluginAtPath:(id)arg1 error:(id *)arg2 withBlock:(id /* unknown block type */)arg3;
+ (id)defaultPlugInManager;
+ (void)initialize;
@property(retain) DVTPlugInLocator *plugInLocator; // @synthesize plugInLocator=_plugInLocator;
@property BOOL shouldClearPlugInCaches; // @synthesize shouldClearPlugInCaches=_shouldClearPlugInCaches;
- (id)_invalidExtensionWithIdentifier:(id)arg1;
- (id)_plugInCachePath;
- (id)_applicationCachesPath;
- (id)_toolsVersionName;
- (void)_createPlugInObjectsFromCache;
- (BOOL)_savePlugInCacheWithScanRecords:(id)arg1 error:(id *)arg2;
- (BOOL)_removePlugInCacheAndReturnError:(id *)arg1;
- (BOOL)_removePlugInCacheAtPath:(id)arg1 error:(id *)arg2;
- (id)_plugInCacheSaveFailedErrorWithUnderlyingError:(id)arg1;
- (BOOL)_loadPlugInCache:(id *)arg1;
- (BOOL)_cacheCoversPlugInsWithScanRecords:(id)arg1;
- (id)_modificationDateOfFileAtPath:(id)arg1;
@property(readonly) BOOL usePlugInCache;
- (void)_preLoadPlugIns;
- (BOOL)_checkPresenceOfRequiredPlugIns:(id)arg1 error:(id *)arg2;
- (BOOL)shouldPerformConsistencyCheck;
- (void)_registerPlugInsFromScanRecords:(id)arg1;
- (void)_pruneUnusablePlugInsAndScanRecords:(id)arg1;
- (id)_plugInsToIgnore;
- (void)_recordSanitizedPluginStatus:(id)arg1 errorMessage:(id)arg2;
- (void)_addSanitizedNonApplePlugInStatusForBundle:(id)arg1 reason:(id)arg2;
@property(readonly) NSSet *sanitizedNonApplePlugInStatuses;
- (void)_createPlugInObjectsFromScanRecords:(id)arg1;
- (void)_applyActivationRulesToScanRecords:(id)arg1;
- (id)_scanForPlugInsInDirectories:(id)arg1 skippingDuplicatesOfPlugIns:(id)arg2;
- (BOOL)_scanForPlugIns:(id *)arg1;
@property(readonly, copy) NSUUID *plugInHostUUID;
@property BOOL hasScannedForPlugIns; // @dynamic hasScannedForPlugIns;
- (id)_scanRecordForBundle:(id)arg1 atPath:(id)arg2;
- (BOOL)_isInitialScan;
- (id)_defaultPathExtensions;
@property(readonly, copy) NSArray *defaultSearchPaths;
- (id)_defaultApplicationSupportSubdirectory;
@property(readonly, copy) NSArray *extraSearchPaths;
- (id)_extensionsForExtensionPoint:(id)arg1 matchingPredicate:(id)arg2;
- (id)sharedExtensionsForExtensionPoint:(id)arg1 matchingPredicate:(id)arg2;
- (id)sharedExtensionWithIdentifier:(id)arg1;
- (id)extensionWithIdentifier:(id)arg1;
- (id)extensionPointWithIdentifier:(id)arg1;
- (id)plugInWithIdentifier:(id)arg1;
- (BOOL)scanForPlugIns:(id *)arg1;
- (id)init;
- (id)_hostAppName;
- (id)_hostAppContainingPath;

// Remaining properties
@property(copy) NSSet *defaultPlugInCapabilities; // @dynamic defaultPlugInCapabilities;
@property(copy) NSSet *exposedCapabilities; // @dynamic exposedCapabilities;
@property(readonly) NSMutableSet *mutableDefaultPlugInCapabilities; // @dynamic mutableDefaultPlugInCapabilities;
@property(readonly) NSMutableSet *mutableExposedCapabilities; // @dynamic mutableExposedCapabilities;
@property(readonly) NSMutableSet *mutablePathExtensions; // @dynamic mutablePathExtensions;
@property(readonly) NSMutableSet *mutableRequiredPlugInIdentifiers; // @dynamic mutableRequiredPlugInIdentifiers;
@property(readonly) NSMutableArray *mutableSearchPaths; // @dynamic mutableSearchPaths;
@property(copy) NSSet *pathExtensions; // @dynamic pathExtensions;
@property(copy) NSSet *requiredPlugInIdentifiers; // @dynamic requiredPlugInIdentifiers;
@property(copy) NSArray *searchPaths; // @dynamic searchPaths;

@end