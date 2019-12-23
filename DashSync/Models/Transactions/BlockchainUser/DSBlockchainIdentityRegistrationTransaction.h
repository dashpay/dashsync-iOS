//
//  DSBlockchainIdentityRegistrationTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSECDSAKey;

@interface DSBlockchainIdentityRegistrationTransaction : DSTransaction


@property (nonatomic,readonly) UInt256 payloadHash;
@property (nonatomic,assign) uint16_t blockchainIdentityRegistrationTransactionVersion;
@property (nonatomic,copy) NSString * username;
@property (nonatomic,assign) UInt160 pubkeyHash;
@property (nullable, nonatomic,readonly) NSString * pubkeyAddress;
@property (nonatomic,strong) NSData * payloadSignature;
@property (nonatomic,readonly) uint64_t topupAmount;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityRegistrationTransactionVersion:(uint16_t)version username:(NSString *)username pubkeyHash:(UInt160)pubkeyHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainIdentityRegistrationTransactionVersion:(uint16_t)version username:(NSString *)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain *)chain;

-(void)signPayloadWithKey:(DSECDSAKey *)privateKey;

-(BOOL)checkPayloadSignature;

@end

NS_ASSUME_NONNULL_END
