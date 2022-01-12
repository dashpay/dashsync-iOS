//
//  DSLocalMasternodeEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//
//

#import "BigIntTypes.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSLocalMasternode+Protected.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataProperties.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataProperties.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataProperties.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSLocalMasternodeEntity

- (DSLocalMasternode *)loadLocalMasternode {
    DSProviderRegistrationTransactionEntity *providerRegistrationTransactionEntity = self.providerRegistrationTransaction;
    DSChain *chain = providerRegistrationTransactionEntity.transactionHash.chain.chain;
    DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.providerRegistrationTransaction transactionForChain:chain];

    DSLocalMasternode *localMasternode = [chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:FALSE];

    for (DSProviderUpdateServiceTransactionEntity *providerUpdateServiceTransactionEntity in self.providerUpdateServiceTransactions) {
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)[providerUpdateServiceTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateServiceTransaction:providerUpdateServiceTransaction save:FALSE];
    }

    for (DSProviderUpdateRegistrarTransactionEntity *providerUpdateRegistrarTransactionEntity in self.providerUpdateRegistrarTransactions) {
        DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)[providerUpdateRegistrarTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateRegistrarTransaction:providerUpdateRegistrarTransaction save:FALSE];
    }

    for (DSProviderUpdateRevocationTransactionEntity *providerUpdateRevocationTransactionEntity in self.providerUpdateRevocationTransactions) {
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)[providerUpdateRevocationTransactionEntity transactionForChain:chain];
        [localMasternode updateWithUpdateRevocationTransaction:providerUpdateRevocationTransaction save:FALSE];
    }
    return localMasternode;
}

- (void)setAttributesFromLocalMasternode:(DSLocalMasternode *)localMasternode {
    self.votingKeysIndex = localMasternode.votingWalletIndex;
    self.votingKeysWalletUniqueId = localMasternode.votingKeysWallet.uniqueIDString;
    self.ownerKeysWalletUniqueId = localMasternode.ownerKeysWallet.uniqueIDString;
    self.ownerKeysIndex = localMasternode.ownerWalletIndex;
    self.operatorKeysIndex = localMasternode.operatorWalletIndex;
    self.operatorKeysWalletUniqueId = localMasternode.operatorKeysWallet.uniqueIDString;
    self.holdingKeysWalletUniqueId = localMasternode.holdingKeysWallet.uniqueIDString;
    self.holdingKeysIndex = localMasternode.holdingWalletIndex;
    DSProviderRegistrationTransactionEntity *providerRegistrationTransactionEntity = [DSProviderRegistrationTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(localMasternode.providerRegistrationTransaction.txHash)];
    self.providerRegistrationTransaction = providerRegistrationTransactionEntity;
    DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectInContext:self.managedObjectContext matching:@"providerRegistrationTransactionHash == %@", uint256_data(localMasternode.providerRegistrationTransaction.txHash)];
    self.simplifiedMasternodeEntry = simplifiedMasternodeEntryEntity;

    for (DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction in localMasternode.providerUpdateServiceTransactions) {
        DSProviderUpdateServiceTransactionEntity *providerUpdateServiceTransactionEntity = [DSProviderUpdateServiceTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(providerUpdateServiceTransaction.txHash)];
        if (![self.providerUpdateServiceTransactions containsObject:providerUpdateServiceTransactionEntity]) {
            [self addProviderUpdateServiceTransactionsObject:providerUpdateServiceTransactionEntity];
        }
    }

    for (DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction in localMasternode.providerUpdateRegistrarTransactions) {
        DSProviderUpdateRegistrarTransactionEntity *providerUpdateRegistrarTransactionEntity = [DSProviderUpdateRegistrarTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(providerUpdateRegistrarTransaction.txHash)];
        if (![self.providerUpdateRegistrarTransactions containsObject:providerUpdateRegistrarTransactionEntity]) {
            [self addProviderUpdateRegistrarTransactionsObject:providerUpdateRegistrarTransactionEntity];
        }
    }

    for (DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction in localMasternode.providerUpdateRevocationTransactions) {
        DSProviderUpdateRevocationTransactionEntity *providerUpdateRevocationTransactionEntity = [DSProviderUpdateRevocationTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(providerUpdateRevocationTransaction.txHash)];
        if (![self.providerUpdateRevocationTransactions containsObject:providerUpdateRevocationTransactionEntity]) {
            [self addProviderUpdateRevocationTransactionsObject:providerUpdateRevocationTransactionEntity];
        }
    }
}

+ (NSDictionary<NSData *, DSLocalMasternodeEntity *> *)findLocalMasternodesAndIndexForProviderRegistrationHashes:(NSSet<NSData *> *)providerRegistrationHashes inContext:(NSManagedObjectContext *)context {
    NSArray *localMasternodeEntities = [self objectsInContext:context matching:@"(providerRegistrationTransaction.transactionHash.txHash IN %@)", providerRegistrationHashes];
    NSMutableArray *indexedEntities = [NSMutableArray array];
    for (DSLocalMasternodeEntity *localMasternodeEntity in localMasternodeEntities) {
        [indexedEntities addObject:localMasternodeEntity.providerRegistrationTransaction.transactionHash.txHash];
    }
    return [NSDictionary dictionaryWithObjects:localMasternodeEntities forKeys:indexedEntities]; //!OCLINT
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *localMasternodeEntities = [self objectsInContext:chainEntity.managedObjectContext matching:@"(providerRegistrationTransaction.transactionHash.chain == %@)", chainEntity];
    for (DSLocalMasternodeEntity *localMasternodeEntity in localMasternodeEntities) {
        [chainEntity.managedObjectContext deleteObject:localMasternodeEntity];
    }
}

@end
