//
//  DSSpecialTransactionsWalletHolder.m
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import "DSAssetLockTransaction.h"
#import "DSAssetUnlockTransaction.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChain+Params.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSPeer.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSSpecialTransactionEntity+CoreDataClass.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSWallet+Protected.h"
#import "NSManagedObject+Sugar.h"

@interface DSSpecialTransactionsWalletHolder ()

@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, strong) NSMutableDictionary *providerRegistrationTransactions;
@property (nonatomic, strong) NSMutableDictionary *providerUpdateServiceTransactions;
@property (nonatomic, strong) NSMutableDictionary *providerUpdateRegistrarTransactions;
@property (nonatomic, strong) NSMutableDictionary *providerUpdateRevocationTransactions;
@property (nonatomic, strong) NSMutableDictionary *assetLockTransactions;
@property (nonatomic, strong) NSMutableDictionary *assetUnlockTransactions;
@property (nonatomic, strong) NSMutableArray<DSTransaction *> *transactionsToSave;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<DSTransaction *> *> *transactionsToSaveInBlockSave;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation DSSpecialTransactionsWalletHolder

- (instancetype)initWithWallet:(DSWallet *)wallet inContext:(NSManagedObjectContext *)managedObjectContext {
    if (!(self = [super init])) return nil;

    self.providerRegistrationTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateServiceTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRegistrarTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRevocationTransactions = [NSMutableDictionary dictionary];
    self.assetLockTransactions = [NSMutableDictionary dictionary];
    self.assetUnlockTransactions = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObjectContext chainContext];
    self.wallet = wallet;
    self.transactionsToSave = [NSMutableArray array];
    self.transactionsToSaveInBlockSave = [NSMutableDictionary dictionary];
    return self;
}

- (NSArray<NSMutableDictionary *> *)transactionDictionaries {
    return @[
        self.providerRegistrationTransactions,
        self.providerUpdateServiceTransactions,
        self.providerUpdateRegistrarTransactions,
        self.providerUpdateRevocationTransactions,
        self.assetLockTransactions,
        self.assetUnlockTransactions
    ];
}


- (NSUInteger)allTransactionsCount {
    NSUInteger count = 0;
    for (NSDictionary *transactionDictionary in [self transactionDictionaries]) {
        count += transactionDictionary.count;
    }
    return count;
}

- (NSArray<DSDerivationPath *> *)derivationPaths {
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

- (DSTransaction *)transactionForHash:(UInt256)transactionHash {
    NSData *transactionHashData = uint256_data(transactionHash);
    for (NSDictionary *transactionDictionary in [self transactionDictionaries]) {
        DSTransaction *transaction = transactionDictionary[transactionHashData];
        if (transaction) return transaction;
    }
    return nil;
}

- (NSArray *)allTransactions {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSDictionary *transactionDictionary in [self transactionDictionaries]) {
        [mArray addObjectsFromArray:[transactionDictionary allValues]];
    }
    return [mArray copy];
}

- (void)setWallet:(DSWallet *)wallet {
    NSAssert(_wallet == nil, @"this should only be called during initialization");
    if (_wallet) return;
    _wallet = wallet;
    [self loadTransactions];
}

- (void)removeAllTransactions {
    for (NSMutableDictionary *transactionDictionary in [self transactionDictionaries]) {
        [transactionDictionary removeAllObjects];
    }
}


- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    [self.transactionsToSaveInBlockSave setObject:[self.transactionsToSave copy] forKey:@(blockNumber)];
    [self.transactionsToSave removeAllObjects];
}

- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context {
    for (DSTransaction *transaction in self.transactionsToSaveInBlockSave[@(blockNumber)]) {
        [transaction setInitialPersistentAttributesInContext:context];
    }
    [self.transactionsToSaveInBlockSave removeObjectForKey:@(blockNumber)];
}

