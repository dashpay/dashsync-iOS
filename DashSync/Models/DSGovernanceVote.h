//
//  DSGovernanceObjectVote.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import <Foundation/Foundation.h>

@class DSGovernanceObject,DSMasternodeBroadcast,DSChain;

@interface DSGovernanceVote : NSObject

@property (nonatomic,readonly) DSGovernanceObject * governanceObject;
@property (nonatomic,readonly) DSMasternodeBroadcast * masternodeBroadcast;
@property (nonatomic,readonly) uint32_t outcome;
@property (nonatomic,readonly) uint32_t signal;
@property (nonatomic,readonly) NSData * signature;
@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) UInt256 governanceVoteHash;

+(DSGovernanceVote* _Nullable)governanceVoteFromMessage:(NSData * _Nonnull)message onChain:(DSChain* _Nonnull)chain;

@end
