//
//  S3ZUploadManager.m
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

@import MobileCoreServices;

#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AWSS3.h>
#import "Parse.h"
#import "S3ZUploadManager.h"


@interface S3ZUploadManager () <AmazonServiceRequestDelegate>

@property (strong, nonatomic) S3TransferManager *transferManager;
@property (strong, nonatomic) NSMutableArray *jobs;
@property (readwrite, nonatomic) NSInteger jobCount;
@property (strong, nonatomic) S3ZConfiguration *configuration;

@end

@implementation S3ZUploadManager

static S3ZUploadManager *instance = NULL;

+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
{
    if (!instance) {
        instance = [[S3ZUploadManager alloc] init];
        instance.configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
}

+ (instancetype)sharedInstance
{
    NSAssert(instance, @"Please run setupWithConfiguration first!");
    return instance;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void)applicationDidEnterBackground
{
    __block UIBackgroundTaskIdentifier background_task;
    background_task = [[UIApplication sharedApplication]  beginBackgroundTaskWithExpirationHandler:^{
        [[S3ZUploadManager sharedInstance] notifyAppBecomesInactive];
        [[UIApplication sharedApplication] endBackgroundTask:background_task];
        background_task = UIBackgroundTaskInvalid;
    }];
}

+ (void)applicationWillEnterForeground
{
    [[S3ZUploadManager sharedInstance] notifyAppBecomesActive];
}

/// When app is awake. Resume upload of previous jobs (if exits).
///
- (void)notifyAppBecomesActive
{
    //NSLog(@"notifyAppBecomesActive");
    if (!self.jobCount) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSData *data = [userDefaults objectForKey:@"jobs"];
        if (data) {
            self.jobs = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
            self.jobCount = [self.jobs count];
            for (S3ZUploadJob *uploadJob in self.jobs) {
                if ((uploadJob.stage == S3ZUploadJobUploading) || (uploadJob.stage == S3ZUploadJobQueued)) {
                    if (![[NSFileManager defaultManager] fileExistsAtPath:[uploadJob.url path]]) {
                        NSLog(@"notifyAppBecomesActive: file not found");
                        uploadJob.stage = S3ZUploadJobUploadFailed;
                    } else {
                        if (uploadJob.putObjectRequest) {
                            uploadJob.transferOperation = [self.transferManager upload:uploadJob.putObjectRequest];
                        } else {
                            uploadJob.transferOperation = [self beginTransferManagerUpload:[uploadJob.url path] bucket:self.configuration.awsBucket key:uploadJob.key];
                        }
                    }
                }
            }
        }
    }

    for (S3ZUploadJob *uploadJob in self.jobs) {
        if (uploadJob.stage == S3ZUploadJobEncoding) {
            [self updateEncodingStatusForJob:uploadJob.jobID];
        }
    }
}

- (void)notifyAppBecomesInactive
{
    //NSLog(@"notifyAppBecomesInactive");
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.jobs];
    [userDefaults setObject:data forKey:@"jobs"];
    [userDefaults synchronize];
}

- (NSString *)iso8601UrlDate:(NSURL *)url
{
    NSDate *fileDate;
    [url getResourceValue:&fileDate forKey:NSURLContentModificationDateKey error:0];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HHmmss"];
    NSString *iso8601String = [dateFormatter stringFromDate:fileDate];
    return iso8601String;
}

// Code from http://stackoverflow.com/a/10988403/48062
- (NSString*)fileMD5:(NSString*)path
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) { // file didnt exist
        NSLog(@"ERROR GETTING FILE MD5");
        return nil;
    }

    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);

    BOOL done = NO;
    while (!done) {
        NSData *fileData = [handle readDataOfLength: 2048];
        CC_MD5_Update(&md5, [fileData bytes], (int)[fileData length]);
        if ([fileData length] == 0) {
            done = YES;
        }
    }

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString *s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    return s;
}

- (S3ZUploadJob *)enqueueVideo:(NSURL *)url forUserID:(NSString *)userID withContext:(id<NSCoding>)context cookie:(NSString *)cookie
{
    return [self enqueueVideo:url forUserID:userID withContext:context cookie:cookie toContainer:[self iso8601UrlDate:url]];
}

