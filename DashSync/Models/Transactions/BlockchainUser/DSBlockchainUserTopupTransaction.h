//
//  DSBlockchainUserTopupTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

@class DSECDSAKey,DSChain;

@interface DSBlockchainUserTopupTransaction : DSTransaction

@property (nonatomic,assign) uint16_t blockchainUserTopupTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) uint64_t topupAmount;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash onChain:(DSChain*)chain;

@end
