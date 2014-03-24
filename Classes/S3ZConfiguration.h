//
//  S3ZConfiguration.h
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/17/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S3ZConfiguration : NSObject

@property (strong, nonatomic) NSString *awsAccessKeyID;
@property (strong, nonatomic) NSString *awsSecretKey;
@property (strong, nonatomic) NSString *awsBucket;
@property (strong, nonatomic) NSString *awsCDN;

@property (strong, nonatomic) NSString *zencoderAPI;
@property (strong, nonatomic) NSString *zencoderAPIKey;
@property (nonatomic) CGFloat zencoderTimeout;
@property (nonatomic) NSInteger zencoderRetries;

@property (strong, nonatomic) NSString *parseAPI;

@property (nonatomic) NSInteger cacheCapacity;
@property (strong, nonatomic) NSString *cachePath;

@property (nonatomic) NSInteger uploadRetries;

@end
