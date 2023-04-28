//
//  DSProviderUpdateRegistrarTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@class DSProviderRegistrationTransaction;

@interface DSProviderUpdateRegistrarTransaction : DSTransaction

@property (nonatomic, readonly) UInt256 payloadHash;
@property (nonatomic, assign) uint16_t providerUpdateRegistrarTransactionVersion;
@property (nonatomic, assign) UInt256 providerRegistrationTransactionHash;
@property (nonatomic, assign) uint16_t providerMode;
@property (nonatomic, assign) UInt384 operatorKey;
@property (nonatomic, readonly) NSString *operatorAddress;
@property (nonatomic, assign) UInt160 votingKeyHash;
@property (nonatomic, readonly) NSString *votingAddress;
@property (nonatomic, strong) NSData *scriptPayout;
@property (nonatomic, readonly) NSString *payoutAddress;
@property (nonatomic, assign) UInt256 inputsHash;
@property (nonatomic, strong) NSData *payloadSignature;
@property (nonatomic, readonly) DSProviderRegistrationTransaction *providerRegistrationTransaction;


- (instancetype)initWithInputHashes:(NSArray *)hashes
                       inputIndexes:(NSArray *)indexes
                       inputScripts:(NSArray *)scripts
                     inputSequences:(NSArray *)inputSequences
                    outputAddresses:(NSArray *)addresses
                      outputAmounts:(NSArray *)amounts
providerUpdateRegistrarTransactionVersion:(uint16_t)version
            providerTransactionHash:(UInt256)providerTransactionHash
                               mode:(uint16_t)providerMode
                        operatorKey:(UInt384)operatorKey
                      votingKeyHash:(UInt160)votingKeyHash
                       scriptPayout:(NSData *)scriptPayout
                            onChain:(DSChain *_Nonnull)chain;

- (instancetype)initWithProviderUpdateRegistrarTransactionVersion:(uint16_t)version
                                          providerTransactionHash:(UInt256)providerTransactionHash
                                                             mode:(uint16_t)providerMode
                                                      operatorKey:(UInt384)operatorKey
                                                    votingKeyHash:(UInt160)votingKeyHash
                                                     scriptPayout:(NSData *)scriptPayout
                                                          onChain:(DSChain *_Nonnull)chain;

- (instancetype)initWithMessage:(NSData *)message registrationTransaction:(DSProviderRegistrationTransaction *_Nullable)registrationTransaction onChain:(DSChain *)chain;

- (void)updateInputsHash;

- (void)signPayloadWithKey:(OpaqueKey *_Nonnull)privateKey;

- (BOOL)checkPayloadSignature;

- (BOOL)checkPayloadSignature:(OpaqueKey *_Nonnull)publicKey;


@end

NS_ASSUME_NONNULL_END