- (S3ZUploadJob *)enqueueVideo:(NSURL *)url forUserID:(NSString *)userID withContext:(id<NSCoding>)context cookie:(NSString *)cookie toContainer:(NSString *)container
{
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    NSAssert(fileExists, @"File does not exists!");
    if (!fileExists) {
        return nil;
    }

    NSString *fileMD5 = [self fileMD5:[url path]];
    NSString *S3PathContainer = nil;
    // If no container was supplied, use md5 as file container.
    if(!container) {
        S3PathContainer = fileMD5;
    } else {
        S3PathContainer = [NSString stringWithFormat:@"%@-%@", container, [fileMD5 substringToIndex:8]];
    }

    // Save the file for the upload process
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *newPath = [NSString stringWithFormat:@"%@/%@.MOV", documentsDirectory, S3PathContainer];
    [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:newPath error:nil];

    NSString *key = [NSString stringWithFormat:@"%@/%@/MASTER.MOV", userID, S3PathContainer];

    S3ZUploadJob *uploadJob = [[S3ZUploadJob alloc] init];
    uploadJob.S3PathContainer = S3PathContainer;
    uploadJob.jobID = [[NSUUID UUID] UUIDString];
    uploadJob.userID = userID;
    uploadJob.url = [NSURL URLWithString:newPath];
    uploadJob.key = key;
    uploadJob.stage = S3ZUploadJobQueued;
    uploadJob.cookie = cookie;
    uploadJob.context = context;

    NSString *play = [NSString stringWithFormat:@"%@/%@/%@/video.m3u8", self.configuration.awsCDN, uploadJob.userID, uploadJob.S3PathContainer];
    NSString *download = [NSString stringWithFormat:@"%@/%@/%@/MASTER.MOV", self.configuration.awsCDN, uploadJob.userID, uploadJob.S3PathContainer];
    uploadJob.playURL = [NSURL URLWithString:play];
    uploadJob.downloadURL = [NSURL URLWithString:download];
    
    
    // S3TransferOperation might not always contain the put request. (Really??)
    uploadJob.transferOperation = [self beginTransferManagerUpload:newPath bucket:self.configuration.awsBucket key:key];
    uploadJob.putObjectRequest = uploadJob.transferOperation.putRequest;
    
    [self.jobs addObject:uploadJob];
    self.jobCount++;
    
    [self notifyAppBecomesInactive];
    
    return uploadJob;
}

