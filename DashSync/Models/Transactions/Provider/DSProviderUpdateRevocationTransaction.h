//
//  DSProviderUpdateRevocationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBLSKey, DSProviderRegistrationTransaction;

@interface DSProviderUpdateRevocationTransaction : DSTransaction

@property (nonatomic,readonly) UInt256 payloadHash;
@property (nonatomic,assign) uint16_t providerUpdateRevocationTransactionVersion;
@property (nonatomic,assign) UInt256 providerRegistrationTransactionHash;
@property (nonatomic,assign) uint16_t reason;
@property (nonatomic,strong) NSData * payloadSignature;
@property (nonatomic,assign) UInt256 inputsHash;
@property (nonatomic,readonly) DSProviderRegistrationTransaction * providerRegistrationTransaction;


-(instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain * _Nonnull)chain;

-(instancetype)initWithProviderUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain * _Nonnull)chain;

-(void)updateInputsHash;

-(void)signPayloadWithKey:(DSBLSKey* _Nonnull)privateKey;

-(BOOL)checkPayloadSignature;

-(BOOL)checkPayloadSignature:(DSBLSKey*)publicKey;


@end

NS_ASSUME_NONNULL_END
