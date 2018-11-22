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

NS_ASSUME_NONNULL_BEGIN

#define PROTOCOL_TIMEOUT     20.0

FOUNDATION_EXPORT NSString* const DSChainManagerNotificationChainKey;

@class DSGovernanceSyncManager, DSMasternodeManager, DSSporkManager, DSPeerManager, DSGovernanceVote, DSDAPIPeerManager, DSTransactionManager, DSMempoolManager, DSBloomFilter;

@interface DSChainManager : NSObject <DSChainDelegate>

@property (nonatomic, readonly) double syncProgress;
@property (nonatomic, readonly) DSSporkManager * sporkManager;
@property (nonatomic, readonly) DSMasternodeManager * masternodeManager;
@property (nonatomic, readonly) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, readonly) DSDAPIPeerManager * DAPIPeerManager;
@property (nonatomic, readonly) DSTransactionManager * transactionManager;
@property (nonatomic, readonly) DSPeerManager * peerManager;
@property (nonatomic, readonly) DSMempoolManager * mempoolManager;
@property (nonatomic, readonly) DSChain * chain;

- (instancetype)initWithChain:(DSChain*)chain;

- (void)rescan;

- (void)updateFilter;

- (DSBloomFilter *)bloomFilterForPeer:(DSPeer *)peer;

@end

NS_ASSUME_NONNULL_END