NSString* fileMIMEType(NSString* file)
{
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[file pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    return (__bridge NSString *)MIMEType;
}

- (S3TransferOperation *)beginTransferManagerUpload:(NSString *)filename bucket:(NSString *)bucket key:(NSString *)key;
{
    // Implementation based upon https://forums.aws.amazon.com/thread.jspa?threadID=118234
    S3PutObjectRequest *putObjectRequest = [[S3PutObjectRequest alloc] initWithKey:key inBucket:bucket];
    putObjectRequest.data = [NSData dataWithContentsOfFile:filename];;
    // We do not set contentType = [file contentType]; because we let S3 deduce this automatically.
    putObjectRequest.delegate = self;
    putObjectRequest.cannedACL = [S3CannedACL publicRead];
    putObjectRequest.contentType = fileMIMEType(filename);
    
    NSLog(@"Uploading %@ to %@/%@", filename, bucket, key);
    
    return [self.transferManager upload:putObjectRequest];
}

- (void)encodeJob:(NSString *)jobID
{
    S3ZUploadJob *uploadJob = [self getJobWithJobID:jobID];
    if (uploadJob) {
        // Paths for files
        NSString *input = [NSString stringWithFormat:@"s3://%@/%@", self.configuration.awsBucket, uploadJob.key];
        NSString *output = [NSString stringWithFormat:@"s3://%@/%@/%@/", self.configuration.awsBucket, uploadJob.userID, uploadJob.S3PathContainer];

        NSString *cookie = uploadJob.cookie.length > 0 ? uploadJob.cookie : @"";
        
        // Run Zencoder
        NSDictionary *requestDictionary = @{
                                            @"input": input,
                                            @"pass_through": cookie,
                                            @"notifications": @[
                                                    self.configuration.parseAPI,
                                                    ],
                                            @"output": @[
                                                    @{
                                                        @"base_url": output,
                                                        @"filename": @"video.mp4",
                                                        @"h264_profile": @"main",
                                                        @"speed" : @1,
                                                        @"quality": @3,
//                                                        @"video_bitrate": @2500, // Deduced following https://support.google.com/youtube/answer/2853702?hl=en logic.
//                                                        @"audio_normalize": @true
                                                        @"public": @1
                                                        },
                                                    // @{
                                                    //     @"audio_bitrate": @64,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"filename": @"file-64k.m3u8",
                                                    //     @"format": @"aac",
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"audio_normalize": @true
                                                    //     },
                                                    // @{
                                                    //     @"audio_bitrate": @56,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"decoder_bitrate_cap": @360,
                                                    //     @"decoder_buffer_size": @840,
                                                    //     @"filename": @"file-240k.m3u8",
                                                    //     @"max_frame_rate": @15,
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"video_bitrate": @184,
                                                    //     @"width": @400,
                                                    //     @"format": @"ts",
                                                    //     @"audio_normalize": @true
                                                    //     },
                                                    // @{
                                                    //     @"audio_bitrate": @56,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"decoder_bitrate_cap": @578,
                                                    //     @"decoder_buffer_size": @1344,
                                                    //     @"filename": @"file-440k.m3u8",
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"video_bitrate": @384,
                                                    //     @"width": @400,
                                                    //     @"format": @"ts",
                                                    //     @"audio_normalize": @true
                                                    //     },
                                                    // @{
                                                    //     @"audio_bitrate": @56,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"decoder_bitrate_cap": @960,
                                                    //     @"decoder_buffer_size": @2240,
                                                    //     @"filename": @"file-640k.m3u8",
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"video_bitrate": @584,
                                                    //     @"width": @480,
                                                    //     @"format": @"ts",
                                                    //     @"audio_normalize": @true
                                                    //     },
//                                                    @{
//                                                        @"audio_bitrate": @56,
//                                                        @"audio_sample_rate": @22050,
//                                                        @"base_url": output,
//                                                        @"decoder_bitrate_cap": @1500,
//                                                        @"decoder_buffer_size": @4000,
//                                                        @"filename": @"file-1040k.m3u8",
//                                                        @"public": @1,
//                                                        @"type": @"segmented",
//                                                        @"video_bitrate": @1000,
//                                                        @"width": @640,
//                                                        @"format": @"ts",
//                                                        @"segment_seconds": @2,
//                                                        //@"audio_normalize": @true
//                                                        },
                                                    // @{
                                                    //     @"audio_bitrate": @56,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"decoder_bitrate_cap": @2310,
                                                    //     @"decoder_buffer_size": @5390,
                                                    //     @"filename": @"file-1540k.m3u8",
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"video_bitrate": @1484,
                                                    //     @"width": @960,
                                                    //     @"format": @"ts",
                                                    //     @"audio_normalize": @true
                                                    //     },
                                                    // @{
                                                    //     @"audio_bitrate": @56,
                                                    //     @"audio_sample_rate": @22050,
                                                    //     @"base_url": output,
                                                    //     @"decoder_bitrate_cap": @3060,
                                                    //     @"decoder_buffer_size": @7140,
                                                    //     @"filename": @"file-2040k.m3u8",
                                                    //     @"public": @1,
                                                    //     @"type": @"segmented",
                                                    //     @"video_bitrate": @1984,
                                                    //     @"width": @1024,
                                                    //     @"format": @"ts",
                                                    //     @"audio_normalize": @true
                                                    //     },
                                                    @{
                                                        @"max_video_bitrate" : @800,
                                                        @"size" : @"640x360",
                                                        @"speed" : @1,
                                                        @"quality" :@3,
                                                        @"filename":@"HLS.m3u8",
                                                        @"type":@"segmented",
                                                        @"segment_seconds":@3,
                                                        @"format":@"ts",
                                                        @"base_url": output,
                                                        @"public":@1
                                                    },
                                                    @{
                                                        @"base_url": output,
                                                        @"filename": @"video.m3u8",
                                                        @"public": @1,
                                                        @"type": @"playlist",
                                                        @"streams": @[
                                                                // @{
                                                                //     @"bandwidth": @2040,
                                                                //     @"path": @"file-2040k.m3u8"
                                                                //     },
                                                                // @{
                                                                //     @"bandwidth": @1540,
                                                                //     @"path": @"file-1540k.m3u8"
                                                                //     },
//                                                                @{
//                                                                    @"bandwidth": @1040,
//                                                                    @"path": @"file-1040k.m3u8"
//                                                                    }//,
                                                                // @{
                                                                //     @"bandwidth": @640,
                                                                //     @"path": @"file-640k.m3u8"
                                                                //     },
                                                                // @{
                                                                //     @"bandwidth": @440,
                                                                //     @"path": @"file-440k.m3u8"
                                                                //     },
                                                                // @{
                                                                //     @"bandwidth": @240,
                                                                //     @"path": @"file-240k.m3u8"
                                                                //     },
                                                                // @{
                                                                //     @"bandwidth": @64,
                                                                //     @"path": @"file-64k.m3u8"
                                                                //     }
                                                                @{
                                                                    @"bandwidth": @900,
                                                                    @"path": @"HLS.m3u8",
                                                                    }//,
                                                                ],
                                                        }
                                                    ]
                                            };

        // Request
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.configuration.zencoderAPI]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:self.configuration.zencoderAPIKey forHTTPHeaderField:@"Zencoder-Api-Key"];
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:requestDictionary options:0 error:0]];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"encodeJob called (%d): %@", uploadJob.encodingRetries, error);
                if (uploadJob.encodingRetries < self.configuration.zencoderRetries) {
                    [self encodeJob:jobID];
                    uploadJob.encodingRetries++;
                } else {
                    uploadJob.stage = S3ZUploadJobEncodingFailed;
                }
            } else {
                NSDictionary *returnDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:0];
                NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
                if ((HTTPURLResponse.statusCode < 200) || (HTTPURLResponse.statusCode >= 300)) {
                    NSLog(@"HTTPURLResponse.statusCode == %ld (%d)", (long)HTTPURLResponse.statusCode, uploadJob.encodingRetries);
                    if (uploadJob.encodingRetries < self.configuration.zencoderRetries) {
                        [self encodeJob:jobID];
                        uploadJob.encodingRetries++;
                    } else {
                        uploadJob.stage = S3ZUploadJobEncodingFailed;
                    }
                } else {
                    uploadJob.stage = S3ZUploadJobEncoding;
                    NSNumber *encodingID = returnDictionary[@"id"];
                    uploadJob.encodingID = [encodingID stringValue];
                    [self notifyAppBecomesInactive];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.configuration.zencoderTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self updateEncodingStatusForJob:uploadJob.jobID];
                    });
                }
            }
        }];
        [task resume];
    }
}

