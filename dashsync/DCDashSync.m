//
//  DCDashSync.m
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2018 dashcore. All rights reserved.
//

#import "DCDashSync.h"

@interface DCDashSync ()

@end

@implementation DCDashSync

+ (instancetype)syncController
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}


- (id)init
{
    if (self == [super init]) {
    // use background fetch to stay synced with the blockchain
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    // start the event manager
    [[BREventManager sharedEventManager] up];
    
    [BRWalletManager sharedInstance];
    
    [DSShapeshiftManager sharedInstance];
    }
    return self;
}


- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    __block id protectedObserver = nil, syncFinishedObserver = nil, syncFailedObserver = nil;
    __block void (^completion)(UIBackgroundFetchResult) = completionHandler;
    void (^cleanup)(void) = ^() {
        completion = nil;
        if (protectedObserver) [[NSNotificationCenter defaultCenter] removeObserver:protectedObserver];
        if (syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFinishedObserver];
        if (syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFailedObserver];
        protectedObserver = syncFinishedObserver = syncFailedObserver = nil;
    };
    
    if ([BRPeerManager sharedInstance].syncProgress >= 1.0) {
        NSLog(@"background fetch already synced");
        if (completion) completion(UIBackgroundFetchResultNoData);
        return;
    }
    
    // timeout after 25 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (completion) {
            NSLog(@"background fetch timeout with progress: %f", [BRPeerManager sharedInstance].syncProgress);
            completion(([BRPeerManager sharedInstance].syncProgress > 0.1) ? UIBackgroundFetchResultNewData :
                       UIBackgroundFetchResultFailed);
            cleanup();
        }
        //TODO: disconnect
    });
    
    protectedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationProtectedDataDidBecomeAvailable object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           NSLog(@"background fetch protected data available");
                                                           [[BRPeerManager sharedInstance] connect];
                                                       }];
    
    syncFinishedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFinishedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           NSLog(@"background fetch sync finished");
                                                           if (completion) completion(UIBackgroundFetchResultNewData);
                                                           cleanup();
                                                       }];
    
    syncFailedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFailedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           NSLog(@"background fetch sync failed");
                                                           if (completion) completion(UIBackgroundFetchResultFailed);
                                                           cleanup();
                                                       }];
    
    NSLog(@"background fetch starting");
    [[BRPeerManager sharedInstance] connect];
    
    // sync events to the server
    [[BREventManager sharedEventManager] sync];
    
    //    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"has_alerted_buy_dash"] == NO &&
    //        [WKWebView class] && [[BRAPIClient sharedClient] featureEnabled:BRFeatureFlagsBuyDash] &&
    //        [UIApplication sharedApplication].applicationIconBadgeNumber == 0) {
    //        [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
    //    }
}

@end
