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

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerRegistrationTransactionVersion:(uint16_t)version username:(NSString* _Nonnull)username pubkeyHash:(UInt160)pubkeyHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainUserRegistrationTransactionVersion:(uint16_t)version username:(NSString* _Nonnull)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain * _Nonnull)chain;

-(void)signPayloadWithKey:(DSKey* _Nonnull)privateKey;

-(BOOL)checkPayloadSignature;

@end
