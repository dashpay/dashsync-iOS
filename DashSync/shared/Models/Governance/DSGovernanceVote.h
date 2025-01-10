//
//  DSGovernanceObjectVote.h
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import "dash_shared_core.h"
#import "DSChain.h"
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSGovernanceObject, DSSimplifiedMasternodeEntry, DSChain;

typedef NS_ENUM(uint32_t, DSGovernanceVoteSignal)
{
    DSGovernanceVoteSignal_None = 0,
    DSGovernanceVoteSignal_Funding = 1,
    DSGovernanceVoteSignal_Valid = 2,
    DSGovernanceVoteSignal_Delete = 3,
    DSGovernanceVoteSignal_Endorsed = 4
};

typedef NS_ENUM(uint32_t, DSGovernanceVoteOutcome)
{
    DSGovernanceVoteOutcome_None = 0,
    DSGovernanceVoteOutcome_Yes = 1,
    DSGovernanceVoteOutcome_No = 2,
    DSGovernanceVoteOutcome_Abstain = 3
};

@interface DSGovernanceVote : NSObject

@property (nullable, nonatomic, strong) DSGovernanceObject *governanceObject;
@property (nonatomic, readonly) DMasternodeEntry *masternode;
@property (nonatomic, readonly) DSGovernanceVoteOutcome outcome;
@property (nonatomic, readonly) DSGovernanceVoteSignal signal;
@property (nonatomic, readonly) NSTimeInterval createdAt;
@property (nonatomic, readonly) NSData *signature;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) UInt256 parentHash;
@property (nonatomic, readonly) DSUTXO masternodeUTXO;
@property (nonatomic, readonly) UInt256 governanceVoteHash;

+ (DSGovernanceVote *_Nullable)governanceVoteFromMessage:(NSData *)message onChain:(DSChain *)chain;
- (instancetype)initWithParentHash:(UInt256)parentHash forMasternodeUTXO:(DSUTXO)masternodeUTXO voteOutcome:(DSGovernanceVoteOutcome)voteOutcome voteSignal:(DSGovernanceVoteSignal)voteSignal createdAt:(NSTimeInterval)createdAt signature:(NSData *_Nullable)signature onChain:(DSChain *)chain;
- (void)signWithKey:(DOpaqueKey *)key;

- (NSData *)dataMessage;
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
