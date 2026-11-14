#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const SeafCustomHeadersErrorDomain;

/// One atomic, device-local Keychain item per normalized server URL and username.
/// No values are written to account info, preferences or logs. Reads are uncached
/// so app extensions see edits before their next request.
@interface SeafCustomHeaders : NSObject
@property (nonatomic, readonly, copy) NSString *server;
@property (nonatomic, readonly, copy) NSString *username;
- (instancetype)initWithServer:(NSString *)server username:(NSString *)username;
- (nullable NSDictionary *)load:(NSError * _Nullable * _Nullable)error;
- (BOOL)saveHeaders:(NSArray<NSDictionary<NSString *, NSString *> *> *)headers enabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
- (BOOL)remove:(NSError * _Nullable * _Nullable)error;
+ (BOOL)validateHeaders:(NSArray *)headers error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)URL:(nullable NSURL *)URL matchesServer:(NSString *)server;
+ (nullable NSURLRequest *)request:(NSURLRequest *)request applyingProfile:(NSDictionary *)profile server:(NSString *)server error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSURLRequest *)redirectRequest:(NSURLRequest *)request fromURL:(NSURL *)previous profile:(NSDictionary *)profile server:(NSString *)server;
@end
NS_ASSUME_NONNULL_END
