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

#import <Foundation/Foundation.h>
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint16_t, DSSyncStateKind) {
    DSSyncStateKind_Chain = 0,
    DSSyncStateKind_Headers = 1,
    DSSyncStateKind_Masternodes = 2,
};


@interface DSMasternodeListSyncState : NSObject <NSCopying>

@property (nonatomic, assign) uint32_t retrievalQueueCount;
@property (nonatomic, assign) uint32_t retrievalQueueMaxAmount;
@property (nonatomic, assign) double storedCount;
@property (nonatomic, assign) uint32_t lastBlockHeight;

- (void)updateWithSyncState:(DMNSyncState *)state;
@end


@interface DSSyncState : NSObject <NSCopying>

@property (nonatomic, assign) DSChainSyncPhase syncPhase;
@property (nonatomic, assign) BOOL hasDownloadPeer;
@property (nonatomic, assign) BOOL peerManagerConnected;

@property (nonatomic, assign) uint32_t estimatedBlockHeight;

@property (nonatomic, assign) uint32_t lastSyncBlockHeight;
@property (nonatomic, assign) uint32_t chainSyncStartHeight;

@property (nonatomic, assign) uint32_t lastTerminalBlockHeight;
@property (nonatomic, assign) uint32_t terminalSyncStartHeight;
@property (nonatomic, strong) DSMasternodeListSyncState *masternodeListSyncInfo;

// MARK: Read-only

@property (nonatomic, readonly) double masternodeListProgress;
@property (nonatomic, readonly) double chainSyncProgress;
@property (nonatomic, readonly) double terminalHeaderSyncProgress;
@property (nonatomic, readonly) double combinedSyncProgress;
@property (nonatomic, readonly) DSSyncStateKind kind;

// MARK: Constructor

- (instancetype)initWithSyncPhase:(DSChainSyncPhase)phase;

@end

NS_ASSUME_NONNULL_END
