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
@property (nonatomic, readonly) UInt256 transactionLockVoteHash;
@property (nonatomic, readonly) DSUTXO transactionOutpoint;
@property (nonatomic, readonly) DSUTXO masternodeOutpoint;
@property (nonatomic, readonly) UInt256 masternodeProviderTransactionHash;
@property (nonatomic, readonly) UInt256 quorumModifierHash;
@property (nonatomic, readonly) UInt256 quorumVerifiedAtBlockHash;
@property (nonatomic, readonly) BOOL signatureVerified;
@property (nonatomic, readonly) BOOL quorumVerified;
@property (nonatomic, readonly) NSArray<DSSimplifiedMasternodeEntry*>* intendedQuorum;
@property (nonatomic, readonly) DSSimplifiedMasternodeEntry * masternode;
@property (nonatomic, readonly) BOOL saved;

- (BOOL)verifySignature;
- (BOOL)sentByIntendedQuorum;

- (void)save;

+ (instancetype)transactionLockVoteWithMessage:(NSData *)message onChain:(DSChain*)chain;

- (instancetype)initWithTransactionHash:(UInt256)transactionHash transactionOutpoint:(DSUTXO)transactionOutpoint masternodeOutpoint:(DSUTXO)masternodeOutpoint masternodeProviderTransactionHash:(UInt256)masternodeProviderTransactionHash quorumModifierHash:(UInt256)quorumModifierHash quorumVerifiedAtBlockHash:(UInt256)quorumVerifiedAtBlockHash signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