- (void)updateEncodingStatusForJob:(NSString *)jobID
{
    S3ZUploadJob *uploadJob = [self getJobWithJobID:jobID];
    if (uploadJob) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@.json?api_key=%@", self.configuration.zencoderAPI, uploadJob.encodingID, self.configuration.zencoderAPIKey]];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"updateEncodingStatusForJob called (%d): %@", uploadJob.encodingRetries, error);
                if (uploadJob.encodingRetries < self.configuration.zencoderRetries) {
                    [self updateEncodingStatusForJob:jobID];
                    uploadJob.encodingRetries++;
                } else {
                    uploadJob.stage = S3ZUploadJobEncodingFailed;
                }
            } else {
                NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
                if ((HTTPURLResponse.statusCode < 200) || (HTTPURLResponse.statusCode >= 300)) {
                    NSLog(@"HTTPURLResponse.statusCode == %ld (%d)", (long)HTTPURLResponse.statusCode, uploadJob.encodingRetries);
                    if (uploadJob.encodingRetries < self.configuration.zencoderRetries) {
                        [self updateEncodingStatusForJob:jobID];
                        uploadJob.encodingRetries++;
                    } else {
                        uploadJob.stage = S3ZUploadJobEncodingFailed;
                    }
                } else {
                    NSDictionary *returnDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:0];
                    [self notifyJobEncodingCompleted:returnDictionary[@"job"]];
                }
            }
        }];
        [task resume];
    }
}

