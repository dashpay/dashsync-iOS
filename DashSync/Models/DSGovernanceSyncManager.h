//
//  DSGovernanceSyncManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSGovernanceObjectCountUpdateNotification;

@class DSPeer,DSChain,DSGovernanceObject,DSGovernanceVote;

@interface DSGovernanceSyncManager : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger recentGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger last3HoursStandaloneGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger governanceObjectsCount;
@property (nonatomic,assign) NSUInteger totalGovernanceObjectCount;
@property (nonatomic,assign) NSUInteger totalGovernanceVoteCount;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceObject:(DSGovernanceObject * _Nonnull)governanceObject;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceVote:(DSGovernanceVote*  _Nonnull)governanceVote;

-(void)peer:(DSPeer * _Nullable)peer hasGovernanceObjectHashes:(NSSet* _Nonnull)governanceObjectHashes;

-(void)peer:(DSPeer * _Nullable)peer hasGovernanceVoteHashes:(NSSet* _Nonnull)governanceVoteHashes;

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer;


@end
