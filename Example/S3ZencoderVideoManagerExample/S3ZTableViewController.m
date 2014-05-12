//
//  S3ZTableViewController.m
//  S3ZencoderVideoManagerExample
//
//  Created by Genady Okrain on 3/6/14.
//  Copyright (c) 2014 Sugar Studio. All rights reserved.
//

#import <MobileCoreServices/UTCoreTypes.h>
#import <MediaPlayer/MediaPlayer.h>
#import "S3ZConfiguration.h"
#import "S3ZUploadManager.h"
#import "S3ZDownloadManager.h"
#import "S3ZTableViewController.h"
#import "S3ZObserver.h"

@interface S3ZTableViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic) MPMoviePlayerViewController *moviePlayer;
@property (nonatomic) NSMutableArray *downloadProgress;

@property (nonatomic) NSMutableArray *observers;

@end

@implementation S3ZTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.observers = [[NSMutableArray alloc] init];
    
    // Load Uploades
    [[S3ZUploadManager sharedInstance] notifyAppBecomesActive];
    
    // Reload the table each time the jobCount updates
    [self.observers addObject:[S3ZObserver observerForObject:[S3ZUploadManager sharedInstance] keyPath:@"jobCount" block:^{
        [self.tableView reloadData];
    }]];
    
    // Reload the table each time the state changes
    for (S3ZUploadJob *uploadJob in [S3ZUploadManager sharedInstance].jobs) {
        [self.observers addObject:[S3ZObserver observerForObject:uploadJob keyPath:@"stage" block:^{
            [self.tableView reloadData];
        }]];
        [self.observers addObject:[S3ZObserver observerForObject:uploadJob keyPath:@"uploadProgress" block:^{
            [self.tableView reloadData];
        }]];
    }
    
    self.clearsSelectionOnViewWillAppear = NO;
}

- (NSMutableArray *)downloadProgress
{
    if (!_downloadProgress) {
        _downloadProgress = [[NSMutableArray alloc] init];
        for (int i = 0; i < [S3ZUploadManager sharedInstance].jobCount; i++) {
            _downloadProgress[i] = [NSNull null];
        }
    }
    return _downloadProgress;
}

- (IBAction)addVideo:(id)sender
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    picker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    [self presentViewController:picker animated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
    S3ZUploadJob *uploadJob = [[S3ZUploadManager sharedInstance] enqueueVideo:url forUserID:@"uploader" withContext:nil cookie:nil];
    self.downloadProgress[[S3ZUploadManager sharedInstance].jobCount-1] = [NSNull null];
    
    // Reload the table each time the state changes
    [self.observers addObject:[S3ZObserver observerForObject:uploadJob keyPath:@"stage" block:^{
        [self.tableView reloadData];
    }]];
    [self.observers addObject:[S3ZObserver observerForObject:uploadJob keyPath:@"uploadProgress" block:^{
        [self.tableView reloadData];
    }]];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)clearAll:(id)sender
{
    [[S3ZUploadManager sharedInstance] cancelAllJobs];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2*[S3ZUploadManager sharedInstance].jobCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    S3ZUploadJob *uploadJob = (S3ZUploadJob *)[[S3ZUploadManager sharedInstance].jobs objectAtIndex:indexPath.row/2];
    cell.textLabel.text = uploadJob.key;
    if (indexPath.row%2) {
        cell.backgroundColor = [UIColor grayColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor whiteColor];
        if ([self.downloadProgress[indexPath.row/2] isKindOfClass:[NSNull class]]) {
            cell.detailTextLabel.text = @"";
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%f%%", [self.downloadProgress[indexPath.row/2] floatValue]*100];
        }
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor blackColor];
        if (uploadJob.stage == S3ZUploadJobQueued) {
            cell.detailTextLabel.text = @"S3ZUploadJobQueued";
        } else if (uploadJob.stage == S3ZUploadJobUploading) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"S3ZUploadJobUploading %f%%",uploadJob.uploadProgress*100];
        } else if (uploadJob.stage == S3ZUploadJobEncoding) {
            cell.detailTextLabel.text = @"S3ZUploadJobEncoding";
        } else if (uploadJob.stage == S3ZUploadJobDone) {
            cell.detailTextLabel.text = @"S3ZUploadJobDone";
        } else if (uploadJob.stage == S3ZUploadJobEncodingFailed) {
            cell.detailTextLabel.text = @"S3ZUploadJobEncodingFailed";
        } else if (uploadJob.stage == S3ZUploadJobUploadFailed) {
            cell.detailTextLabel.text = @"S3ZUploadJobUploadFailed";
        } else {
            NSLog(@"uploadJob.stage unknown value");
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    S3ZUploadJob *uploadJob = (S3ZUploadJob *)[[S3ZUploadManager sharedInstance].jobs objectAtIndex:indexPath.row/2];
    if (indexPath.row % 2) {
        if ((uploadJob.stage == S3ZUploadJobDone) || (uploadJob.stage == S3ZUploadJobEncoding) || (uploadJob.stage == S3ZUploadJobEncodingFailed))  {
            [[S3ZDownloadManager sharedInstance] downloadURL:uploadJob.downloadURL
                                                withBlock:^(BOOL succeeded, NSURL *location, NSError *error) {
                                                    if (!succeeded) {
                                                        self.downloadProgress[indexPath.row/2] = [NSNull null];
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            [self.tableView reloadData];
                                                        });
                                                    } else {
                                                        NSString *fileName = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], [uploadJob.downloadURL pathExtension]];
                                                        NSURL *destination = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
                                                        NSError *error;
                                                        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:&error];
                                                        if (error) {
                                                            NSLog(@"downloadTask error: %@", error);
                                                        }
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            self.moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:destination];
                                                            [self.moviePlayer.moviePlayer setControlStyle:MPMovieControlStyleFullscreen];
                                                            [self presentMoviePlayerViewControllerAnimated:self.moviePlayer];
                                                            [self.moviePlayer.moviePlayer play];
                                                        });
                                                    }
                                                } progressBlock:^(float downloadProgress) {
                                                    self.downloadProgress[indexPath.row/2] = [NSNumber numberWithFloat:downloadProgress];
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        [self.tableView reloadData];
                                                    });
                                                }];
        }
    } else {
        if (uploadJob.stage == S3ZUploadJobEncodingFailed) {
            [[S3ZUploadManager sharedInstance] reEncodeJob:uploadJob.jobID];
        } else if (uploadJob.stage == S3ZUploadJobUploadFailed) {
            [[S3ZUploadManager sharedInstance] reUploadJob:uploadJob.jobID];
        } else if (uploadJob.stage == S3ZUploadJobDone) {
            self.moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:uploadJob.playURL];
            [self.moviePlayer.moviePlayer setControlStyle:MPMovieControlStyleFullscreen];
            [self presentMoviePlayerViewControllerAnimated:self.moviePlayer];
            [self.moviePlayer.moviePlayer play];
        }
    }
}

@end
