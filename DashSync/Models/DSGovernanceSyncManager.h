//
//  DSGovernanceSyncManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import <Foundation/Foundation.h>


@class DSPeer,DSChain,DSGovernanceObject,DSGovernanceVote;

@interface DSGovernanceSyncManager : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger recentGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger last3HoursGovernanceObjectHashesCount;
@property (nonatomic,readonly) NSUInteger governanceObjectsCount;
@property (nonatomic,assign) NSUInteger totalGovernanceObjectCount;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceObject:(DSGovernanceObject * _Nonnull)governanceObject;

-(void)peer:(DSPeer * _Nullable)peer relayedGovernanceVote:(DSGovernanceVote*  _Nonnull)governanceVote;

-(void)peer:(DSPeer *)peer hasGovernanceObjectHashes:(NSSet*)governanceObjectHashes;

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer;


@end
