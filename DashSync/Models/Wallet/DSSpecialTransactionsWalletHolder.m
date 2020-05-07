//
//  DSSpecialTransactionsWalletHolder.m
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import "DSSpecialTransactionsWalletHolder.h"
#import "DSWallet.h"
#import "NSManagedObject+Sugar.h"
#import "DSSpecialTransactionEntity+CoreDataClass.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSCreditFundingTransaction.h"
#import "DSChain.h"

@interface DSSpecialTransactionsWalletHolder()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary * providerRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateServiceTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRegistrarTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRevocationTransactions;
@property (nonatomic,strong) NSMutableDictionary * creditFundingTransactions;
@property (nonatomic,strong) NSMutableArray <DSTransaction*> *transactionsToSave;
@property (nonatomic,strong) NSMutableDictionary <NSNumber*,NSArray<DSTransaction*>*> *transactionsToSaveInBlockSave;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSSpecialTransactionsWalletHolder

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [super init])) return nil;
    
    self.providerRegistrationTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateServiceTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRegistrarTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRevocationTransactions = [NSMutableDictionary dictionary];
    self.creditFundingTransactions = [NSMutableDictionary dictionary];
    self.managedObjectContext =[NSManagedObjectContext chainContext];
    self.wallet = wallet;
    self.transactionsToSave = [NSMutableArray array];
    self.transactionsToSaveInBlockSave = [NSMutableDictionary dictionary];
    return self;
}

-(NSArray<NSMutableDictionary*>*)transactionDictionaries {
    return @[self.providerRegistrationTransactions,self.providerUpdateServiceTransactions,self.providerUpdateRegistrarTransactions,self.providerUpdateRevocationTransactions,self.creditFundingTransactions];
}

-(NSUInteger)allTransactionsCount {
    NSUInteger count = 0;
    for (NSDictionary * transactionDictionary in [self transactionDictionaries]) {
        count += transactionDictionary.count;
    }
    return count;
}

-(NSArray<DSDerivationPath*>*)derivationPaths {
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

-(DSTransaction*)transactionForHash:(UInt256)transactionHash {
    
    NSData * transactionHashData = uint256_data(transactionHash);
    for (NSDictionary * transactionDictionary in [self transactionDictionaries]) {
        DSTransaction * transaction = [transactionDictionary objectForKey:transactionHashData];
        if (transaction) return transaction;
    }
    return nil;
}

-(NSArray*)allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (NSDictionary * transactionDictionary in [self transactionDictionaries]) {
        [mArray addObjectsFromArray:[transactionDictionary allValues]];
    }
    return [mArray copy];
}

-(void)setWallet:(DSWallet *)wallet {
    NSAssert(!_wallet, @"this should only be called during initialization");
    if (_wallet) return;
    _wallet = wallet;
    [self loadTransactions];
}

- (void)removeAllTransactions {
    for (NSMutableDictionary * transactionDictionary in [self transactionDictionaries]) {
        [transactionDictionary removeAllObjects];
    }
}


-(void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    [self.transactionsToSaveInBlockSave setObject:[self.transactionsToSave copy] forKey:@(blockNumber)];
    [self.transactionsToSave removeAllObjects];
}

-(void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext*)context {
    for (DSTransaction * transaction in self.transactionsToSaveInBlockSave[@(blockNumber)]) {
        [transaction setInitialPersistentAttributesInContext:context];
    }
    [self.transactionsToSaveInBlockSave removeObjectForKey:@(blockNumber)];
}

