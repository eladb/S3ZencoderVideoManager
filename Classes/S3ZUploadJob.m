//
//  S3ZUploadJob.m
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import "S3ZUploadJob.h"

@implementation S3ZUploadJob

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    self.jobID = [decoder decodeObjectForKey:@"jobID"];
    self.userID = [decoder decodeObjectForKey:@"userID"];
    self.encodingID = [decoder decodeObjectForKey:@"encodingID"];
    self.uploadProgress = [decoder decodeFloatForKey:@"uploadProgress"];
    self.S3PathContainer = [decoder decodeObjectForKey:@"S3PathContainer"];
    NSValue *stageValue = [decoder decodeObjectForKey:@"stage"];
    JobUploadStage stage;
    [stageValue getValue:&stage];
    self.stage = stage;
    self.putObjectRequest = [decoder decodeObjectForKey:@"putObjectRequest"];
    self.url = [decoder decodeObjectForKey:@"url"];
    self.key = [decoder decodeObjectForKey:@"key"];
    self.playURL = [decoder decodeObjectForKey:@"playURL"];
    self.encodingRetries = [decoder decodeIntForKey:@"encodingRetries"];
    self.uploadingRetries = [decoder decodeIntForKey:@"uploadingRetries"];
    self.context = [decoder decodeObjectForKey:@"context"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.jobID forKey:@"jobID"];
    [encoder encodeObject:self.userID forKey:@"userID"];
    [encoder encodeObject:self.encodingID forKey:@"encodingID"];
    [encoder encodeFloat:self.uploadProgress forKey:@"uploadProgress"];
    [encoder encodeObject:self.S3PathContainer forKey:@"S3PathContainer"];
    JobUploadStage stage = self.stage;
    NSValue *stageValue = [NSValue value:&stage withObjCType:@encode(JobUploadStage)];
    [encoder encodeObject:stageValue forKey:@"stage"];
    self.putObjectRequest.responseTimer = nil;
    [encoder encodeObject:self.putObjectRequest forKey:@"putObjectRequest"];
    [encoder encodeObject:self.url forKey:@"url"];
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeObject:self.playURL forKey:@"playURL"];
    [encoder encodeInt:self.encodingRetries forKey:@"encodingRetries"];
    [encoder encodeInt:self.uploadingRetries forKey:@"uploadingRetries"];
    [encoder encodeObject:self.context forKey:@"context"];
}

- (void)setStage:(JobUploadStage)stage
{
    _stage = stage;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"S3ZUploadJobStageDidChange" object:self];
}

@end
