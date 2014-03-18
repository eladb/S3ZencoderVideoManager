//
//  S3ZDownloadManager.m
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/11/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import "S3ZDownloadManager.h"

@interface S3ZDownloadManager () <NSURLSessionDownloadDelegate>

@property (strong, nonatomic) void (^progressBlock)(float downloadProgress);
@property (strong, nonatomic) void (^block)(BOOL succeeded, NSURL *location, NSError *error);
@property (strong, nonatomic) NSURLCache *cache;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLSessionDownloadTask *task;
@property (strong, nonatomic) S3ZConfiguration *configuration;

@end

@implementation S3ZDownloadManager

static S3ZDownloadManager *instance = NULL;

+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
{
    if (!instance) {
        instance = [[S3ZDownloadManager alloc] init];
        instance.configuration = configuration;
        
        instance.cache = [[NSURLCache alloc] initWithMemoryCapacity:instance.configuration.cacheCapacity diskCapacity:instance.configuration.cacheCapacity diskPath:instance.configuration.cachePath];
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        sessionConfiguration.URLCache = instance.cache;
        instance.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:instance delegateQueue:nil];
    }
}

+ (instancetype)sharedInstance
{
    NSAssert(instance, @"Please run setupWithConfiguration first!");
    return instance;
}

- (void)downloadURL:(NSURL *)url
          withBlock:(void (^)(BOOL succeeded, NSURL *location, NSError *error))block
      progressBlock:(void (^)(float downloadProgress))progressBlock
{
    // Kill old task
    if (self.task) {
        [self.task cancel];
    }
    
    // Set Blocks
    self.block = block;
    self.progressBlock = progressBlock;
    
    // Run Task
    self.task = [self.session downloadTaskWithURL:url];
    [self.task resume];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)downloadTask.response;
    if (HTTPURLResponse.statusCode != 200) {
        NSLog(@"HTTPURLResponse.statusCode != 200");
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"HTTPURLResponse.statusCode != 200", nil) };
        NSError *error = [NSError errorWithDomain:@"Uploader" code:0 userInfo:userInfo];
        
        self.task = nil;
        self.block(NO, nil, error);
    } else {
        // Cache
        NSData *data = [NSData dataWithContentsOfMappedFile:[location path]];
        NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:downloadTask.response data:data];
        [self.cache storeCachedResponse:cachedResponse forRequest:downloadTask.originalRequest];
        
        self.task = nil;
        self.block(YES, location, nil);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    self.progressBlock((float)((double)totalBytesWritten/(double)totalBytesExpectedToWrite));
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        NSLog(@"didCompleteWithError: %@", error);
        
        self.task = nil;
        self.block(NO, nil, error);
    }
}

@end
