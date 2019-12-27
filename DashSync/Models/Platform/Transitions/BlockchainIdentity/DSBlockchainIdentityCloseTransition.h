//
//  DSBlockchainIdentityCloseTransition.h
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSTransition.h"

@interface DSBlockchainIdentityCloseTransition : DSTransition

@property (nonatomic,assign) uint16_t blockchainIdentityCloseTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousBlockchainIdentityTransactionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,strong) NSData * payloadSignature;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainIdentityCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

@end
