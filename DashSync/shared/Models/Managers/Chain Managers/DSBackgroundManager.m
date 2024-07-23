//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSBackgroundManager.h"
#import "DSChainManager.h"
#import "DSPeerManager+Protected.h"

@interface DSBackgroundManager ()

@property (nonatomic, strong) DSChain *chain;

#if TARGET_OS_IOS

@property (nonatomic, strong) id backgroundObserver;
@property (nonatomic, assign) NSUInteger terminalHeadersSaveTaskId, blockLocatorsSaveTaskId;

#endif

@end

@implementation DSBackgroundManager

- (instancetype)initWithChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
#if TARGET_OS_IOS
    self.terminalHeadersSaveTaskId = UIBackgroundTaskInvalid;
    self.backgroundObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [chain.chainManager.peerManager startBackgroundMode:self.terminalHeadersSaveTaskId == UIBackgroundTaskInvalid];
        }];
#endif

    return self;
}

- (void)dealloc {
#if TARGET_OS_IOS
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.backgroundObserver) 
        [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
#endif
}


- (void)createBlockLocatorsTask:(void(^ __nullable)(void))handler {
#if TARGET_OS_IOS
    if (self.blockLocatorsSaveTaskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
        self.blockLocatorsSaveTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:handler];
    }
#endif
}
- (void)createTerminalHeadersTask:(void(^ __nullable)(void))handler {
#if TARGET_OS_IOS
    if (self.terminalHeadersSaveTaskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
        self.terminalHeadersSaveTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:handler];
    }
#endif
}

- (void)stopBackgroundActivities {
#if TARGET_OS_IOS
    if (self.terminalHeadersSaveTaskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.terminalHeadersSaveTaskId];
        self.terminalHeadersSaveTaskId = UIBackgroundTaskInvalid;
    }

    if (self.blockLocatorsSaveTaskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.blockLocatorsSaveTaskId];
        self.blockLocatorsSaveTaskId = UIBackgroundTaskInvalid;
    }
#endif
}

- (BOOL)hasValidHeadersTask {
    return self.terminalHeadersSaveTaskId != UIBackgroundTaskInvalid || [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;
}

@end
