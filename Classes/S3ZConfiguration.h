//
//  S3ZConfiguration.h
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/17/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S3ZConfiguration : NSObject

@property (nonatomic) NSString *awsAccessKeyID;
@property (nonatomic) NSString *awsSecretKey;
@property (nonatomic) NSString *awsBucket;
@property (nonatomic) NSString *awsCDN;

@property (nonatomic) NSString *zencoderAPI;
@property (nonatomic) NSString *zencoderAPIKey;
@property (nonatomic) CGFloat zencoderTimeout;
@property (nonatomic) NSInteger zencoderRetries;

@property (nonatomic) NSString *parseAPI;

@property (nonatomic) NSInteger cacheCapacity;
@property (nonatomic) NSString *cachePath;

@property (nonatomic) NSInteger uploadRetries;

@end
