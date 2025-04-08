//
//  DSChainManager.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSBackgroundManager.h"
#import "DSChain.h"
#import "DSKeyManager.h"
#import "DSPeer.h"
#import "DSSyncState.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint32_t, DSSyncCountInfo)
{
    DSSyncCountInfo_List = 2,
    DSSyncCountInfo_MNW = 3,
    DSSyncCountInfo_GovernanceObject = 10,
    DSSyncCountInfo_GovernanceObjectVote = 11,
};

#define PROTOCOL_TIMEOUT 40.0

FOUNDATION_EXPORT NSString *const DSChainManagerNotificationChainKey;
FOUNDATION_EXPORT NSString *const DSChainManagerNotificationWalletKey;
FOUNDATION_EXPORT NSString *const DSChainManagerNotificationAccountKey;
FOUNDATION_EXPORT NSString *const DSChainManagerNotificationSyncStateKey;

FOUNDATION_EXPORT NSString *_Nonnull const DSChainManagerSyncWillStartNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSChainManagerChainSyncDidStartNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSChainManagerSyncFinishedNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSChainManagerSyncFailedNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSChainManagerSyncStateDidChangeNotification;

@class DSGovernanceSyncManager, DSMasternodeManager, DSSporkManager, DSPeerManager, DSGovernanceVote, DSTransactionManager, DSIdentitiesManager, DSBackgroundManager, DSBloomFilter, DSBlock, DSFullBlock, DSKeyManager, DSSyncState;

typedef void (^BlockMiningCompletionBlock)(DSFullBlock *_Nullable block, NSUInteger attempts, NSTimeInterval timeUsed, NSError *_Nullable error);
typedef void (^MultipleBlockMiningCompletionBlock)(NSArray<DSFullBlock *> *block, NSArray<NSNumber *> *attempts, NSTimeInterval timeUsed, NSError *_Nullable error);

@interface DSChainManager : NSObject <DSChainDelegate, DSPeerChainDelegate>

@property (nonatomic, readonly) DSBackgroundManager *backgroundManager;
@property (nonatomic, readonly) DSSporkManager *sporkManager;
@property (nonatomic, readonly) DSMasternodeManager *masternodeManager;
@property (nonatomic, readonly) DSGovernanceSyncManager *governanceSyncManager;
@property (nonatomic, readonly) DSIdentitiesManager *identitiesManager;
@property (nonatomic, readonly) DSTransactionManager *transactionManager;
@property (nonatomic, readonly) DSPeerManager *peerManager;
@property (nonatomic, readonly) DSKeyManager *keyManager;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly, getter = isSynced) BOOL synced;
@property (nonatomic, readonly) double combinedSyncProgress;

/*! @brief Returns the sync phase that the chain is currently in.  */
@property (nonatomic, readonly) DSChainSyncPhase syncPhase;

/*! @brief Returns determined chain sync state.  */
@property (nonatomic, readonly) DSSyncState *syncState;

- (void)startSync;
- (void)stopSync;
- (void)syncBlocksRescan;
- (void)masternodeListAndBlocksRescan;
- (void)masternodeListRescan;


- (DSChainLock * _Nullable)chainLockForBlockHash:(UInt256)blockHash;

@end

NS_ASSUME_NONNULL_END
