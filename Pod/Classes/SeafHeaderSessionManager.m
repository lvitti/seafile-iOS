#import "SeafHeaderSessionManager.h"
#import <objc/runtime.h>

static char SeafHeaderContextKey;

@implementation SeafHeaderSessionManager
- (instancetype)initWithBaseURL:(NSURL *)url sessionConfiguration:(NSURLSessionConfiguration *)configuration {
    if ((self = [super initWithBaseURL:url sessionConfiguration:configuration])) {
        [self setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request) {
            NSDictionary *context = objc_getAssociatedObject(task, &SeafHeaderContextKey);
            if (!context) return request;
            // Preserve the task snapshot across redirects; never forward secrets to another origin.
            return [SeafCustomHeaders redirectRequest:request fromURL:response.URL
                                               profile:context[@"profile"] server:context[@"server"]];
        }];
    }
    return self;
}

- (NSURLRequest *)prepare:(NSURLRequest *)request context:(NSDictionary **)context error:(NSError **)error {
    SeafCustomHeaders *store = self.headerStore ? self.headerStore() : nil;
    NSDictionary *profile = @{ @"enabled": @NO, @"headers": @[] };
    if (store.username.length && [SeafCustomHeaders URL:request.URL matchesServer:store.server]) {
        profile = [store load:error];
        if (!profile) return nil; // Never silently send an incomplete authenticated request.
    }
    if (![profile[@"enabled"] boolValue]) profile = @{ @"enabled": @NO, @"headers": @[] };
    *context = @{ @"server": store.server ?: @"", @"profile": profile };
    return [SeafCustomHeaders request:request applyingProfile:profile server:store.server ?: @"" error:error];
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request uploadProgress:(void (^)(NSProgress *))uploadProgress downloadProgress:(void (^)(NSProgress *))downloadProgress completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completionHandler) completionHandler(nil, nil, error); });
        return nil;
    }
    NSURLSessionDataTask *task = [super dataTaskWithRequest:prepared uploadProgress:uploadProgress downloadProgress:downloadProgress completionHandler:completionHandler];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request progress:(void (^)(NSProgress *))progress destination:(NSURL *(^)(NSURL *, NSURLResponse *))destination completionHandler:(void (^)(NSURLResponse *, NSURL *, NSError *))completionHandler {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completionHandler) completionHandler(nil, nil, error); });
        return nil;
    }
    NSURLSessionDownloadTask *task = [super downloadTaskWithRequest:prepared progress:progress destination:destination completionHandler:completionHandler];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL progress:(void (^)(NSProgress *))progress completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completionHandler) completionHandler(nil, nil, error); });
        return nil;
    }
    NSURLSessionUploadTask *task = [super uploadTaskWithRequest:prepared fromFile:fileURL progress:progress completionHandler:completionHandler];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData progress:(void (^)(NSProgress *))progress completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completionHandler) completionHandler(nil, nil, error); });
        return nil;
    }
    NSURLSessionUploadTask *task = [super uploadTaskWithRequest:prepared fromData:bodyData progress:progress completionHandler:completionHandler];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request progress:(void (^)(NSProgress *))progress completionHandler:(void (^)(NSURLResponse *, id, NSError *))completionHandler {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completionHandler) completionHandler(nil, nil, error); });
        return nil;
    }
    NSURLSessionUploadTask *task = [super uploadTaskWithStreamedRequest:prepared progress:progress completionHandler:completionHandler];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

- (NSURLSessionDataTask *)rawDataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completion) completion(nil, nil, error); });
        return nil;
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:prepared completionHandler:completion];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}
- (NSURLSessionDownloadTask *)rawDownloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completion {
    NSDictionary *context; NSError *error;
    NSURLRequest *prepared = [self prepare:request context:&context error:&error];
    if (!prepared) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{ if (completion) completion(nil, nil, error); });
        return nil;
    }
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:prepared completionHandler:completion];
    objc_setAssociatedObject(task, &SeafHeaderContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}
@end
