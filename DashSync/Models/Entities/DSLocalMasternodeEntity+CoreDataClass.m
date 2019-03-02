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
#import "DSProviderUpdateServiceTransactionEntity+CoreDataProperties.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataProperties.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataProperties.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSWallet.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "NSManagedObject+Sugar.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"

@implementation DSLocalMasternodeEntity

- (DSLocalMasternode*)loadLocalMasternode {
    DSProviderRegistrationTransactionEntity * providerRegistrationTransactionEntity = self.providerRegistrationTransaction;
    DSChain * chain = providerRegistrationTransactionEntity.transactionHash.chain.chain;
    DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.providerRegistrationTransaction transactionForChain:chain];
    
    DSLocalMasternode * localMasternode = [chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction];
    
    for (DSProviderUpdateServiceTransactionEntity * providerUpdateServiceTransactionEntity in self.providerUpdateServiceTransactions) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)[providerUpdateServiceTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateServiceTransaction:providerUpdateServiceTransaction];
    }
    
    for (DSProviderUpdateRegistrarTransactionEntity * providerUpdateRegistrarTransactionEntity in self.providerUpdateRegistrarTransactions) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)[providerUpdateRegistrarTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateRegistrarTransaction:providerUpdateRegistrarTransaction];
    }
    
    for (DSProviderUpdateRevocationTransactionEntity * providerUpdateRevocationTransactionEntity in self.providerUpdateRevocationTransactions) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)[providerUpdateRevocationTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateRevocationTransaction:providerUpdateRevocationTransaction];
    }
    return localMasternode;
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
    DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectMatching:@"providerRegistrationTransactionHash == %@", uint256_data(localMasternode.providerRegistrationTransaction.txHash)];
    self.simplifiedMasternodeEntry = simplifiedMasternodeEntryEntity;
    
    for (DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction in localMasternode.providerUpdateServiceTransactions) {
        DSProviderUpdateServiceTransactionEntity * providerUpdateServiceTransactionEntity = [DSProviderUpdateServiceTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(providerUpdateServiceTransaction.txHash)];
        if (![self.providerUpdateServiceTransactions containsObject:providerUpdateServiceTransactionEntity]) {
            [self addProviderUpdateServiceTransactionsObject:providerUpdateServiceTransactionEntity];
        }
    }
    
    for (DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction in localMasternode.providerUpdateRegistrarTransactions) {
        DSProviderUpdateRegistrarTransactionEntity * providerUpdateRegistrarTransactionEntity = [DSProviderUpdateRegistrarTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(providerUpdateRegistrarTransaction.txHash)];
        if (![self.providerUpdateRegistrarTransactions containsObject:providerUpdateRegistrarTransactionEntity]) {
            [self addProviderUpdateRegistrarTransactionsObject:providerUpdateRegistrarTransactionEntity];
        }
    }
    
    for (DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction in localMasternode.providerUpdateRevocationTransactions) {
        DSProviderUpdateRevocationTransactionEntity * providerUpdateRevocationTransactionEntity = [DSProviderUpdateRevocationTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(providerUpdateRevocationTransaction.txHash)];
        if (![self.providerUpdateRevocationTransactions containsObject:providerUpdateRevocationTransactionEntity]) {
            [self addProviderUpdateRevocationTransactionsObject:providerUpdateRevocationTransactionEntity];
        }
    }
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
    NSArray * localMasternodeEntities = [self objectsMatching:@"(providerRegistrationTransaction.transactionHash.chain == %@)",chainEntity];
    for (DSLocalMasternodeEntity * localMasternodeEntity in localMasternodeEntities) {
        [chainEntity.managedObjectContext deleteObject:localMasternodeEntity];
    }
}

@end
