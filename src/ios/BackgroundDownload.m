
#import "BackgroundDownload.h"

@implementation BackgroundDownload {
    bool ignoreNextError;
}

@synthesize session;
@synthesize downloadTask;

- (void)startAsync:(CDVInvokedUrlCommand*)command
{
    self.downloadUri = [command.arguments objectAtIndex:0];
    self.targetFile = [command.arguments objectAtIndex:1];
    self.callbackId = command.callbackId;
    self.fileType = @"MP4"; //default
    
    NSURLRequest    *req  = [NSURLRequest requestWithURL:[NSURL URLWithString:self.downloadUri]];
    NSURLConnection *conn = [NSURLConnection connectionWithRequest:req delegate:self];
    [conn start];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Downloading Started");
        NSString *urlToDownload = self.downloadUri;
        NSURL  *url = [NSURL URLWithString:urlToDownload];
        NSData *urlData = [NSData dataWithContentsOfURL:url];
        if ( urlData )
        {
                dispatch_async(dispatch_get_main_queue(), ^{
                [urlData writeToFile:self.filePath  atomically:YES];
                NSLog(@"File Saved !");
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
            });
        }
    });
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Timeout"
                                                    message:@"Unable to play media file."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    if ([[response MIMEType] rangeOfString:@"video/mp4" options:NSCaseInsensitiveSearch].location == NSNotFound)
    {
        self.fileType = @".MP3";  //get mime
    }
    else
    {
        self.fileType = @".MP4";
    }
    
    NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString  *documentsDirectory = [paths objectAtIndex:0];
    self.filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, [self.targetFile stringByAppendingString:self.fileType]];
}


- (NSURLSession *)backgroundSession
{
    static NSURLSession *backgroundSession = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.cordova.plugin.BackgroundDownload.BackgroundSession"];
        backgroundSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    });
    return backgroundSession;
}

- (void)stop:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* myarg = [command.arguments objectAtIndex:0];
    
    if (myarg != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Arg was null"];
    }
    
    [downloadTask cancel];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSMutableDictionary* progressObj = [NSMutableDictionary dictionaryWithCapacity:1];
    [progressObj setObject:[NSNumber numberWithInteger:totalBytesWritten] forKey:@"bytesReceived"];
    [progressObj setObject:[NSNumber numberWithInteger:totalBytesExpectedToWrite] forKey:@"totalBytesToReceive"];
    NSMutableDictionary* resObj = [NSMutableDictionary dictionaryWithCapacity:1];
    [resObj setObject:progressObj forKey:@"progress"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resObj];
    result.keepCallback = [NSNumber numberWithInteger: TRUE];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (ignoreNextError) {
        ignoreNextError = NO;
        return;
    }
    
    if (error != nil) {
        if ((error.code == -999)) {
            NSData* resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
            // resumeData is available only if operation was terminated by the system (no connection or other reason)
            // this happens when application is closed when there is pending download, so we try to resume it
            if (resumeData != nil) {
                ignoreNextError = YES;
                [downloadTask cancel];
                downloadTask = [self.session downloadTaskWithResumeData:resumeData];
                [downloadTask resume];
                return;
            }
        }
        CDVPluginResult* errorResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        [self.commandDelegate sendPluginResult:errorResult callbackId:self.callbackId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    //[fileManager removeItemAtPath:targetURL.path error: nil];
    //[fileManager createFileAtPath:targetURL.path contents:[fileManager contentsAtPath:[location path]] attributes:nil];
    
    NSURL *targetURL = [NSURL URLWithString:_targetFile];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[targetURL.path stringByAppendingString:self.fileType]];
    BOOL Success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
}
@end
