//
//  JVObserver.h
//  S3ZencoderVideoManagerExample
//
//  Created by Elad Ben-Israel on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S3ZObserver : NSObject

@property (readonly, nonatomic) id object;
@property (readonly, nonatomic) NSString *keyPath;
@property (readonly, nonatomic) void(^block)(void);

+ (instancetype)observerForObject:(id)object keyPath:(NSString *)keyPath block:(void(^)(void))block;
- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath block:(void(^)(void))block;

@end