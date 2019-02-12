//
//  DSProviderRegistrationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

@class DSKey;

@interface DSProviderRegistrationTransaction : DSTransaction

@property (nonatomic,readonly) UInt256 payloadHash;
@property (nonatomic,assign) uint16_t providerRegistrationTransactionVersion;
@property (nonatomic,assign) uint16_t providerType;
@property (nonatomic,assign) uint16_t providerMode;
@property (nonatomic,assign) DSUTXO collateralOutpoint;
@property (nonatomic,assign) UInt128 ipAddress; //v6, but only v4 supported
@property (nonatomic,assign) uint16_t port;
@property (nonatomic,assign) UInt160 ownerKeyHash;
@property (nonatomic,assign) UInt384 operatorKey;
@property (nonatomic,assign) UInt160 votingKeyHash;
@property (nonatomic,assign) uint16_t operatorReward;
@property (nonatomic,strong) NSData * scriptPayout;
@property (nonatomic,assign) UInt256 inputsHash;
@property (nonatomic,strong) NSData * payloadSignature;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain;

-(instancetype)initWithProviderRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain;

-(void)updateInputsHash;

-(void)signPayloadWithKey:(DSKey* _Nonnull)privateKey;

-(BOOL)checkPayloadSignature;

@end
