#import "SeafCustomHeaders.h"
#import <Security/Security.h>

NSString * const SeafCustomHeadersErrorDomain = @"com.seafile.custom-headers";

static BOOL HeaderError(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:SeafCustomHeadersErrorDomain code:code
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

@implementation SeafCustomHeaders
- (instancetype)initWithServer:(NSString *)server username:(NSString *)username {
    if ((self = [super init])) {
        NSURLComponents *parts = [NSURLComponents componentsWithString:server];
        parts.scheme = parts.scheme.lowercaseString;
        parts.host = parts.host.lowercaseString;
        if ([parts.scheme isEqualToString:@"https"] && parts.port.integerValue == 443) parts.port = nil;
        while ([parts.path hasSuffix:@"/"]) parts.path = [parts.path substringToIndex:parts.path.length - 1];
        _server = [parts.string copy] ?: [server copy];
        _username = [username copy];
    }
    return self;
}

- (NSMutableDictionary *)query {
    // JSON avoids ambiguous URL/username separators in the Keychain account key.
    NSData *scope = [NSJSONSerialization dataWithJSONObject:@[self.server, self.username] options:0 error:nil];
    NSString *account = [[NSString alloc] initWithData:scope encoding:NSUTF8StringEncoding];
    NSMutableDictionary *query = [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: SeafCustomHeadersErrorDomain,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecAttrSynchronizable: @NO} mutableCopy];
    NSString *group = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SeafCustomHeadersAccessGroup"];
    if (group.length) query[(__bridge id)kSecAttrAccessGroup] = group;
    return query;
}

- (NSDictionary *)load:(NSError **)error {
    NSMutableDictionary *query = [self query];
    query[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return @{ @"enabled": @NO, @"headers": @[] };
    if (status != errSecSuccess) {
        HeaderError(error, status, NSLocalizedString(@"Custom headers could not be read from Keychain. Unlock the device and try again.", nil));
        return nil;
    }
    NSData *data = CFBridgingRelease(result);
    id profile = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![profile isKindOfClass:NSDictionary.class] || ![profile[@"enabled"] isKindOfClass:NSNumber.class] ||
        ![SeafCustomHeaders validateHeaders:profile[@"headers"] error:error]) {
        HeaderError(error, 1, NSLocalizedString(@"The saved custom headers are invalid.", nil));
        return nil;
    }
    return profile;
}

- (BOOL)saveHeaders:(NSArray *)headers enabled:(BOOL)enabled error:(NSError **)error {
    if (![SeafCustomHeaders validateHeaders:headers error:error]) return NO;
    if (![SeafCustomHeaders URL:[NSURL URLWithString:self.server] matchesServer:self.server] || !self.username.length) {
        return HeaderError(error, 2, NSLocalizedString(@"Enter an HTTPS server and a username before configuring custom headers.", nil));
    }
    NSDictionary *profile = @{ @"enabled": @(enabled), @"headers": headers };
    NSData *data = [NSJSONSerialization dataWithJSONObject:profile options:0 error:error];
    if (!data) return NO;
    NSMutableDictionary *query = [self query];
    NSDictionary *attributes = @{(__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    return status == errSecSuccess || HeaderError(error, status, NSLocalizedString(@"Custom headers could not be saved to Keychain.", nil));
}

- (BOOL)remove:(NSError **)error {
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)[self query]);
    return status == errSecSuccess || status == errSecItemNotFound ||
        HeaderError(error, status, NSLocalizedString(@"Custom headers could not be removed from Keychain.", nil));
}

