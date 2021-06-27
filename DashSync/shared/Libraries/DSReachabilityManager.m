//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Copyright (c) 2015 Michal Zaborowski. All rights reserved.
// Copyright (c) 2011–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "DSReachabilityManager.h"
#if !TARGET_OS_WATCH

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <netinet6/in6.h>

NSString *const DSReachabilityDidChangeNotification = @"org.dash.networking.reachability.change";
NSString *const DSReachabilityNotificationStatusItem = @"DSReachabilityNotificationStatusItem";

typedef void (^DSReachabilityStatusBlock)(DSReachabilityStatus status);

typedef NS_ENUM(NSUInteger, DSReachabilityAssociation)
{
    DSReachabilityForAddress = 1,
    DSReachabilityForAddressPair = 2,
    DSReachabilityForName = 3,
};

static DSReachabilityStatus DSReachabilityStatusForFlags(SCNetworkReachabilityFlags flags) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));

    DSReachabilityStatus status = DSReachabilityStatusUnknown;
    if (isNetworkReachable == NO) {
        status = DSReachabilityStatusNotReachable;
    }
#if TARGET_OS_IPHONE
    else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = DSReachabilityStatusReachableViaWWAN;
    }
#endif
    else {
        status = DSReachabilityStatusReachableViaWiFi;
    }

    return status;
}

static void DSReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkReachabilityFlags flags, void *info) {
    DSReachabilityStatus status = DSReachabilityStatusForFlags(flags);
    DSReachabilityStatusBlock block = (__bridge DSReachabilityStatusBlock)info;
    if (block) {
        block(status);
    }


    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSDictionary *userInfo = @{DSReachabilityNotificationStatusItem: @(status)};
        [notificationCenter postNotificationName:DSReachabilityDidChangeNotification object:nil userInfo:userInfo];
    });
}

static const void *DSReachabilityRetainCallback(const void *info) {
    return Block_copy(info);
}

static void DSReachabilityReleaseCallback(const void *info) {
    if (info) {
        Block_release(info);
    }
}

@interface DSReachabilityManager ()
@property (readwrite, nonatomic, strong) id networkReachability;
@property (readwrite, nonatomic, assign) DSReachabilityAssociation networkReachabilityAssociation;
@property (readwrite, nonatomic, assign) DSReachabilityStatus networkReachabilityStatus;
@property (readwrite, nonatomic, copy) DSReachabilityStatusBlock networkReachabilityStatusBlock;
@property (readwrite, nonatomic, assign, getter=isMonitoring) BOOL monitoring;
@property (nonatomic, strong) NSHashTable *blockTable;
@end

@implementation DSReachabilityManager

+ (instancetype)sharedManager {
    static DSReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self managerForLocalAddress];
    });

    return _sharedManager;
}

+ (instancetype)managerForLocalAddress {
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    return [self managerForAddress:&address];
}

+ (instancetype)managerForDomain:(NSString *)domain {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);

    DSReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    manager.networkReachabilityAssociation = DSReachabilityForName;

    return manager;
}

+ (instancetype)managerForAddress:(const void *)address {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);

    DSReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    manager.networkReachabilityAssociation = DSReachabilityForAddress;

    return manager;
}

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.blockTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsCopyIn];
    self.networkReachability = CFBridgingRelease(reachability);
    self.networkReachabilityStatus = DSReachabilityStatusUnknown;

    return self;
}

- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

- (void)dealloc {
    [self stopMonitoring];
    [self.blockTable removeAllObjects];
}

#pragma mark -

- (BOOL)isReachable {
    return [self isReachableViaWWAN] || [self isReachableViaWiFi];
}

- (BOOL)isReachableViaWWAN {
    return self.networkReachabilityStatus == DSReachabilityStatusReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi {
    return self.networkReachabilityStatus == DSReachabilityStatusReachableViaWiFi;
}

#pragma mark -

- (void)startMonitoring {
    [self stopMonitoring];

    if (!self.networkReachability) {
        return;
    }

    self.monitoring = YES;

    __weak __typeof(self) weakSelf = self;
    DSReachabilityStatusBlock callback = ^(DSReachabilityStatus status) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;

        strongSelf.networkReachabilityStatus = status;
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
        NSArray *blockObjects = [strongSelf.blockTable allObjects];
        [blockObjects enumerateObjectsUsingBlock:^(DSReachabilityStatusBlock obj, NSUInteger idx, BOOL *_Nonnull stop) {
            obj(status);
            [strongSelf.blockTable removeObject:obj];
        }];
    };

    id networkReachability = self.networkReachability;
    SCNetworkReachabilityContext context = {0, (__bridge void *)callback, DSReachabilityRetainCallback, DSReachabilityReleaseCallback, NULL};
    SCNetworkReachabilitySetCallback((__bridge SCNetworkReachabilityRef)networkReachability, DSReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop((__bridge SCNetworkReachabilityRef)networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);

    switch (self.networkReachabilityAssociation) {
        case DSReachabilityForName:
            break;
        case DSReachabilityForAddress:
        case DSReachabilityForAddressPair:
        default: {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                SCNetworkReachabilityFlags flags;
                SCNetworkReachabilityGetFlags((__bridge SCNetworkReachabilityRef)networkReachability, &flags);
                DSReachabilityStatus status = DSReachabilityStatusForFlags(flags);
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(status);

                    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
                    [notificationCenter postNotificationName:DSReachabilityDidChangeNotification object:nil userInfo:@{DSReachabilityNotificationStatusItem: @(status)}];
                });
            });
        } break;
    }
}

- (void)stopMonitoring {
    self.monitoring = NO;
    if (!self.networkReachability) {
        return;
    }

    SCNetworkReachabilityUnscheduleFromRunLoop((__bridge SCNetworkReachabilityRef)self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

#pragma mark -

- (void)setReachabilityStatusChangeBlock:(void (^)(DSReachabilityStatus status))block {
    self.networkReachabilityStatusBlock = block;
}

- (void)addSingleCallReachabilityStatusChangeBlock:(nonnull void (^)(DSReachabilityStatus status))block {
    [self.blockTable addObject:block];
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObject:@"networkReachabilityStatus"];
    }

    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end
#endif
