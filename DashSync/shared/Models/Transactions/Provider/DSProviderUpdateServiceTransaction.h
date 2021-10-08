//
//  DSProviderUpdateServiceTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//

#import "BigIntTypes.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBLSKey, DSProviderRegistrationTransaction;

@interface DSProviderUpdateServiceTransaction : DSTransaction

@property (nonatomic, readonly) UInt256 payloadHash;
@property (nonatomic, assign) uint16_t providerUpdateServiceTransactionVersion;
@property (nonatomic, assign) UInt256 providerRegistrationTransactionHash;
@property (nonatomic, assign) DSSocketAddress masternodeSocketAddress;
@property (nonatomic, strong) NSData *scriptPayout;
@property (nonatomic, nullable, readonly) NSString *payoutAddress;
@property (nonatomic, assign) UInt256 inputsHash;
@property (nonatomic, strong) NSData *payloadSignature;
@property (nonatomic, readonly) DSProviderRegistrationTransaction *providerRegistrationTransaction;


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash masternodeSocketAddress:(DSSocketAddress)masternodeSocketAddress scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain;

- (instancetype)initWithProviderUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash masternodeSocketAddress:(DSSocketAddress)masternodeSocketAddress scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain;

- (void)updateInputsHash;

- (void)signPayloadWithKey:(DSBLSKey *_Nonnull)privateKey;

- (BOOL)checkPayloadSignature;

- (BOOL)checkPayloadSignature:(DSBLSKey *)publicKey;


@end

NS_ASSUME_NONNULL_END
