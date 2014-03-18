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

typedef NS_ENUM(NSInteger, JobUploadStage) {
    UploadQueued,
    UploadUploading,
    UploadUploadingFailed,
    UploadEncoding,
    UploadEncodingFailed,
    UploadDone
};

@interface S3ZUploadJob : NSObject <NSCoding>

@property (nonatomic) NSString *jobID;
@property (nonatomic) NSString *userID;
@property (nonatomic) NSString *S3PathContainer;
@property (nonatomic) NSString *encodingID;
@property (nonatomic) float uploadProgress;  // 0..1
@property (nonatomic) JobUploadStage stage;
@property (nonatomic) S3TransferOperation *transferOperation;
@property (nonatomic) S3PutObjectRequest *putObjectRequest;
@property (nonatomic) NSURL *url;
@property (nonatomic) NSString *key;
@property (nonatomic) NSURL *playURL;
@property (nonatomic) int encodingRetries;
@property (nonatomic) int uploadingRetries;

@end
