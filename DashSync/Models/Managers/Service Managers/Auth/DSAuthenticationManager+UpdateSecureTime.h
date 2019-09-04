//
//  DSAuthenticationManager+Private.h
//  AFNetworking
//
//  Created by Andrew Podkovyrin on 01/12/2018.
//

#import "DSAuthenticationManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationManager (Private)

- (void)updateSecureTime:(NSTimeInterval)secureTime;
- (void)updateSecureTimeFromResponseIfNeeded:(NSDictionary<NSString *, NSString *> *)responseHeaders;

@end

NS_ASSUME_NONNULL_END
