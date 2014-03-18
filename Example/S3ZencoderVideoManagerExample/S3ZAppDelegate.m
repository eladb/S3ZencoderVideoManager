//
//  S3ZAppDelegate.m
//  S3ZencoderVideoManagerExample
//
//  Created by Genady Okrain on 3/17/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <Parse/Parse.h>
#import "S3ZAppDelegate.h"
#import "S3ZConfiguration.h"
#import "S3ZUploadManager.h"
#import "S3ZDownloadManager.h"

@implementation S3ZAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Configuration
    S3ZConfiguration *configuration  = [[S3ZConfiguration alloc] init];
    configuration.awsAccessKeyID    = @"";
    configuration.awsSecretKey      = @"";
    configuration.awsBucket         = @"";
    configuration.awsCDN            = @"";
    configuration.zencoderAPI       = @"";
    configuration.zencoderAPIKey    = @"";
    configuration.zencoderTimeout   = 0;
    configuration.zencoderRetries   = 0;
    configuration.parseAPI          = @"";
    configuration.cacheCapacity     = 0;
    configuration.cachePath         = @"";
    configuration.uploadRetries     = 0;
    [S3ZUploadManager setupWithConfiguration:configuration];
    [S3ZDownloadManager setupWithConfiguration:configuration];
    
    // Parse
    [Parse setApplicationId:@"" clientKey:@""];
    [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound];
    
    // Override point for customization after application launch.
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
}
- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    NSLog(@"Failed to get token, error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [[S3ZUploadManager sharedInstance] notifyJobEncodingCompleted:userInfo];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end

