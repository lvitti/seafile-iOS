#import <AFNetworking/AFHTTPSessionManager.h>
#import "SeafCustomHeaders.h"

/// Applies per-account headers at task creation, including direct transfers.
@interface SeafHeaderSessionManager : AFHTTPSessionManager
@property (nonatomic, copy) SeafCustomHeaders *(^headerStore)(void);
- (NSURLSessionDataTask *)rawDataTaskWithRequest:(NSURLRequest *)request
                             completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion;
- (NSURLSessionDownloadTask *)rawDownloadTaskWithRequest:(NSURLRequest *)request
                                     completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completion;
@end
