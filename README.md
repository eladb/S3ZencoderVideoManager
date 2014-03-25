# S3ZencoderVideoManager

[![Build Status](https://travis-ci.org/sugarso/S3ZencoderVideoManager.png)](https://travis-ci.org/sugarso/S3ZencoderVideoManager)
[![Version](http://cocoapod-badges.herokuapp.com/v/S3ZencoderVideoManager/badge.png)](http://cocoadocs.org/docsets/S3ZencoderVideoManager)
[![Analytics](https://ga-beacon.appspot.com/UA-29713074-4
/S3ZencoderVideoManager/README)](https://github.com/igrigorik/ga-beacon)


## General Info

S3ZencoderVideoManager contains 2 independent modules:

1. S3ZUploadManager 

2. S3ZDownloadManager

The role of S3ZencoderVideoManager Uploader is a video upload queue to S3 and start encoding for HLS which is must for long/big video files on App Store apps. The encoding is done with Zencoder which is the best service because of API, uptime and compression. See the example for more info.

The role of S3ZencoderVideoManager Downloader is to be able to download big files with cache and progress support.

**The downloader is not a queue and each time you start a new download the old download will be cancelled.**


### S3ZUploadManager
Video uploading queue to S3 bucket and Zencoder encoding for [HLS] (https://developer.apple.com/library/ios/documentation/networkinginternet/conceptual/streamingmediaguide/UsingHTTPLiveStreaming/UsingHTTPLiveStreaming.html).

When the encoding is done Zencoder will send Push Notification using Parse.

**Important features:**

  1. All jobs should try to run in the background.
  2. When app becomes active, resume all jobs.
  3. On startup/active, reload encoding state from Zencoder and update stage if needed.

### S3ZDownloadManager
One file cached download task with done block and progress block.

*Starting new task will cancel the active task.*


## Usage

To run the example project; clone the repo, and run `pod install` from the Example directory first.


## Requirements

1. [AWS Account] (http://aws.amazon.com)

2. [Zencoder Account] (http://www.zencoder.com)

3. [Parse Account] (http://www.parse.com)

## Installation

S3ZencoderVideoManager is available through [CocoaPods](http://cocoapods.org), to install
it simply add the following line to your Podfile:

    pod "S3ZencoderVideoManager"
    
## Configuration

### S3ZConfiguration

*Run the following configuration code before first use:*

```objective-c
    S3ZConfiguration *configuration  = [[S3ZConfiguration alloc] init];
    configuration.awsAccessKeyID     = @"";                                            // AWS Access Key ID
    configuration.awsSecretKey       = @"";                                            // AWS Secret Key
    configuration.awsBucket          = @"";                                            // AWS Bucket
    configuration.awsCDN             = @"";                                            // AWS CloudFront (Full https)
    configuration.zencoderAPI        = @"https://app.zencoder.com/api/v2/jobs";        // Zencoder API
    configuration.zencoderAPIKey     = @"";                                            // Zencoder API Key
    configuration.zencoderTimeout    = 30.0;                                           // Polling time in seconds to check Zencoder status if Push wasn't received
    configuration.zencoderRetries    = 3;                                              // Number of Zencoder encoding retries before giving up
    configuration.parseAPI           = @"";                                            // Parse API - http://YOUR_USERNAME:YOUR_PASSWORD@APP_NAME.parseapp.com/notify
    configuration.cacheCapacity      = 100*1024*1024;                                  // Download Cache size in bytes
    configuration.cachePath          = @"cache.db";                                    // Download Cache file name
    configuration.uploadRetries      = 3;                                              // Number of uploading retries before giving up
    [S3ZUploadManager setupWithConfiguration:configuration];
    [S3ZDownloadManager setupWithConfiguration:configuration];
```

### Parse

*Parse configuration for push:* (https://parse.com/tutorials/ios-push-notifications)
```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Parse setApplicationId:@"" clientKey:@""];
    [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [[S3ZUploadManager sharedInstance] notifyJobEncodingCompleted:userInfo];
}
```

*Parse Cloud Code for sending the notifications using Zencoder:* (https://parse.com/docs/cloud_code_guide#webhooks)

```js
var express = require('express');
var app = express();
app.use(express.bodyParser());
 
app.post('/notify',
	express.basicAuth('YOUR_USERNAME', 'YOUR_PASSWORD'),
	function(req, res) {
		var job = req.body.job;
		var query = new Parse.Query(Parse.Installation);
		query.containedIn('deviceToken', [job.pass_through]);
		Parse.Push.send({		
			where: query,
			data: {
				alert: "Job Done!",
				state: job.state,
				id: job.id
			}
		});
		res.send('Success');
	}, function(error) {
    	res.status(500);
    	res.send('Error');
});
 
app.listen();
```

## API

### S3ZUploadJob

Each upload queue job can be found in one of the following states:

    S3ZUploadJobQueued
    S3ZUploadJobUploading
    S3ZUploadJobUploadFailed    // After uploadRetries
    S3ZUploadJobEncoding
    S3ZUploadJobEncodingFailed  // After zencoderRetries
    S3ZUploadJobDone

When starting a job the final play url can be used before the job done `@property (nonatomic) NSURL *playURL`.

Each job has it's own `@property (nonatomic) NSString *jobID`.

Each stage change will generate `S3ZUploadJobDidChange` notification with the `S3ZUploadJobStageDidChange` object.

### S3ZUploadManager

Array with all S3ZUploadJob jobs:
```objective-c
@property (readonly, nonatomic) NSMutableArray *jobs;
```

Number of jobs in the array:
```objective-c
@property (readonly, nonatomic) NSInteger jobsCount;
```

Setup function before first use:
```objective-c
+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
```

Accessing the shared instance:
```objective-c
+ (instancetype)sharedInstance;
```

Starting a new upload job:
```objective-c
- (S3ZUploadJob *)enqueueVideo:(NSURL *)url forUserID:(NSString *)userID withContext:(id<NSCoding>)context;
```

Example:
```objective-c
S3ZUploadJob *uploadJob = [[S3ZUploadManager sharedInstance] enqueueVideo:url forUserID:@"uploader" withContext:nil];
```

Cancelling an upload job:
```objective-c
- (void)cancelJob:(NSString *)jobID;
```

Cancelling all upload jobs:
```objective-c
- (void)cancelAllJobs;
```

Encoding again on UploadEncodingFailed state:
```objective-c
- (void)reEncodeJob:(NSString *)jobID;
```

Encoding again on UploadUploadingFailed state:
```objective-c
- (void)reUploadJob:(NSString *)jobID;
```

Run this function to read all upload jobs from disk:
```objective-c
- (void)notifyAppBecomesActive;
```

Run this function to write all upload jobs to disk:
```objective-c
- (void)notifyAppBecomesInactive;
```

Push notification when Zencoder job done:
```objective-c
- (void)notifyJobEncodingCompleted:(NSDictionary *)userInfo;
```

### S3ZDownloadManager

Setup function before first use:
```objective-c
+ (void)setupWithConfiguration:(S3ZConfiguration *)configuration;
```

Accessing the shared instance:
```objective-c
+ (instancetype)sharedInstance;
```

Starting downloading task:
```objective-c
- (void)downloadURL:(NSURL *)url
          withBlock:(void (^)(BOOL succeeded, NSURL *location, NSError *error))block
      progressBlock:(void (^)(float downloadProgress))progressBlock;
```

## Author

Genady Okrain, genady@okrain.com

## License

S3ZencoderVideoManager is available under the MIT license. See the LICENSE file for more info.