- (void)cancelJob:(NSString *)jobID
{
    S3ZUploadJob *uploadJob = [self getJobWithJobID:jobID];
    if (uploadJob) {
        // Cancel
        [uploadJob.transferOperation cancel];
        uploadJob.transferOperation = nil;
        
        // Remove from jobs
        [self.jobs removeObject:uploadJob];
        self.jobCount--;
    }
}

- (void)notifyJobEncodingCompleted:(NSDictionary *)userInfo
{
    NSString *state = userInfo[@"state"];
    NSNumber *encodingIDNumber = userInfo[@"id"];
    NSString *encodingID = [encodingIDNumber stringValue];
    S3ZUploadJob *uploadJob = [self getJobWithEncodingID:encodingID];
    if (uploadJob) {
        if ([state isEqualToString:@"finished"]) {
            uploadJob.stage = S3ZUploadJobDone;
            [self notifyAppBecomesInactive];
        } else if ([state isEqualToString:@"failed"]) {
            NSLog(@"notifyJobEncodingCompleted (%d): failed", uploadJob.encodingRetries);
            if (uploadJob.encodingRetries < self.configuration.zencoderRetries) {
                [self reEncodeJob:uploadJob.jobID];
                uploadJob.encodingRetries++;
            } else {
                uploadJob.stage = S3ZUploadJobEncodingFailed;
            }
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.configuration.zencoderTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self updateEncodingStatusForJob:uploadJob.jobID];
            });
        }
    }
}

- (void)reEncodeJob:(NSString *)jobID
{
    // Start new job
    [self encodeJob:jobID];
}

- (void)reUploadJob:(NSString *)jobID
{
    S3ZUploadJob *uploadJob = [self getJobWithJobID:jobID];
    if (uploadJob) {
        if (uploadJob.transferOperation) {
            NSLog(@"reUploadJob: transferOperation");
            uploadJob.transferOperation = [self.transferManager resume:uploadJob.transferOperation requestDelegate:self];
        } else {
            NSLog(@"reUploadJob: !transferOperation");
            uploadJob.transferOperation = [self beginTransferManagerUpload:[uploadJob.url path] bucket:self.configuration.awsBucket key:uploadJob.key];
        }
    }
}

- (void)cancelAllJobs
{
    [self.transferManager cancelAllTransfers];
    self.jobs = nil;
    self.jobCount = 0;
    [[S3ZUploadManager sharedInstance] notifyAppBecomesInactive];
}

- (S3ZUploadJob *)getJobWithJobID:(NSString *)jobID
{
    S3ZUploadJob *uploadJob;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jobID LIKE %@", jobID];
    NSArray *uploadJobs = [self.jobs filteredArrayUsingPredicate:predicate];
    if (uploadJobs.count == 1) {
        uploadJob = uploadJobs[0];
    } else {
        NSLog(@"getJobWithJobID !uploadJob: jobID == %@", jobID);
    }
    return uploadJob;
}

- (S3ZUploadJob *)getJobWithKey:(NSString *)key
{
    S3ZUploadJob *uploadJob;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"key LIKE %@", key];
    NSArray *uploadJobs = [self.jobs filteredArrayUsingPredicate:predicate];
    if (uploadJobs.count == 1) {
        uploadJob = uploadJobs[0];
    } else {
        NSLog(@"getJobWithKey !uploadJob: key == %@", key);
    }
    return uploadJob;
}