- (BOOL)registerTransaction:(DSTransaction*)transaction saveImmediately:(BOOL)saveImmediately {
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
    } else if ([transaction isMemberOfClass:[DSCreditFundingTransaction class]]) {
          DSCreditFundingTransaction * creditFundingTransaction = (DSCreditFundingTransaction *)transaction;
          if (![self.creditFundingTransactions objectForKey:uint256_data(creditFundingTransaction.creditBurnIdentityIdentifier)]) {
          [self.creditFundingTransactions setObject:transaction forKey:uint256_data(creditFundingTransaction.creditBurnIdentityIdentifier)];
              added = TRUE;
          }
    } else {
        NSAssert(FALSE,@"unknown transaction type being registered");
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

-(void)loadTransactions {
    if (_wallet.isTransient) return;
    NSManagedObjectContext * context = self.managedObjectContext;
    [context performBlockAndWait:^{
        NSMutableArray * derivationPathEntities = [NSMutableArray array];
        for (DSDerivationPath * derivationPath in [self derivationPaths]) {
            if (![derivationPath hasExtendedPublicKey]) continue;
            DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:self.managedObjectContext];
            
            //DSDLog(@"addresses for derivation path entity %@",derivationPathEntity.addresses);
            [derivationPathEntities addObject:derivationPathEntity];
        }
        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntitiesA = [DSSpecialTransactionEntity allObjectsWithPrefetch:@[@"addresses"] inContext:context];
        NSLog(@"%@",[specialTransactionEntitiesA firstObject].addresses.firstObject);
        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntities = [DSSpecialTransactionEntity objectsInContext:context matching:@"(ANY addresses.derivationPath IN %@)",derivationPathEntities];
        for (DSSpecialTransactionEntity *e in specialTransactionEntities) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
                    [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
                    [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
                    [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSCreditFundingTransaction class]]) {
                    DSCreditFundingTransaction * creditFundingTransaction = (DSCreditFundingTransaction *)transaction;
                    [self.creditFundingTransactions setObject:transaction forKey:uint256_data(creditFundingTransaction.creditBurnIdentityIdentifier)];
                } else { //the other ones don't have addresses in payload
                    NSAssert(FALSE, @"Unknown special transaction type");
                }
        }
        NSArray * providerRegistrationTransactions = [self.providerRegistrationTransactions allValues];
        for (DSProviderRegistrationTransaction * providerRegistrationTransaction in providerRegistrationTransactions) {
            NSArray<DSProviderUpdateServiceTransactionEntity *>* providerUpdateServiceTransactions = [DSProviderUpdateServiceTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateServiceTransactionEntity *e in providerUpdateServiceTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSProviderUpdateRegistrarTransactionEntity *>* providerUpdateRegistrarTransactions = [DSProviderUpdateRegistrarTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRegistrarTransactionEntity *e in providerUpdateRegistrarTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSProviderUpdateRevocationTransactionEntity *>* providerUpdateRevocationTransactions = [DSProviderUpdateRevocationTransactionEntity objectsInContext:context matching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRevocationTransactionEntity *e in providerUpdateRevocationTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
        }
        
//        NSArray * blockchainIdentityRegistrationTransactions = [self.blockchainIdentityRegistrationTransactions allValues];
//
//        for (DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction in blockchainIdentityRegistrationTransactions) {
//            NSArray<DSBlockchainIdentityResetTransitionEntity *>* blockchainIdentityResetTransactions = [DSBlockchainIdentityResetTransactionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
//            for (DSBlockchainIdentityResetTransitionEntity *e in blockchainIdentityResetTransactions) {
//                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
//
//                if (! transaction) continue;
//                [self.blockchainIdentityResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
//            }
//
//            NSArray<DSBlockchainIdentityCloseTransitionEntity *>* blockchainIdentityCloseTransactions = [DSBlockchainIdentityCloseTransactionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
//            for (DSBlockchainIdentityCloseTransitionEntity *e in blockchainIdentityCloseTransactions) {
//                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
//
//                if (! transaction) continue;
//                [self.blockchainIdentityCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
//            }
//
//            NSArray<DSBlockchainIdentityTopupTransitionEntity *>* blockchainIdentityTopupTransactions = [DSBlockchainIdentityTopupTransitionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
//            for (DSBlockchainIdentityTopupTransitionEntity *e in blockchainIdentityTopupTransactions) {
//                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
//
//                if (! transaction) continue;
//                [self.blockchainIdentityTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
//            }
//            NSArray<DSTransition *>* transitions = [DSTransitionEntity objectsInContext:context matching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
//            for (DSTransitionEntity *e in transitions) {
//                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
//
//                if (! transaction) continue;
//                [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
//            }
//        }
    }];
}

-(DSCreditFundingTransaction*)creditFundingTransactionForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    return [self.creditFundingTransactions objectForKey:uint256_data(blockchainIdentityUniqueId)];
}

//// MARK: == Blockchain Identities Transaction Retrieval
//
//-(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    for (DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction in [self.blockchainIdentityRegistrationTransactions allValues]) {
//        if (uint160_eq(blockchainIdentityRegistrationTransaction.pubkeyHash, publicKeyHash)) {
//            return blockchainIdentityRegistrationTransaction;
//        }
//    }
//    return nil;
//}
//
//- (DSBlockchainIdentityUpdateTransition*)blockchainIdentityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    for (DSBlockchainIdentityResetTransition * blockchainIdentityResetTransaction in [self.blockchainIdentityResetTransactions allValues]) {
//        if (uint160_eq(blockchainIdentityResetTransaction.replacementPublicKeyHash, publicKeyHash)) {
//            return blockchainIdentityResetTransaction;
//        }
//    }
//    return nil;
//}
//
//-(NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)blockchainIdentityRegistrationTransactionHash {
//    NSLog(@"blockchainIdentityRegistrationTransactionHash %@",uint256_hex(blockchainIdentityRegistrationTransactionHash));
//    NSMutableArray<DSTransaction*> * subscriptionTransactions = [NSMutableArray array];
//    for (DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction in [self.blockchainIdentityTopupTransactions allValues]) {
//        if (uint256_eq(blockchainIdentityTopupTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:blockchainIdentityTopupTransaction];
//        }
//    }
//    for (DSBlockchainIdentityResetTransition * blockchainIdentityResetTransaction in [self.blockchainIdentityResetTransactions allValues]) {
//        if (uint256_eq(blockchainIdentityResetTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:blockchainIdentityResetTransaction];
//        }
//    }
//    for (DSBlockchainIdentityCloseTransition * blockchainIdentityCloseTransaction in [self.blockchainIdentityCloseTransactions allValues]) {
//        if (uint256_eq(blockchainIdentityCloseTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:blockchainIdentityCloseTransaction];
//        }
//    }
//    for (DSTransition * transition in [self.transitions allValues]) {
//        NSLog(@"transition blockchainIdentityRegistrationTransactionHash %@",uint256_hex(transition.registrationTransactionHash));
//        if (uint256_eq(transition.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
//            [subscriptionTransactions addObject:transition];
//        }
//    }
//    return [subscriptionTransactions copy];
//}
//
//-(UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash {
//    NSMutableOrderedSet * subscriptionTransactions = [NSMutableOrderedSet orderedSetWithArray:[self identityTransitionsForRegistrationTransitionHash:blockchainIdentityRegistrationTransactionHash]];
//    UInt256 lastSubscriptionTransactionHash = blockchainIdentityRegistrationTransactionHash;
//    while ([subscriptionTransactions count]) {
//        BOOL found = FALSE;
//        for (DSTransaction * transaction in [subscriptionTransactions copy]) {
//            if ([transaction isKindOfClass:[DSBlockchainIdentityTopupTransition class]]) {
//                [subscriptionTransactions removeObject:transaction]; //remove topups
//            } else if ([transaction isKindOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
//                DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = (DSBlockchainIdentityUpdateTransition*)transaction;
//                if (uint256_eq(blockchainIdentityResetTransaction.previousBlockchainIdentityTransactionHash, lastSubscriptionTransactionHash)) {
//                    lastSubscriptionTransactionHash = blockchainIdentityResetTransaction.txHash;
//                    found = TRUE;
//                    [subscriptionTransactions removeObject:blockchainIdentityResetTransaction];
//                }
//            } else if ([transaction isKindOfClass:[DSBlockchainIdentityCloseTransition class]]) {
//                DSBlockchainIdentityCloseTransition * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransition*)transaction;
//                if (uint256_eq(blockchainIdentityCloseTransaction.previousBlockchainIdentityTransactionHash, lastSubscriptionTransactionHash)) {
//                    lastSubscriptionTransactionHash = blockchainIdentityCloseTransaction.txHash;
//                    found = TRUE;
//                    [subscriptionTransactions removeObject:blockchainIdentityCloseTransaction];
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

@end