- (BOOL)registerTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    BOOL added = FALSE;
    if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
        if (![self.providerRegistrationTransactions objectForKey:uint256_data(transaction.txHash)]) {
            [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
        if (![self.providerUpdateServiceTransactions objectForKey:uint256_data(transaction.txHash)]) {
            [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        if (![self.providerUpdateRegistrarTransactions objectForKey:uint256_data(transaction.txHash)]) {
            [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        if (![self.providerUpdateRevocationTransactions objectForKey:uint256_data(transaction.txHash)]) {
            [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        if (![self.providerUpdateRevocationTransactions objectForKey:uint256_data(transaction.txHash)]) {
            [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSAssetLockTransaction class]]) {
        DSAssetLockTransaction *assetLockTransaction = (DSAssetLockTransaction *)transaction;
        if (![self.assetLockTransactions objectForKey:uint256_data(assetLockTransaction.txHash)]) {
            [self.assetLockTransactions setObject:transaction forKey:uint256_data(assetLockTransaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSAssetUnlockTransaction class]]) {
        DSAssetUnlockTransaction *assetUnlockTransaction = (DSAssetUnlockTransaction *)transaction;
        if (![self.assetUnlockTransactions objectForKey:uint256_data(assetUnlockTransaction.txHash)]) {
            [self.assetUnlockTransactions setObject:transaction forKey:uint256_data(assetUnlockTransaction.txHash)];
            added = TRUE;
        }
    } else {
        NSAssert(FALSE, @"unknown transaction type being registered");
        return NO;
    }
    if (added) {
        if (saveImmediately) {
            [transaction saveInitial];
        } else {
            [self.transactionsToSave addObject:transaction];
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)loadTransactions {
    if (_wallet.isTransient) return;
    NSManagedObjectContext *context = self.managedObjectContext;
    [context performBlockAndWait:^{
        NSMutableArray *derivationPathEntities = [NSMutableArray array];
        for (DSDerivationPath *derivationPath in [self derivationPaths]) {
            if (![derivationPath hasExtendedPublicKey]) continue;
            DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:self.managedObjectContext];

            //DSLogPrivate(@"addresses for derivation path entity %@",derivationPathEntity.addresses);
            [derivationPathEntities addObject:derivationPathEntity];
        }
        //        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntitiesA = [DSSpecialTransactionEntity allObjectsWithPrefetch:@[@"addresses"] inContext:context];
        //DSLogPrivate(@"%@",[specialTransactionEntitiesA firstObject].addresses.firstObject);
        NSArray<DSSpecialTransactionEntity *> *specialTransactionEntities = [DSSpecialTransactionEntity objectsInContext:context matching:@"(ANY addresses.derivationPath IN %@)", derivationPathEntities];
        for (DSSpecialTransactionEntity *e in specialTransactionEntities) {
            DSTransaction *transaction = [e transactionForChain:self.wallet.chain];

            if (!transaction) continue;
            if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
                [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            } else if ([transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
                [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            } else if ([transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
                [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            } else if ([transaction isMemberOfClass:[DSAssetLockTransaction class]]) {
                [self.assetLockTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            } else if ([transaction isMemberOfClass:[DSAssetUnlockTransaction class]]) {
                [self.assetUnlockTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            } else { //the other ones don't have addresses in payload
                NSAssert(FALSE, @"Unknown special transaction type");
            }
        }
        NSArray *providerRegistrationTransactions = [self.providerRegistrationTransactions allValues];
        for (DSProviderRegistrationTransaction *providerRegistrationTransaction in providerRegistrationTransactions) {
            NSArray<DSProviderUpdateServiceTransactionEntity *> *providerUpdateServiceTransactions = [DSProviderUpdateServiceTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@", uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateServiceTransactionEntity *e in providerUpdateServiceTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];

                if (!transaction) continue;
                [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }

            NSArray<DSProviderUpdateRegistrarTransactionEntity *> *providerUpdateRegistrarTransactions = [DSProviderUpdateRegistrarTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@", uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRegistrarTransactionEntity *e in providerUpdateRegistrarTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];

                if (!transaction) continue;
                [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }

            NSArray<DSProviderUpdateRevocationTransactionEntity *> *providerUpdateRevocationTransactions = [DSProviderUpdateRevocationTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@", uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRevocationTransactionEntity *e in providerUpdateRevocationTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];

                if (!transaction) continue;
                [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
        }

        //        NSArray * identityRegistrationTransactions = [self.identityRegistrationTransactions allValues];
        //
        //        for (DSIdentityRegistrationTransition * identityRegistrationTransaction in identityRegistrationTransactions) {
        //            NSArray<DSBlockchainIdentityResetTransitionEntity *>* identityResetTransactions = [DSBlockchainIdentityResetTransactionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(identityRegistrationTransaction.txHash)];
        //            for (DSBlockchainIdentityResetTransitionEntity *e in identityResetTransactions) {
        //                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
        //
        //                if (! transaction) continue;
        //                [self.identityResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
        //            }
        //
        //            NSArray<DSBlockchainIdentityCloseTransitionEntity *>* identityCloseTransactions = [DSBlockchainIdentityCloseTransactionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(identityRegistrationTransaction.txHash)];
        //            for (DSBlockchainIdentityCloseTransitionEntity *e in identityCloseTransactions) {
        //                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
        //
        //                if (! transaction) continue;
        //                [self.identityCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
        //            }
        //
        //            NSArray<DSBlockchainIdentityTopupTransitionEntity *>* identityTopupTransactions = [DSBlockchainIdentityTopupTransitionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(identityRegistrationTransaction.txHash)];
        //            for (DSBlockchainIdentityTopupTransitionEntity *e in identityTopupTransactions) {
        //                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
        //
        //                if (! transaction) continue;
        //                [self.identityTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
        //            }
        //            NSArray<DSTransition *>* transitions = [DSTransitionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(identityRegistrationTransaction.txHash)];
        //            for (DSTransitionEntity *e in transitions) {
        //                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
        //
        //                if (! transaction) continue;
        //                [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
        //            }
        //        }
    }];
}

//- (DSCreditFundingTransaction *)creditFundingTransactionForIdentityUniqueId:(UInt256)identityUniqueId {
//    return [self.creditFundingTransactions objectForKey:uint256_data(identityUniqueId)];
//}
//
//// MARK: == Blockchain Identities Transaction Retrieval
//
//-(DSIdentityRegistrationTransition*)identityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    for (DSIdentityRegistrationTransition * identityRegistrationTransaction in [self.identityRegistrationTransactions allValues]) {
//        if (uint160_eq(identityRegistrationTransaction.pubkeyHash, publicKeyHash)) {
//            return identityRegistrationTransaction;
//        }
//    }
//    return nil;
//}
//
//- (DSIdentityUpdateTransition*)identityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    for (DSIdentityResetTransition * identityResetTransaction in [self.identityResetTransactions allValues]) {
//        if (uint160_eq(identityResetTransaction.replacementPublicKeyHash, publicKeyHash)) {
//            return identityResetTransaction;
//        }
//    }
//    return nil;
//}
//
//-(NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)identityRegistrationTransactionHash {
//    NSLog(@"identityRegistrationTransactionHash %@",uint256_hex(identityRegistrationTransactionHash));
//    NSMutableArray<DSTransaction*> * subscriptionTransactions = [NSMutableArray array];
//    for (DSIdentityTopupTransition * identityTopupTransaction in [self.identityTopupTransactions allValues]) {
//        if (uint256_eq(identityTopupTransaction.registrationTransactionHash, identityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:identityTopupTransaction];
//        }
//    }
//    for (DSIdentityResetTransition * identityResetTransaction in [self.identityResetTransactions allValues]) {
//        if (uint256_eq(identityResetTransaction.registrationTransactionHash, identityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:identityResetTransaction];
//        }
//    }
//    for (DSIdentityCloseTransition * identityCloseTransaction in [self.identityCloseTransactions allValues]) {
//        if (uint256_eq(identityCloseTransaction.registrationTransactionHash, identityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:identityCloseTransaction];
//        }
//    }
//    for (DSTransition * transition in [self.transitions allValues]) {
//        NSLog(@"transition identityRegistrationTransactionHash %@",uint256_hex(transition.registrationTransactionHash));
//        if (uint256_eq(transition.registrationTransactionHash, identityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:transition];
//        }
//    }
//    return [subscriptionTransactions copy];
//}
//
//-(UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)identityRegistrationTransactionHash {
//    NSMutableOrderedSet * subscriptionTransactions = [NSMutableOrderedSet orderedSetWithArray:[self identityTransitionsForRegistrationTransitionHash:identityRegistrationTransactionHash]];
//    UInt256 lastSubscriptionTransactionHash = identityRegistrationTransactionHash;
//    while ([subscriptionTransactions count]) {
//        BOOL found = FALSE;
//        for (DSTransaction * transaction in [subscriptionTransactions copy]) {
//            if ([transaction isKindOfClass:[DSIdentityTopupTransition class]]) {
//                [subscriptionTransactions removeObject:transaction]; //remove topups
//            } else if ([transaction isKindOfClass:[DSIdentityUpdateTransition class]]) {
//                DSIdentityUpdateTransition * transition = (DSIdentityUpdateTransition*)transaction;
//                if (uint256_eq(transition.previousIdentityTransactionHash, lastSubscriptionTransactionHash)) {
//                    lastSubscriptionTransactionHash = transition.txHash;
//                    found = TRUE;
//                    [subscriptionTransactions removeObject:transition];
//                }
//            } else if ([transaction isKindOfClass:[DSIdentityCloseTransition class]]) {
//                DSIdentityCloseTransition * transition = (DSIdentityCloseTransition*)transaction;
//                if (uint256_eq(transition.previousIdentityTransactionHash, lastSubscriptionTransactionHash)) {
//                    lastSubscriptionTransactionHash = transition.txHash;
//                    found = TRUE;
//                    [subscriptionTransactions removeObject:transition];
//                }
//            } else if ([transaction isKindOfClass:[DSTransition class]]) {
//                DSTransition * transition = (DSTransition*)transaction;
//                if (uint256_eq(transition.previousTransitionHash, lastSubscriptionTransactionHash)) {
//                    lastSubscriptionTransactionHash = transition.txHash;
//                    NSLog(@"%@",uint256_hex(transition.txHash));
//                    found = TRUE;
//                    [subscriptionTransactions removeObject:transition];
//                }
//            }
//        }
//        if (!found) break;
//    }
//    return lastSubscriptionTransactionHash;
//}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes {
    NSMutableArray *updated = [NSMutableArray array];
    NSTimeInterval walletCreationTime = [self.wallet walletCreationTime];
    for (NSValue *hash in txHashes) {
        DSTransaction *tx = [self transactionForHash:uint256_data_from_obj(hash).UInt256];
        UInt256 h;

        if (!tx || (tx.blockHeight == height && tx.timestamp == timestamp)) continue;
#if DEBUG
        DSLogPrivate(@"[%@] Setting special tx %@ height to %d", self.wallet.chain.name, tx, height);
#else
        DSLog(@"[%@] Setting special tx %@ height to %d", self.wallet.chain.name, @"<REDACTED>", height);
#endif
        tx.blockHeight = height;
        if (tx.timestamp == UINT32_MAX || tx.timestamp == 0) {
            //We should only update the timestamp one time
            tx.timestamp = timestamp;
        }


        [updated addObject:tx];
        [hash getValue:&h];
        if ((walletCreationTime == BIP39_WALLET_UNKNOWN_CREATION_TIME || walletCreationTime == BIP39_CREATION_TIME)) {
            [self.wallet setGuessedWalletCreationTime:tx.timestamp - HOUR_TIME_INTERVAL - (DAY_TIME_INTERVAL / arc4random() % DAY_TIME_INTERVAL)];
        }
    }

    return updated;
}

@end
