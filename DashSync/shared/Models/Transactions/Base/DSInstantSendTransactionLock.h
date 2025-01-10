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
@property (nonatomic, readonly) UInt256 transactionHash;
@property (nonatomic, readonly) UInt768 signature;
@property (nonatomic, readonly) NSArray *inputOutpoints;
@property (nonatomic, readonly) UInt256 cycleHash;
@property (nonatomic, readonly) BOOL signatureVerified; //verifies the signature and quorum together
//@property (nonatomic, readonly) DLLMQEntry *intendedQuorum;
@property (nonatomic, readonly, assign) u384 *intendedQuorumPublicKey;
//@property (nonatomic, readonly) DSQuorumEntry *intendedQuorum;
@property (nonatomic, readonly) BOOL saved;
@property (nonatomic, readonly) UInt256 requestID;

@property (nonatomic, readonly, getter=isDeterministic) BOOL deterministic;

- (NSData *)toData;

- (BOOL)verifySignature;

- (void)saveInitial;
- (void)saveSignatureValid;

+ (instancetype)instantSendTransactionLockWithNonDeterministicMessage:(NSData *)message onChain:(DSChain *)chain;

+ (instancetype)instantSendTransactionLockWithDeterministicMessage:(NSData *)message onChain:(DSChain *)chain;

- (instancetype)initWithTransactionHash:(UInt256)transactionHash withInputOutpoints:(NSArray *)inputOutpoints signature:(UInt768)signature signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain *)chain;

//- (DSQuorumEntry *_Nullable)findSigningQuorumReturnMasternodeList:(DSMasternodeList *_Nullable *_Nullable)returnMasternodeList;

@end

NS_ASSUME_NONNULL_END
