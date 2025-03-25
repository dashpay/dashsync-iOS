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
@property (nonatomic, readonly) DInstantLock *lock;

@property (nonatomic, readonly) NSData *transactionHashData;
@property (nonatomic, readonly) NSData *signatureData;
@property (nonatomic, readonly) NSData *cycleHashData;

@property (nonatomic, readonly) BOOL signatureVerified; //verifies the signature and quorum together
@property (nonatomic, readonly) BOOL saved;

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
