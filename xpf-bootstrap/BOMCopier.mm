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

#import <Foundation/Foundation.h>
#import "rebind_table.h"
#import "XPFLog.h"

#define XPF_BM_PATH "/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom"


/*
 * Yosemite+ supports packages containing a non-standard "pbzx"-compressed Payload; this is described
 * in Yosemite's PackageKit as the "LZMA block compressed" format.
 
 * We insert ourselves into the BOMCopierCopyWithOptions path to handle decompression of the
 * payload directly.
 *
 * Information on parsing the pbzx format was derived from the exceedingly helpful
 * work published by "SJ_UnderWater" at http://www.tonymacx86.com/general-help/135458-pbzx-stream-parser.html
 */

extern "C" {

/* Forward declaration */
struct BOMCopier;

/* Keys used to store input souces within a set of BOMCopier options */
static NSString *kBOMOptionInputFDKey = @"inputFD";
static NSString *kBOMOptionInputStreamKey = @"inputStream";

static const uint8_t PBZX_MAGIC[] = { 'p', 'b', 'z', 'x' };

/** BOMCopier fatal error handler. */
typedef void (*BOMCopierFatalErrorHandler)(BOMCopier *copier, const char *errorString);

/** BOMCopier. This is depends on internal offsets that may change! */
struct BOMCopier {
    void *_unknown_head[4];
    BOMCopierFatalErrorHandler _fatalErrorHandler;
    uint8_t _unknown_tail[];
};

}

static BOOL (*orig_BOMCopierCopyWithOptions)(BOMCopier *copier, off_t offset, const char *destPath, NSDictionary *options);
static BOOL xpf_BOMCopierCopyWithOptions (BOMCopier *copier, off_t offset, const char *destPath, NSDictionary *options) {
    XPFLog(@"xpf_BOMCopierCopyWithOptions(%p, %lld, %s, %@)", copier, (long long) offset, destPath, options);
    
    /* Configure a readn() implementation based on the caller-provided input type */
    ssize_t (^ReadN)(void *buf, size_t nbyte, off_t offset) = nil;
    NSUInteger inputsFound = 0;
    
    NSMutableDictionary *patchedOptions = [options mutableCopy];
    
    /* Configure for an input FD */
    if (options[kBOMOptionInputFDKey] != nil) {
        inputsFound++;

        int fd = [(NSNumber *) options[kBOMOptionInputFDKey] intValue];
        ReadN = ^ssize_t (void *buf, size_t nbyte, off_t offset) {
            size_t remain = nbyte;
            ssize_t nr = 0;
            while (remain > 0) {
                nr = pread(fd, buf, nbyte, offset + (nbyte - remain));
                if (nr < 0) {
                    if (errno == EINTR)
                        continue;
                    
                    copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"Error reading from fd=%d: %s", fd, strerror(errno)].UTF8String);
                    return nr;
                }
                
                if (nr == 0)
                    break;
                
                remain -= nr;
            }
            
            return nbyte - remain;
        };

        patchedOptions[kBOMOptionInputFDKey] = nil;
    }
    
    /* Configure for an input stream */
    if (options[kBOMOptionInputStreamKey]) {
        inputsFound++;

        NSInputStream *stream = options[kBOMOptionInputStreamKey];
        ReadN = ^ssize_t (void *buf, size_t nbyte, off_t offset) {
            size_t remain = nbyte;
            NSNumber *position = [stream propertyForKey: NSStreamFileCurrentOffsetKey];

            NSInteger nr;
            while (remain > 0) {
                nr = [stream read:(uint8_t *)buf maxLength:nbyte];
                if (nr < 0) {
                    copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"Error reading from stream=%@: %@", stream, stream.streamError].UTF8String);
                    return nr;
                }
                
                if (nr == 0)
                    break;
                
                remain -= nr;
            }
            
            if (![stream setProperty: position forKey: NSStreamFileCurrentOffsetKey]) {
                copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"Failed to reset current offset in input stream=%@: %@", stream, stream.streamError].UTF8String);
                return -1;
            }
            
            return nbyte - remain;
        };

        patchedOptions[kBOMOptionInputStreamKey] = nil;
    }
    
    /* Supplying zero inputs, multiple inputs, or inputs *and* a dest path -- is either invalid, or something we don't handle.
     * We just pass these cases through to the original function. */
    if (inputsFound == 0 || inputsFound > 1 || (inputsFound > 0 && destPath != NULL)) {
        XPFLog(@"xpf_BOMCopierCopyWithOptions: Invalid configuration");
        return orig_BOMCopierCopyWithOptions(copier, offset, destPath, options);
    }
    
    /* Read the file header */
    uint8_t hdr_buf[sizeof(PBZX_MAGIC)];
    ssize_t nread = ReadN(hdr_buf, sizeof(hdr_buf), offset);
    if (nread == -1)
        return NO;
    
    /* If it's not a pbzx stream, nothing for us to do */
    if (nread != sizeof(hdr_buf) || memcmp(hdr_buf, PBZX_MAGIC, sizeof(hdr_buf)) != 0)
        return orig_BOMCopierCopyWithOptions(copier, offset, destPath, options);
    
    XPFLog(@"xpf_BOMCopierCopyWithOptions: Translating pbzx stream");
    
    /* If it is a pbzx stream, we have to interpose ourself */
    int pipefds[2];
    if (pipe(pipefds) == -1) {
        copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"pipe(2): %s", strerror(errno)].UTF8String);
        return NO;
    }
    
    int readerFD = pipefds[0];
    int writerFD = pipefds[1];
    
    if (fcntl(readerFD, F_SETNOSIGPIPE, 1) == -1) {
        copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"fcntl(readerFD, F_SETNOSIGPIPE, ...): %s", strerror(errno)].UTF8String);
        return NO;
    }
    
    if (fcntl(writerFD, F_SETNOSIGPIPE, 1) == -1) {
        copier->_fatalErrorHandler(copier, [NSString stringWithFormat: @"fcntl(writerFD, F_SETNOSIGPIPE, ...): %s", strerror(errno)].UTF8String);
        return NO;
    }

    patchedOptions[kBOMOptionInputFDKey] = @(readerFD);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // TODO! Decompress the pbzx stream here!
        XPFLog(@"xpf_BOMCopierCopyWithOptions: XXX TODO");
        close(writerFD);
    });
    
    BOOL ret = orig_BOMCopierCopyWithOptions(copier, offset, destPath, patchedOptions);
    
    close(readerFD);
    return ret;
}

static BOOL xpf_BOMCopierCopy (BOMCopier *copier, off_t offset, const char *destPath) {
    return xpf_BOMCopierCopyWithOptions(copier, offset, destPath, nil);
}

XPF_REBIND_ENTRY("_BOMCopierCopyWithOptions", XPF_BM_PATH, (void **) &orig_BOMCopierCopyWithOptions, (uintptr_t) &xpf_BOMCopierCopyWithOptions);
XPF_REBIND_ENTRY("_BOMCopierCopy", XPF_BM_PATH, NULL, (uintptr_t) &xpf_BOMCopierCopy);
