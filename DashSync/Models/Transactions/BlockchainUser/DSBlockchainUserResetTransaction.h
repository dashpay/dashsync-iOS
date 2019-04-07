//
//  DSBlockchainUserResetUserKeyTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSECDSAKey;

@interface DSBlockchainUserResetTransaction : DSTransaction

@property (nonatomic,assign) uint16_t blockchainUserResetTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousBlockchainUserTransactionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,assign) UInt160 replacementPublicKeyHash; //we will get rid of this and do next line later
@property (nullable, nonatomic,readonly) NSString * replacementAddress; // TODO: replacementAddress is not initialized
//@property (nonatomic,strong) NSData * replacementPublicKey;
@property (nonatomic,strong) NSData * oldPublicKeyPayloadSignature;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKeyHash:(UInt160)replacementPublicKeyHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

//this is what we will eventually go to (right below)

//- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKey:(NSData*)replacementPublicKey creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKeyHash:(UInt160)replacementPublicKeyHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

-(void)signPayloadWithKey:(DSECDSAKey*)privateKey;

-(BOOL)checkPayloadSignatureIsSignedByPublicKeyWithHash:(UInt160)oldPublicKeyHash;

@end

NS_ASSUME_NONNULL_END
