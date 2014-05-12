//
//  S3ZUploadManager.h
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S3ZConfiguration.h"
#import "S3ZUploadJob.h"

@interface S3ZUploadManager : NSObject

@property (readonly, strong, nonatomic) NSMutableArray *jobs;
@property (readonly, nonatomic) NSInteger jobCount;

+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
+ (instancetype)sharedInstance;

- (S3ZUploadJob *)enqueueVideo:(NSURL *)url forUserID:(NSString *)userID withContext:(id<NSCoding>)context cookie:(NSString *)cookie;
- (void)cancelJob:(NSString *)jobID;
- (void)cancelAllJobs;
- (void)reEncodeJob:(NSString *)jobID;
- (void)reUploadJob:(NSString *)jobID;

- (void)notifyAppBecomesActive;
- (void)notifyAppBecomesInactive;
- (void)notifyJobEncodingCompleted:(NSDictionary *)userInfo;

@end

