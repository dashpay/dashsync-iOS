//
//  DSInstantSendTransactionLock.h
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSSimplifiedMasternodeEntry;

@interface DSInstantSendTransactionLock : NSObject

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) UInt256 transactionHash;
@property (nonatomic, readonly) UInt256 instantSendTransactionLockHash;
@property (nonatomic, readonly) UInt768 signature;
@property (nonatomic, readonly) NSArray * inputOutpoints;
@property (nonatomic, readonly) BOOL signatureVerified;
@property (nonatomic, readonly) BOOL quorumVerified;
@property (nonatomic, readonly) NSArray<DSSimplifiedMasternodeEntry*>* intendedQuorum;
@property (nonatomic, readonly) BOOL saved;

- (BOOL)verifySignature;
- (BOOL)verifySentByIntendedQuorum;

- (void)save;

+ (instancetype)instantSendTransactionLockWithMessage:(NSData *)message onChain:(DSChain*)chain;

- (instancetype)initWithTransactionHash:(UInt256)transactionHash withInputOutpoints:(NSArray*)inputOutpoints signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
