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
@property (nonatomic, assign) UInt128 ipAddress; //v6, but only v4 supported
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, strong) NSData *scriptPayout;
@property (nonatomic, nullable, readonly) NSString *payoutAddress;
@property (nonatomic, assign) UInt256 inputsHash;
@property (nonatomic, strong) NSData *payloadSignature;
@property (nonatomic, assign) uint16_t providerType; // Masternode Type: 0: Regular, 1: HighPerformance
@property (nonatomic, assign) uint16_t platformHTTPPort;
@property (nonatomic, assign) uint16_t platformP2PPort;
@property (nonatomic, assign) UInt160 platformNodeID;
@property (nonatomic, readonly) DSProviderRegistrationTransaction *providerRegistrationTransaction;


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain;

- (instancetype)initWithProviderUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain;

- (void)updateInputsHash;

- (void)signPayloadWithKey:(DSBLSKey *_Nonnull)privateKey;

- (BOOL)checkPayloadSignature;

- (BOOL)checkPayloadSignature:(DSBLSKey *)publicKey;


@end

NS_ASSUME_NONNULL_END
