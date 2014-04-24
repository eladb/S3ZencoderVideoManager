//
//  JVObserver.m
//  S3ZencoderVideoManagerExample
//
//  Created by Elad Ben-Israel on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import "S3ZObserver.h"

@interface S3ZObserver ()

@property (strong, nonatomic) id object;
@property (strong, nonatomic) NSString *keyPath;
@property (strong, nonatomic) void(^block)(void);

@end

@implementation S3ZObserver

- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath block:(void(^)(void))block
{
    if (!object || keyPath.length == 0) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        self.object = object;
        self.keyPath = keyPath;
        self.block = block;
        [self.object addObserver:self forKeyPath:self.keyPath options:NSKeyValueObservingOptionInitial context:nil];
    }
    return self;
}

+ (instancetype)observerForObject:(id)object keyPath:(NSString *)keyPath block:(void(^)(void))block
{
    return [[S3ZObserver alloc] initWithObject:object keyPath:keyPath block:block];
}

- (void)dealloc
{
    [self.object removeObserver:self forKeyPath:self.keyPath];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.block) {
        dispatch_async(dispatch_get_main_queue(), self.block);
    }
}

@end