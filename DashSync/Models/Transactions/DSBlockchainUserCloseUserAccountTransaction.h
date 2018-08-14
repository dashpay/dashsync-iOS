//
//  DSBlockchainUserCloseUserAccountTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSTransaction.h"

@interface DSBlockchainUserCloseUserAccountTransaction : DSTransaction

@property (nonatomic,readonly) uint16_t blockchainUserCloseUserAccountTransactionVersion;
@property (nonatomic,readonly) UInt256 registrationTransactionHash;
@property (nonatomic,readonly) UInt256 previousSubscriptionTransactionHash;
@property (nonatomic,readonly) NSNumber * topupAmount;
@property (nonatomic,readonly) uint16_t topupIndex;

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts BlockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousSubscriptionTransactionHash:(UInt256)previousSubscriptionTransactionHash topupAmount:(NSNumber*)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain;

-(instancetype)initWithBlockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousSubscriptionTransactionHash:(UInt256)previousSubscriptionTransactionHash onChain:(DSChain*)chain;

@end
