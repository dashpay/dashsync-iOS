//
//  DSLocalMasternodeEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSLocalMasternode+Protected.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSWallet.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "NSManagedObject+Sugar.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"

@implementation DSLocalMasternodeEntity

- (DSLocalMasternode*)loadLocalMasternode {
    DSProviderRegistrationTransactionEntity * providerRegistrationTransactionEntity = self.providerRegistrationTransaction;
    DSChain * chain = providerRegistrationTransactionEntity.transactionHash.chain.chain;
    DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.providerRegistrationTransaction transactionForChain:chain];
    
    return [chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction];
}

-(void)setAttributesFromLocalMasternode:(DSLocalMasternode*)localMasternode {
    self.votingKeysIndex = localMasternode.votingWalletIndex;
    self.votingKeysWalletUniqueId = localMasternode.votingKeysWallet.uniqueID;
    self.ownerKeysWalletUniqueId = localMasternode.ownerKeysWallet.uniqueID;
    self.ownerKeysIndex = localMasternode.ownerWalletIndex;
    self.operatorKeysIndex = localMasternode.operatorWalletIndex;
    self.operatorKeysWalletUniqueId = localMasternode.operatorKeysWallet.uniqueID;
    self.holdingKeysWalletUniqueId = localMasternode.holdingKeysWallet.uniqueID;
    self.holdingKeysIndex = localMasternode.holdingWalletIndex;
    DSProviderRegistrationTransactionEntity * providerRegistrationTransactionEntity = [DSProviderRegistrationTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(localMasternode.providerRegistrationTransaction.txHash)];
    self.providerRegistrationTransaction = providerRegistrationTransactionEntity;
    self.simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntryEntity anyObjectMatching:@"providerRegistrationTransactionHash == %@", uint256_data(localMasternode.providerRegistrationTransaction.txHash)];
}

@end
