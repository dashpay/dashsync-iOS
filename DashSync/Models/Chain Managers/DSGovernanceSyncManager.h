//
//  DSGovernanceSyncManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
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
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSPeer.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectCountUpdateNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceVotesDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceVoteCountUpdateNotification;

#define SUPERBLOCK_AVERAGE_TIME 2575480
#define PROPOSAL_COST 500000000

@class DSPeer,DSChain,DSGovernanceObject,DSGovernanceVote;

@interface DSGovernanceSyncManager : NSObject <DSGovernanceObjectDelegate,DSPeerGovernanceDelegate>

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger recentGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger last3HoursStandaloneGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger governanceObjectsCount;
@property (nonatomic,readonly) NSUInteger proposalObjectsCount;

@property (nonatomic,readonly) NSUInteger governanceVotesCount;
@property (nonatomic,readonly) NSUInteger totalGovernanceVotesCount;

@property (nonatomic,readonly) DSGovernanceObject * currentGovernanceSyncObject;


-(instancetype)initWithChain:(DSChain*)chain;

-(void)startGovernanceSync;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceObject:(DSGovernanceObject * _Nonnull)governanceObject;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceVote:(DSGovernanceVote*  _Nonnull)governanceVote;

-(void)peer:(DSPeer * _Nullable)peer hasGovernanceObjectHashes:(NSSet* _Nonnull)governanceObjectHashes;

-(DSGovernanceVote *)peer:(DSPeer * _Nullable)peer requestedVote:(UInt256)voteHash;

-(DSGovernanceObject *)peer:(DSPeer * _Nullable)peer requestedGovernanceObject:(UInt256)governanceObjectHash;

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer;

-(void)finishedGovernanceVoteSyncWithPeer:(DSPeer*)peer;

-(void)vote:(DSGovernanceVoteOutcome)governanceVoteOutcome onGovernanceProposal:(DSGovernanceObject* _Nonnull)governanceObject;

-(void)wipeGovernanceInfo;

-(DSGovernanceObject*)createProposalWithIdentifier:(NSString*)identifier toPaymentAddress:(NSString*)paymentAddress forAmount:(uint64_t)amount fromAccount:(DSAccount*)account startDate:(NSDate*)date cycles:(NSUInteger)cycles url:(NSString*)url;


@end
