//
//  DSInstantSendTransactionLock.h
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSInstantSendTransactionLock : NSObject

@property (nonatomic, readonly) uint8_t version;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) dashcore_ephemerealdata_instant_lock_InstantLock *lock;

//@property (nonatomic, readonly) dashcore_hash_types_Txid *transactionHash;
//@property (nonatomic, readonly) dashcore_bls_sig_utils_BLSSignature *signature;
//@property (nonatomic, readonly) Vec_dashcore_blockdata_transaction_outpoint_OutPoint *inputOutpoints;
//@property (nonatomic, readonly) dashcore_hash_types_CycleHash *cycleHash;
@property (nonatomic, readonly) NSData *transactionHashData;
@property (nonatomic, readonly) NSData *signatureData;
@property (nonatomic, readonly) NSData *cycleHashData;

@property (nonatomic, readonly) BOOL signatureVerified; //verifies the signature and quorum together
//@property (nonatomic, readonly) NSData *intendedQuorumPublicKey;
@property (nonatomic, readonly) BOOL saved;
//@property (nonatomic, readonly) UInt256 requestID;

@property (nonatomic, readonly, getter=isDeterministic) BOOL deterministic;

- (NSData *)toData;

- (BOOL)verifySignature;

- (void)saveInitial;
- (void)saveSignatureValid;

+ (instancetype)instantSendTransactionLockWithNonDeterministicMessage:(NSData *)message onChain:(DSChain *)chain;

+ (instancetype)instantSendTransactionLockWithDeterministicMessage:(NSData *)message onChain:(DSChain *)chain;

- (instancetype)initWithTransactionHash:(NSData *)transactionHash
                     withInputOutpoints:(NSArray *)inputOutpoints
                                version:(uint8_t)version
                              signature:(NSData *)signature
                              cycleHash:(NSData *)cycleHash
                      signatureVerified:(BOOL)signatureVerified
                         quorumVerified:(BOOL)quorumVerified
                                onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
