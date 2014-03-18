//
//  S3ZDownloadManager.h
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/11/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S3ZConfiguration.h"

@interface S3ZDownloadManager : NSObject

+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
+ (instancetype)sharedInstance;

- (void)downloadURL:(NSURL *)url
          withBlock:(void (^)(BOOL succeeded, NSURL *location, NSError *error))block
      progressBlock:(void (^)(float downloadProgress))progressBlock;

@end
