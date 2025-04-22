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
    DSSyncStateKind_Platform = 3,
};

typedef NS_ENUM(uint32_t, DSSyncStateExtKind) {
    DSSyncStateExtKind_None = 1 << 0,
    DSSyncStateExtKind_Peers = 1 << 1,
    DSSyncStateExtKind_Governance = 1 << 2,
    DSSyncStateExtKind_Mempool = 1 << 3,
    DSSyncStateExtKind_Headers = 1 << 4,
    DSSyncStateExtKind_Masternodes = 1 << 5,
    DSSyncStateExtKind_Transactions = 1 << 6,
    DSSyncStateExtKind_CoinJoin = 1 << 7,
    DSSyncStateExtKind_Platform = 1 << 8,
};

typedef NS_ENUM(uint16_t, DSPlatformSyncStateKind) {
    DSPlatformSyncStateKind_None = 1 << 0,
    DSPlatformSyncStateKind_KeyHashes = 1 << 1,
    DSPlatformSyncStateKind_Unsynced = 1 << 2,
};

typedef NS_ENUM(uint16_t, DSPeersSyncStateKind) {
    DSPeersSyncStateKind_None = 1 << 0,
    DSPeersSyncStateKind_Selection = 1 << 1,
    DSPeersSyncStateKind_Connecting = 1 << 2,
};

typedef NS_ENUM(uint16_t, DSMasternodeListSyncStateKind) {
    DSMasternodeListSyncStateKind_None = 1 << 0,
    DSMasternodeListSyncStateKind_Checkpoints = 1 << 1,
    DSMasternodeListSyncStateKind_Diffs = 1 << 2,
    DSMasternodeListSyncStateKind_QrInfo = 1 << 3,
    DSMasternodeListSyncStateKind_Quorums = 1 << 4,
};

NSString * DSSyncStateExtKindDescription(DSSyncStateExtKind kind);
NSString * DSPeersSyncStateKindDescription(DSPeersSyncStateKind kind);
NSString * DSPlatformSyncStateKindDescription(DSPlatformSyncStateKind kind);
NSString * DSMasternodeListSyncStateKindDescription(DSMasternodeListSyncStateKind kind);

@interface DSMasternodeListSyncState : NSObject <NSCopying>

@property (nonatomic, assign) uint32_t queueCount;
@property (nonatomic, assign) uint32_t queueMaxAmount;
@property (nonatomic, assign) uint32_t storedCount;
@property (nonatomic, assign) uint32_t lastListHeight;
@property (nonatomic, assign) uint32_t estimatedBlockHeight;
@property (nonatomic, readonly) DSMasternodeListSyncStateKind kind;

- (void)addSyncKind:(DSMasternodeListSyncStateKind)kind;
- (void)removeSyncKind:(DSMasternodeListSyncStateKind)kind;
- (void)resetSyncKind;

- (void)updateWithSyncState:(DMNSyncState *)state;
@end

@interface DSPlatformSyncState : NSObject <NSCopying>
@property (nonatomic, assign) uint32_t queueCount;
@property (nonatomic, assign) uint32_t queueMaxAmount;
@property (nonatomic, assign) NSTimeInterval lastSyncedIndentitiesTimestamp;
@property (nonatomic, readonly) DSPlatformSyncStateKind kind;
/*! @brief Returns if we synced identities in the last 30 seconds.  */
@property (nonatomic, readonly) BOOL hasRecentIdentitiesSync;

- (void)addSyncKind:(DSPlatformSyncStateKind)kind;
- (void)removeSyncKind:(DSPlatformSyncStateKind)kind;
- (void)resetSyncKind;

@end

@interface DSPeersSyncState : NSObject <NSCopying>
@property (nonatomic, readonly) DSPeersSyncStateKind kind;
@property (nonatomic, assign) BOOL hasDownloadPeer;
@property (nonatomic, assign) BOOL peerManagerConnected;
- (void)addSyncKind:(DSPeersSyncStateKind)kind;
- (void)removeSyncKind:(DSPeersSyncStateKind)kind;
- (void)resetSyncKind;
@end

@interface DSSyncState : NSObject <NSCopying>

@property (nonatomic, assign) DSChainSyncPhase syncPhase;
@property (nonatomic, readonly) DSSyncStateExtKind extKind;

@property (nonatomic, assign) uint32_t estimatedBlockHeight;

@property (nonatomic, assign) uint32_t lastSyncBlockHeight;
@property (nonatomic, assign) uint32_t chainSyncStartHeight;

@property (nonatomic, assign) uint32_t lastTerminalBlockHeight;
@property (nonatomic, assign) uint32_t terminalSyncStartHeight;
@property (nonatomic, strong) DSMasternodeListSyncState *masternodeListSyncInfo;
@property (nonatomic, strong) DSPlatformSyncState *platformSyncInfo;
@property (nonatomic, strong) DSPeersSyncState *peersSyncInfo;

// MARK: Read-only

@property (nonatomic, readonly) double masternodeListProgress;
@property (nonatomic, readonly) double chainSyncProgress;
@property (nonatomic, readonly) double terminalHeaderSyncProgress;
@property (nonatomic, readonly) double progress;
@property (nonatomic, readonly) DSSyncStateKind kind;

// MARK: Constructor

- (instancetype)initWithSyncPhase:(DSChainSyncPhase)phase;

// MARK: Description

- (NSString *)peersDescription;
- (NSString *)chainDescription;
- (NSString *)headersDescription;
- (NSString *)masternodesDescription;
- (NSString *)platformDescription;

- (void)addSyncKind:(DSSyncStateExtKind)kind;
- (void)removeSyncKind:(DSSyncStateExtKind)kind;
- (void)resetSyncKind;
@end

NS_ASSUME_NONNULL_END
