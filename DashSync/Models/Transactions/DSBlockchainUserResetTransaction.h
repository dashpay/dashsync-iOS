//
//  DSBlockchainUserResetUserKeyTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSTransaction.h"

@interface DSBlockchainUserResetTransaction : DSTransaction

@property (nonatomic,assign) uint16_t blockchainUserResetTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousBlockchainUserTransactionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,strong) NSData * replacementPublicKey;
@property (nonatomic,strong) NSData * oldPublicKeyPayloadSignature;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKey:(NSData*)replacementPublicKey creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

@end
