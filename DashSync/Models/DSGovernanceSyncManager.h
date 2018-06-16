//
//  DSGovernanceSyncManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectCountUpdateNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceVotesDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceVoteCountUpdateNotification;

@class DSPeer,DSChain,DSGovernanceObject,DSGovernanceVote;

@interface DSGovernanceSyncManager : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger recentGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger last3HoursStandaloneGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger governanceObjectsCount;

@property (nonatomic, readonly) NSUInteger governanceVotesCount;

@property (nonatomic,readonly) DSGovernanceObject * currentGovernanceSyncObject;

@property (nonatomic,assign) NSUInteger totalGovernanceObjectCount;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceObject:(DSGovernanceObject * _Nonnull)governanceObject;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceVote:(DSGovernanceVote*  _Nonnull)governanceVote;

-(void)peer:(DSPeer * _Nullable)peer hasGovernanceObjectHashes:(NSSet* _Nonnull)governanceObjectHashes;

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer;

-(void)finishedGovernanceVoteSyncWithPeer:(DSPeer*)peer;


@end
