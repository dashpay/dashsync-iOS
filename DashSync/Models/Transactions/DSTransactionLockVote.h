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

@class DSChain;

@interface DSTransactionLockVote : NSObject

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) UInt256 transactionHash;
@property (nonatomic, readonly) DSUTXO transactionOutpoint;
@property (nonatomic, readonly) DSUTXO masternodeOutpoint;
@property (nonatomic, readonly) BOOL signatureVerified;

- (BOOL)verifySignature;

+ (instancetype)transactionLockVoteWithMessage:(NSData *)message onChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
