//
//  DSBlockchainUserCloseTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSTransaction.h"

@interface DSBlockchainUserCloseTransaction : DSTransaction

@property (nonatomic,assign) uint16_t blockchainUserCloseTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousBlockchainUserTransactionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,strong) NSData * payloadSignature;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainUserCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

@end
