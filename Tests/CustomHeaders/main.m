#import <Foundation/Foundation.h>
#import "SeafCustomHeaders.h"

static void Check(BOOL ok, NSString *message) {
    if (!ok) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}
static NSDictionary *Profile(NSString *value, BOOL enabled) {
    return @{ @"enabled": @(enabled), @"headers": @[@{@"name": @"CF-Access-Client-Secret", @"value": value}] };
}
int main(void) {
    @autoreleasepool {
        NSString *server = @"https://files.example.test/seafile";
        NSDictionary *profile = Profile(@"account-a", YES);
        Check([SeafCustomHeaders validateHeaders:profile[@"headers"] error:nil], @"Cloudflare header accepted");
        Check([SeafCustomHeaders validateHeaders:@[] error:nil], @"Empty list accepted");
        for (NSString *name in @[@"Authorization", @"HOST", @"Cookie", @"Content-Type", @"Transfer-Encoding", @"Connection", @"X-Seafile-OTP", @"Bad Name", @"X:Bad", @""]) {
            Check(![SeafCustomHeaders validateHeaders:@[@{@"name":name, @"value":@"value"}] error:nil], @"Reserved/invalid name rejected");
        }
        Check(![SeafCustomHeaders validateHeaders:@[@{@"name":@"X-Test", @"value":@"a"}, @{@"name":@"x-test", @"value":@"b"}] error:nil], @"Case-insensitive duplicates rejected");
        for (NSString *value in @[@"", @"a\rb", @"a\nb", @"a\tb", [NSString stringWithFormat:@"a%Cb", (unichar)0], @"😀"]) {
            Check(![SeafCustomHeaders validateHeaders:@[@{@"name":@"X-Test", @"value":value}] error:nil], @"Invalid value rejected");
        }
        NSString *longValue = [@"x" stringByPaddingToLength:4097 withString:@"x" startingAtIndex:0];
        Check(![SeafCustomHeaders validateHeaders:@[@{@"name":@"X-Test", @"value":longValue}] error:nil], @"Value byte limit enforced");
        NSMutableArray *many = [NSMutableArray array];
        for (NSInteger i=0; i<21; i++) [many addObject:@{@"name":[NSString stringWithFormat:@"X-%ld", (long)i], @"value":@"a"}];
        Check(![SeafCustomHeaders validateHeaders:many error:nil], @"Header count limit enforced");
        NSMutableArray *large = [NSMutableArray array];
        for (NSInteger i=0; i<5; i++) [large addObject:@{@"name":[NSString stringWithFormat:@"X-%ld", (long)i], @"value":[@"a" stringByPaddingToLength:4000 withString:@"a" startingAtIndex:0]}];
        Check(![SeafCustomHeaders validateHeaders:large error:nil], @"Aggregate byte limit enforced");
        for (NSString *target in @[@"https://files.example.test/api2/", @"https://FILES.example.test:443/download/a", @"https://files.example.test/seafhttp"]) {
            Check([SeafCustomHeaders URL:[NSURL URLWithString:target] matchesServer:server], @"Exact HTTPS origin accepted");
        }
        for (NSString *target in @[@"http://files.example.test/api2/", @"https://files.example.test:444/a", @"https://files.example.test.evil.test/a", @"https://sub.files.example.test/a", @"https://files.example.test@evil.test/a", @"https://user@files.example.test/a", @"https://storage.example.test/signed"]) {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:target]];
            NSURLRequest *result = [SeafCustomHeaders request:request applyingProfile:profile server:server error:nil];
            Check(![result valueForHTTPHeaderField:@"CF-Access-Client-Secret"], @"Foreign origin gets no headers");
        }
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://files.example.test/upload"]];
        request.HTTPMethod = @"POST";
        request.HTTPBody = [@"multipart bytes" dataUsingEncoding:NSUTF8StringEncoding];
        [request setValue:@"multipart/form-data; boundary=original" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"Token seafile" forHTTPHeaderField:@"Authorization"];
        NSURLRequest *a = [SeafCustomHeaders request:request applyingProfile:profile server:server error:nil];
        NSURLRequest *b = [SeafCustomHeaders request:request applyingProfile:Profile(@"account-b", YES) server:server error:nil];
        Check([[a valueForHTTPHeaderField:@"CF-Access-Client-Secret"] isEqual:@"account-a"], @"Account A value");
        Check([[b valueForHTTPHeaderField:@"CF-Access-Client-Secret"] isEqual:@"account-b"], @"Account B value");
        Check(![request valueForHTTPHeaderField:@"CF-Access-Client-Secret"], @"Input request is never mutated");
        Check([a.HTTPBody isEqual:request.HTTPBody] && [a.HTTPMethod isEqual:@"POST"] &&
            [[a valueForHTTPHeaderField:@"Content-Type"] isEqual:[request valueForHTTPHeaderField:@"Content-Type"]] &&
            [[a valueForHTTPHeaderField:@"Authorization"] isEqual:@"Token seafile"], @"Body, boundary and Seafile auth preserved");
        Check(![[SeafCustomHeaders request:request applyingProfile:Profile(@"a", NO) server:server error:nil] valueForHTTPHeaderField:@"CF-Access-Client-Secret"], @"Disabled headers not sent");
        NSError *error = nil;
        Check(![SeafCustomHeaders request:a applyingProfile:profile server:server error:&error] && error != nil, @"Collision fails instead of replacing an existing header");
        for (NSString *target in @[@"https://evil.test/a", @"https://files.example.test:444/a", @"http://files.example.test/a"]) {
            NSMutableURLRequest *redirect = [a mutableCopy]; redirect.URL = [NSURL URLWithString:target];
            [redirect setValue:@"session=private" forHTTPHeaderField:@"Cookie"];
            NSURLRequest *clean = [SeafCustomHeaders redirectRequest:redirect fromURL:a.URL profile:profile server:server];
            Check(![clean valueForHTTPHeaderField:@"CF-Access-Client-Secret"] && ![clean valueForHTTPHeaderField:@"Authorization"] && ![clean valueForHTTPHeaderField:@"Cookie"], @"Cross-origin redirect strips credentials");
        }
        NSMutableURLRequest *redirect = [a mutableCopy]; redirect.URL = [NSURL URLWithString:@"https://files.example.test:443/next"];
        NSURLRequest *same = [SeafCustomHeaders redirectRequest:redirect fromURL:a.URL profile:profile server:server];
        Check([[same valueForHTTPHeaderField:@"CF-Access-Client-Secret"] isEqual:@"account-a"] && [same.HTTPBody isEqual:a.HTTPBody], @"Same-origin redirect preserves headers and body");
        SeafCustomHeaders *store = [[SeafCustomHeaders alloc] initWithServer:@"HTTPS://FILES.EXAMPLE.TEST:443/seafile/" username:@"alice"];
        Check([store.server isEqual:@"https://files.example.test/seafile"], @"Storage URL normalized");
        puts("PASS: custom header validation, origin isolation, multipart preservation and redirect policy");
    }
    return 0;
}
