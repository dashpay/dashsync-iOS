//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
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

#import "DSChain.h"
#import "DSQuorumSnapshot.h"
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSMasternodeListDiffValidationErrorNotification;

#define MASTERNODE_COST 100000000000

@class DSPeer, DSChain, DSSimplifiedMasternodeEntry, DSWallet, DSLocalMasternode, DSProviderRegistrationTransaction, DSQuorumEntry, DSMasternodeList, DSInstantSendTransactionLock, DSBLSKey, DSECDSAKey;

@interface DSMasternodeManager : NSObject <DSPeerMasternodeDelegate>

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, readonly) NSUInteger simplifiedMasternodeEntryCount;
@property (nonatomic, readonly) NSUInteger activeQuorumsCount;
@property (nonatomic, readonly) NSArray *recentMasternodeLists;
@property (nonatomic, readonly) NSUInteger knownMasternodeListsCount;
@property (nonatomic, readonly) uint32_t earliestMasternodeListBlockHeight;
@property (nonatomic, readonly) uint32_t lastMasternodeListBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedMasternodeListsToSync;
@property (nonatomic, readonly) DSMasternodeList *currentMasternodeList;
@property (nonatomic, readonly) double masternodeListAndQuorumsSyncProgress;
@property (nonatomic, readonly) NSUInteger masternodeListRetrievalQueueCount;
@property (nonatomic, readonly) NSUInteger masternodeListRetrievalQueueMaxAmount;
@property (nonatomic, readonly) BOOL hasMasternodeListCurrentlyBeingSaved;
@property (nonatomic, readonly) BOOL currentMasternodeListIsInLast24Hours;

@property (nonatomic, readonly, nullable) MasternodeProcessor *processor;
@property (nonatomic, readonly, nullable) MasternodeProcessorCache *processorCache;

- (instancetype)init NS_UNAVAILABLE;
- (uint32_t)heightForBlockHash:(UInt256)blockhash;
- (BOOL)hasCurrentMasternodeListInLast30Days;

- (DSSimplifiedMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash;

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port;

- (DSQuorumEntry *_Nullable)quorumEntryForInstantSendRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset;
- (DSQuorumEntry *_Nullable)quorumEntryForChainLockRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset;
- (DSQuorumEntry *_Nullable)quorumEntryForChainLockRequestID:(UInt256)requestID forBlockHeight:(uint32_t)blockHeight;
- (DSQuorumEntry *_Nullable)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash forBlockHeight:(uint32_t)blockHeight;

- (DSMasternodeList *_Nullable)masternodeListForBlockHash:(UInt256)blockHash withBlockHeightLookup:(uint32_t (^_Nullable)(UInt256 blockHash))blockHeightLookup;
- (DSMasternodeList *_Nullable)masternodeListForBlockHash:(UInt256)blockHash;

/// Rust helpers
- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHeight:(uint32_t)blockHeight;
- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHash:(UInt256)blockHash;
- (BOOL)saveQuorumSnapshot:(DSQuorumSnapshot *)snapshot;
- (BOOL)saveMasternodeList:(DSMasternodeList *)masternodeList forBlockHash:(UInt256)blockHash;

- (void)startSync;
- (BOOL)requestMasternodeListForBlockHeight:(uint32_t)blockHeight error:(NSError *_Nullable *_Nullable)error;
- (BOOL)requestMasternodeListForBlockHash:(UInt256)blockHash;

- (void)reloadMasternodeLists;
- (void)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (void)destroyProcessors;

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion;

@end

NS_ASSUME_NONNULL_END