- (S3ZUploadJob *)getJobWithEncodingID:(NSString *)encodingID
{
    S3ZUploadJob *uploadJob;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"encodingID LIKE %@", encodingID];
    NSArray *uploadJobs = [self.jobs filteredArrayUsingPredicate:predicate];
    if (uploadJobs.count == 1) {
        uploadJob = uploadJobs[0];
    } else {
        NSLog(@"getJobWithEncodingID !uploadJob: encodingID == %@", encodingID);
    }
    return uploadJob;
}

- (NSMutableArray *)jobs
{
    if (!_jobs) {
        _jobs = [[NSMutableArray alloc] init];
    }
    return _jobs;
}

- (S3TransferManager *)transferManager
{
    if (!_transferManager) {
        // Initialize the S3 Client.
        AmazonS3Client *s3 = [[AmazonS3Client alloc] initWithAccessKey:self.configuration.awsAccessKeyID
                                                         withSecretKey:self.configuration.awsSecretKey];

        // Initialize the S3TransferManager
        _transferManager = [S3TransferManager new];
        _transferManager.s3 = s3;
        _transferManager.operationQueue.maxConcurrentOperationCount = 1;
        _transferManager.delegate = self;
    }
    return _transferManager;
}

#pragma mark - AmazonServiceRequestDelegate

- (void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"didReceiveResponse called: %@", response);
}

- (void)request:(AmazonServiceRequest *)request didSendData:(long long) bytesWritten totalBytesWritten:(long long)totalBytesWritten totalBytesExpectedToWrite:(long long)totalBytesExpectedToWrite
{
    NSString *key = ((S3PutObjectRequest *)request).key;
    S3ZUploadJob *uploadJob = [self getJobWithKey:key];
    if (uploadJob) {
        uploadJob.uploadProgress = (CGFloat)((double)totalBytesWritten/(double)totalBytesExpectedToWrite);
        uploadJob.stage = S3ZUploadJobUploading;
        [self notifyAppBecomesInactive];
    } else {
        NSLog(@"didSendData !uploadJob: key == %@", key);
    }
}

- (void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response
{
    NSString *key = ((S3PutObjectRequest *)request).key;
    S3ZUploadJob *uploadJob = [self getJobWithKey:key];
    if (uploadJob) {
        [[NSFileManager defaultManager] removeItemAtPath:[uploadJob.url path] error:nil];
        [self encodeJob:uploadJob.jobID];
    } else {
        NSLog(@"didFailWithServiceException !uploadJob: key == %@", key);
    }
}

- (void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error
{
    NSString *key = ((S3PutObjectRequest *)request).key;
    S3ZUploadJob *uploadJob = [self getJobWithKey:key];
    if (uploadJob) {
        NSLog(@"didFailWithError called (%d): %@", uploadJob.uploadingRetries, error);
        if (uploadJob.uploadingRetries < self.configuration.uploadRetries) {
            [uploadJob.transferOperation cancel];
            uploadJob.transferOperation = nil;
            [self reUploadJob:uploadJob.jobID];
            uploadJob.uploadingRetries++;
        } else {
            uploadJob.stage = S3ZUploadJobUploadFailed;
        }
    } else {
        NSLog(@"didFailWithError !uploadJob: key == %@", key);
    }
}

- (void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)exception
{
    NSString *key = ((S3PutObjectRequest *)request).key;
    S3ZUploadJob *uploadJob = [self getJobWithKey:key];
    if (uploadJob) {
        NSLog(@"didFailWithServiceException called (%d): %@", uploadJob.uploadingRetries, exception);
        if (uploadJob.uploadingRetries < self.configuration.uploadRetries) {
            [uploadJob.transferOperation cancel];
            uploadJob.transferOperation = nil;
            [self reUploadJob:uploadJob.jobID];
            uploadJob.uploadingRetries++;
        } else {
            uploadJob.stage = S3ZUploadJobUploadFailed;
        }
    } else {
        NSLog(@"didFailWithServiceException !uploadJob: key == %@", key);
    }
}

@end
