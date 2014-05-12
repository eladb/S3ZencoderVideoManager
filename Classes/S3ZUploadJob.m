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
    S3ZUploadJobStage stage;
    [stageValue getValue:&stage];
    self.stage = stage;
    self.putObjectRequest = [decoder decodeObjectForKey:@"putObjectRequest"];
    self.url = [decoder decodeObjectForKey:@"url"];
    self.key = [decoder decodeObjectForKey:@"key"];
    self.playURL = [decoder decodeObjectForKey:@"playURL"];
    self.downloadURL = [decoder decodeObjectForKey:@"downloadURL"];
    self.encodingRetries = [decoder decodeIntForKey:@"encodingRetries"];
    self.uploadingRetries = [decoder decodeIntForKey:@"uploadingRetries"];
    self.context = [decoder decodeObjectForKey:@"context"];
    self.cookie = [decoder decodeObjectForKey:@"cookie"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.jobID forKey:@"jobID"];
    [encoder encodeObject:self.userID forKey:@"userID"];
    [encoder encodeObject:self.encodingID forKey:@"encodingID"];
    [encoder encodeFloat:self.uploadProgress forKey:@"uploadProgress"];
    [encoder encodeObject:self.S3PathContainer forKey:@"S3PathContainer"];
    S3ZUploadJobStage stage = self.stage;
    NSValue *stageValue = [NSValue value:&stage withObjCType:@encode(S3ZUploadJobStage)];
    [encoder encodeObject:stageValue forKey:@"stage"];
    self.putObjectRequest.responseTimer = nil;
    [encoder encodeObject:self.putObjectRequest forKey:@"putObjectRequest"];
    [encoder encodeObject:self.url forKey:@"url"];
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeObject:self.playURL forKey:@"playURL"];
    [encoder encodeObject:self.downloadURL forKey:@"downloadURL"];
    [encoder encodeInt:self.encodingRetries forKey:@"encodingRetries"];
    [encoder encodeInt:self.uploadingRetries forKey:@"uploadingRetries"];
    [encoder encodeObject:self.context forKey:@"context"];
    [encoder encodeObject:self.cookie forKey:@"cookie"];
}

- (void)setStage:(S3ZUploadJobStage)stage
{
    _stage = stage;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"S3ZUploadJobStageDidChange" object:self];
}

extern NSString *NSStringFromS3ZUploadJob(S3ZUploadJobStage stage)
{
    NSArray *strings = @[
                         @"S3ZUploadJobQueued",
                         @"S3ZUploadJobUploading",
                         @"S3ZUploadJobUploadFailed",
                         @"S3ZUploadJobEncoding",
                         @"S3ZUploadJobEncodingFailed",
                         @"S3ZUploadJobDone"
                         ];
    return strings[stage];
}

- (NSString *)description
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<S3ZUploadJob: %@", self.jobID];
    
    if (self.stage) {
        [string appendFormat:@", Stage: %@", NSStringFromS3ZUploadJob(self.stage)];
    }
    if (self.stage == S3ZUploadJobUploading) {
        [string appendFormat:@", Upload Progress: %.2f%%", 100*self.uploadProgress];
    }
    if (self.stage == S3ZUploadJobEncodingFailed) {
        [string appendFormat:@", Uploading Retries: %d", self.uploadingRetries];
    }
    if (self.stage == S3ZUploadJobUploadFailed) {
        [string appendFormat:@", Encoding Retries: %d", self.encodingRetries];
    }
    
    [string appendFormat:@", Local URL: %@", self.url];
    [string appendFormat:@", Play URL: %@", self.playURL];
    [string appendFormat:@", Download URL: %@", self.downloadURL];
    [string appendFormat:@", User ID: %@", self.userID];
    
    if ((self.stage == S3ZUploadJobEncoding) || (self.stage == S3ZUploadJobEncodingFailed) || (self.stage == S3ZUploadJobDone)) {
        [string appendFormat:@", Encoding ID: %@", self.encodingID];
    }
    
    [string appendFormat:@", S3 Path: %@", self.S3PathContainer];
    [string appendFormat:@", S3 Key: %@", self.key];
    [string appendString:@">"];
    
    return [string copy];
}

@end
