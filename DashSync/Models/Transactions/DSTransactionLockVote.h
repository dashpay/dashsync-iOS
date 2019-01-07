//
//  DSTransactionLockVote.h
//  DashSync
//
//  Created by Sam Westrich on 11/20/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSSimplifiedMasternodeEntry;

@interface DSTransactionLockVote : NSObject

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) UInt256 transactionHash;
@property (nonatomic, readonly) DSUTXO transactionOutpoint;
@property (nonatomic, readonly) DSUTXO masternodeOutpoint;
@property (nonatomic, readonly) UInt256 masternodeProviderTransactionHash;
@property (nonatomic, readonly) UInt256 quorumModifierHash;
@property (nonatomic, readonly) BOOL signatureVerified;
@property (nonatomic, readonly) NSArray<DSSimplifiedMasternodeEntry*>* intendedQuorum;
@property (nonatomic, readonly) DSSimplifiedMasternodeEntry * masternode;

- (BOOL)verifySignature;
- (BOOL)sentByIntendedQuorum;

+ (instancetype)transactionLockVoteWithMessage:(NSData *)message onChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
