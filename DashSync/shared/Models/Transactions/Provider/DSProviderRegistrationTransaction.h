//
//  DSProviderRegistrationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "BigIntTypes.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternode;

@interface DSProviderRegistrationTransaction : DSTransaction

@property (nonatomic, readonly) UInt256 payloadHash;
@property (nonatomic, assign) uint16_t providerRegistrationTransactionVersion;
@property (nonatomic, assign) uint16_t providerType;
@property (nonatomic, assign) uint16_t providerMode;
@property (nonatomic, assign) DSUTXO collateralOutpoint;
@property (nonatomic, assign) UInt128 ipAddress; //v6, but only v4 supported
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) UInt160 ownerKeyHash;
@property (nullable, nonatomic, readonly) NSString *ownerAddress;
@property (nonatomic, assign) UInt384 operatorKey;
@property (nonatomic, assign) uint16_t operatorKeyVersion;
@property (nonatomic, readonly) NSString *operatorKeyString;
@property (nonatomic, readonly) NSString *operatorAddress;
@property (nonatomic, assign) UInt160 votingKeyHash;
@property (nonatomic, readonly) NSString *votingAddress;
@property (nonatomic, assign) uint16_t operatorReward;
@property (nonatomic, strong) NSData *scriptPayout;
@property (nonatomic, readonly) NSString *payoutAddress;
@property (nullable, nonatomic, readonly) NSString *holdingAddress;
@property (nonatomic, assign) UInt256 inputsHash;
@property (nonatomic, strong) NSData *payloadSignature;
@property (nonatomic, readonly) NSString *payloadCollateralString;
@property (nonatomic, readonly) UInt256 payloadCollateralDigest;
@property (nonatomic, readonly) NSString *coreRegistrationCommand;
@property (nonatomic, readonly) NSString *location;
@property (nonatomic, readonly) DSLocalMasternode *localMasternode;
@property (nullable, nonatomic, readonly) DSWallet *masternodeHoldingWallet; //only set if the transaction is sent to a masternode holding address
@property (nonatomic, assign) uint16_t platformHTTPPort;
@property (nonatomic, assign) uint16_t platformP2PPort;
@property (nonatomic, assign) UInt160 platformNodeID;
@property (nullable, nonatomic, readonly) NSString *platformNodeAddress;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey operatorKeyVersion:(uint16_t)operatorKeyVersion votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData *)scriptPayout onChain:(DSChain *)chain;

- (instancetype)initWithProviderRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey operatorKeyVersion:(uint16_t)operatorKeyVersion votingKeyHash:(UInt160)votingKeyHash platformNodeID:(UInt160)platformNodeID operatorReward:(uint16_t)operatorReward scriptPayout:(NSData *)scriptPayout onChain:(DSChain *)chain;

- (void)updateInputsHash;

- (BOOL)checkPayloadSignature;
- (NSUInteger)masternodeOutputIndex;

- (BOOL)usesBasicBLS;
- (BOOL)usesHPMN;

@end

NS_ASSUME_NONNULL_END
