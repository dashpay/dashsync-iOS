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

#import <Foundation/Foundation.h>
#import "DSChain.h"
#import "DSPeer.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint32_t, DSSyncCountInfo) {
    DSSyncCountInfo_List = 2,
    DSSyncCountInfo_MNW = 3,
    DSSyncCountInfo_GovernanceObject = 10,
    DSSyncCountInfo_GovernanceObjectVote = 11,
};

#define PROTOCOL_TIMEOUT     20.0

FOUNDATION_EXPORT NSString* const DSChainManagerNotificationChainKey;

@class DSGovernanceSyncManager, DSMasternodeManager, DSSporkManager, DSPeerManager, DSGovernanceVote, DSDAPIClient, DSTransactionManager, DSIdentitiesManager, DSBloomFilter;

typedef void (^MiningCompletionBlock)(DSMerkleBlock * block, NSUInteger attempts, NSTimeInterval timeUsed, NSError * error);

@interface DSChainManager : NSObject <DSChainDelegate,DSPeerChainDelegate>

@property (nonatomic, readonly) double syncProgress;
@property (nonatomic, readonly) DSSporkManager * sporkManager;
@property (nonatomic, readonly) DSMasternodeManager * masternodeManager;
@property (nonatomic, readonly) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, readonly) DSDAPIClient * DAPIClient;
@property (nonatomic, readonly) DSIdentitiesManager * identitiesManager;
@property (nonatomic, readonly) DSTransactionManager * transactionManager;
@property (nonatomic, readonly) DSPeerManager * peerManager;
@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) NSData * chainSynchronizationFingerprint;

/*! @brief Returns the sync phase that the chain is currently in.  */
@property (nonatomic, readonly) DSChainSyncPhase syncPhase;

- (void)startSync;

- (void)stopSync;

- (void)rescan;

- (void)rescanMasternodeListsAndQuorums;

- (void)mineBlockWithTimeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