+ (BOOL)validateHeaders:(NSArray *)headers error:(NSError **)error {
    if (![headers isKindOfClass:NSArray.class] || headers.count > 20)
        return HeaderError(error, 3, NSLocalizedString(@"You can save up to 20 custom headers.", nil));
    NSCharacterSet *token = [NSCharacterSet characterSetWithCharactersInString:@"!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    NSSet *reserved = [NSSet setWithArray:@[@"authorization", @"proxy-authorization", @"host", @"cookie", @"set-cookie", @"content-type", @"content-length", @"connection", @"keep-alive", @"transfer-encoding", @"te", @"trailer", @"upgrade", @"proxy-connection", @"expect"]];
    NSMutableSet *names = [NSMutableSet set];
    NSUInteger total = 0;
    for (id entry in headers) {
        if (![entry isKindOfClass:NSDictionary.class]) return HeaderError(error, 4, NSLocalizedString(@"Invalid custom header.", nil));
        NSString *name = entry[@"name"], *value = entry[@"value"];
        if (![name isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class])
            return HeaderError(error, 4, NSLocalizedString(@"Invalid custom header.", nil));
        NSString *lower = name.lowercaseString;
        if (!name.length || [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 128 ||
            [name rangeOfCharacterFromSet:token.invertedSet].location != NSNotFound ||
            [reserved containsObject:lower] || [lower hasPrefix:@"x-seafile-"] || [names containsObject:lower])
            return HeaderError(error, 5, NSLocalizedString(@"Header names must be valid, unique and not reserved by Seafile or HTTP.", nil));
        if (!value.length || [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 4096)
            return HeaderError(error, 6, NSLocalizedString(@"Enter a header value of up to 4096 bytes.", nil));
        // NSURLRequest HTTP/1 field values: visible ASCII or obs-text, no controls.
        for (NSUInteger i = 0; i < value.length; i++) {
            unichar c = [value characterAtIndex:i];
            if (c < 32 || c == 127 || c > 255)
                return HeaderError(error, 7, NSLocalizedString(@"Header values cannot contain control characters or unsupported characters.", nil));
        }
        total += [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        [names addObject:lower];
    }
    return total <= 16384 || HeaderError(error, 8, NSLocalizedString(@"Custom headers cannot exceed 16 KiB in total.", nil));
}

+ (BOOL)URL:(NSURL *)URL matchesServer:(NSString *)server {
    NSURL *base = [NSURL URLWithString:server];
    if (!URL.host.length || !base.host.length || URL.user.length || URL.password.length || base.user.length || base.password.length) return NO;
    return [URL.scheme.lowercaseString isEqualToString:@"https"] &&
        [base.scheme.lowercaseString isEqualToString:@"https"] &&
        [URL.host.lowercaseString isEqualToString:base.host.lowercaseString] &&
        (URL.port ?: @443).integerValue == (base.port ?: @443).integerValue;
}

+ (NSURLRequest *)request:(NSURLRequest *)request applyingProfile:(NSDictionary *)profile server:(NSString *)server error:(NSError **)error {
    if (![profile[@"enabled"] boolValue] || ![self URL:request.URL matchesServer:server]) return request;
    if (![self validateHeaders:profile[@"headers"] error:error]) return nil;
    NSMutableURLRequest *result = [request mutableCopy];
    for (NSDictionary *header in profile[@"headers"]) {
        if ([result valueForHTTPHeaderField:header[@"name"]] != nil) {
            HeaderError(error, 9, NSLocalizedString(@"A custom header conflicts with a header required by this request.", nil));
            return nil;
        }
        [result setValue:header[@"value"] forHTTPHeaderField:header[@"name"]];
    }
    return result;
}

+ (NSURLRequest *)redirectRequest:(NSURLRequest *)request fromURL:(NSURL *)previous profile:(NSDictionary *)profile server:(NSString *)server {
    NSMutableURLRequest *clean = [request mutableCopy];
    for (NSDictionary *header in profile[@"headers"])
        [clean setValue:nil forHTTPHeaderField:header[@"name"]];
    BOOL sameOrigin = [previous.scheme.lowercaseString isEqual:request.URL.scheme.lowercaseString] &&
        [previous.host.lowercaseString isEqual:request.URL.host.lowercaseString] &&
        [(previous.port ?: ([previous.scheme.lowercaseString isEqual:@"https"] ? @443 : @80))
            isEqual:(request.URL.port ?: ([request.URL.scheme.lowercaseString isEqual:@"https"] ? @443 : @80))];
    if (!sameOrigin) {
        [clean setValue:nil forHTTPHeaderField:@"Authorization"];
        [clean setValue:nil forHTTPHeaderField:@"Cookie"];
    }
    return [self request:clean applyingProfile:profile server:server error:nil];
}
@end
