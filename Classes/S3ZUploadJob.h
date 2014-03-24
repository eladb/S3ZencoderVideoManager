//
//  S3ZUploadJob.h
//  S3ZencoderVideoManager
//
//  Created by Genady Okrain on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AWSS3.h>

typedef NS_ENUM(NSInteger, S3ZUploadJobStage) {
    S3ZUploadJobQueued,
    S3ZUploadJobUploading,
    S3ZUploadJobUploadFailed,
    S3ZUploadJobEncoding,
    S3ZUploadJobEncodingFailed,
    S3ZUploadJobDone
};

@interface S3ZUploadJob : NSObject <NSCoding>

@property (strong, nonatomic) NSString *jobID;
@property (strong, nonatomic) NSString *userID;
@property (strong, nonatomic) NSString *S3PathContainer;
@property (strong, nonatomic) NSString *encodingID;
@property (nonatomic) float uploadProgress;  // 0..1
@property (nonatomic) S3ZUploadJobStage stage;
@property (strong, nonatomic) S3TransferOperation *transferOperation;
@property (strong, nonatomic) S3PutObjectRequest *putObjectRequest;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *key;
@property (strong, nonatomic) NSURL *playURL;
@property (strong, nonatomic) NSURL *downloadURL;
@property (nonatomic) int encodingRetries;
@property (nonatomic) int uploadingRetries;
@property (strong, nonatomic) id<NSCoding> context;

extern NSString *NSStringFromS3ZUploadJob(S3ZUploadJobStage stage);

@end
