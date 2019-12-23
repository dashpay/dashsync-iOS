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
#import "DSBlockchainIdentityResetTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityCloseTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityTopupTransactionEntity+CoreDataClass.h"
#import "DSTransitionEntity+CoreDataClass.h"
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
#import "DSBlockchainIdentityRegistrationTransaction.h"
#import "DSBlockchainIdentityTopupTransaction.h"
#import "DSBlockchainIdentityCloseTransaction.h"
#import "DSBlockchainIdentityResetTransaction.h"
#import "DSTransition.h"
#import "DSChain.h"

@interface DSSpecialTransactionsWalletHolder()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary * providerRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateServiceTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRegistrarTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRevocationTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainIdentityRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainIdentityTopupTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainIdentityResetTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainIdentityCloseTransactions;
@property (nonatomic,strong) NSMutableDictionary * transitions;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSSpecialTransactionsWalletHolder

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [super init])) return nil;
    
    self.providerRegistrationTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateServiceTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRegistrarTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRevocationTransactions = [NSMutableDictionary dictionary];
    self.blockchainIdentityRegistrationTransactions = [NSMutableDictionary dictionary];
    self.blockchainIdentityTopupTransactions = [NSMutableDictionary dictionary];
    self.blockchainIdentityResetTransactions = [NSMutableDictionary dictionary];
    self.blockchainIdentityCloseTransactions = [NSMutableDictionary dictionary];
    self.transitions = [NSMutableDictionary dictionary];
    self.managedObjectContext = managedObjectContext?managedObjectContext:[NSManagedObject context];
    self.wallet = wallet;
    return self;
}

-(NSArray<NSMutableDictionary*>*)transactionDictionaries {
    return @[self.providerRegistrationTransactions,self.providerUpdateServiceTransactions,self.providerUpdateRegistrarTransactions,self.providerUpdateRevocationTransactions,self.blockchainIdentityRegistrationTransactions,self.blockchainIdentityCloseTransactions,self.blockchainIdentityResetTransactions,self.blockchainIdentityTopupTransactions,self.transitions];
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

- (BOOL)registerTransaction:(DSTransaction*)transaction {
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
    } else if ([transaction isMemberOfClass:[DSBlockchainIdentityRegistrationTransaction class]]) {
        if (![self.blockchainIdentityRegistrationTransactions objectForKey:uint256_data(transaction.txHash)]) {
        [self.blockchainIdentityRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSBlockchainIdentityResetTransaction class]]) {
        if (![self.blockchainIdentityResetTransactions objectForKey:uint256_data(transaction.txHash)]) {
        [self.blockchainIdentityResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSBlockchainIdentityCloseTransaction class]]) {
        if (![self.blockchainIdentityCloseTransactions objectForKey:uint256_data(transaction.txHash)]) {
        [self.blockchainIdentityCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSBlockchainIdentityTopupTransaction class]]) {
        if (![self.blockchainIdentityTopupTransactions objectForKey:uint256_data(transaction.txHash)]) {
        [self.blockchainIdentityTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else if ([transaction isMemberOfClass:[DSTransition class]]) {
        if (![self.transitions objectForKey:uint256_data(transaction.txHash)]) {
        [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
            added = TRUE;
        }
    } else {
        NSAssert(FALSE,@"unknown transaction type being registered");
        return NO;
    }
    if (added) {
        [transaction saveInitial];
        return YES;
    } else {
        return NO;
    }
}

-(void)loadTransactions {
    if (_wallet.isTransient) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSTransactionEntity setContext:self.managedObjectContext];
        [DSSpecialTransactionEntity setContext:self.managedObjectContext];
        [DSTxInputEntity setContext:self.managedObjectContext];
        [DSTxOutputEntity setContext:self.managedObjectContext];
        [DSAddressEntity setContext:self.managedObjectContext];
        [DSDerivationPathEntity setContext:self.managedObjectContext];
        NSMutableArray * derivationPathEntities = [NSMutableArray array];
        for (DSDerivationPath * derivationPath in [self derivationPaths]) {
            if (![derivationPath hasExtendedPublicKey]) continue;
            DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath];
            
            //DSDLog(@"addresses for derivation path entity %@",derivationPathEntity.addresses);
            [derivationPathEntities addObject:derivationPathEntity];
        }
        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntitiesA = [DSSpecialTransactionEntity allObjectsWithPrefetch:@[@"addresses"]];
        NSLog(@"%@",[specialTransactionEntitiesA firstObject].addresses.firstObject);
        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntities = [DSSpecialTransactionEntity objectsMatching:@"(ANY addresses.derivationPath IN %@)",derivationPathEntities];
        for (DSSpecialTransactionEntity *e in specialTransactionEntities) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
                    [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
                    [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
                    [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSBlockchainIdentityRegistrationTransaction class]]) {
                    [self.blockchainIdentityRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSBlockchainIdentityResetTransaction class]]) {
                    [self.blockchainIdentityResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else { //the other ones don't have addresses in payload
                    NSAssert(FALSE, @"Unknown special transaction type");
                }
        }
        NSArray * providerRegistrationTransactions = [self.providerRegistrationTransactions allValues];
        for (DSProviderRegistrationTransaction * providerRegistrationTransaction in providerRegistrationTransactions) {
            NSArray<DSProviderUpdateServiceTransactionEntity *>* providerUpdateServiceTransactions = [DSProviderUpdateServiceTransactionEntity objectsMatching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateServiceTransactionEntity *e in providerUpdateServiceTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSProviderUpdateRegistrarTransactionEntity *>* providerUpdateRegistrarTransactions = [DSProviderUpdateRegistrarTransactionEntity objectsMatching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRegistrarTransactionEntity *e in providerUpdateRegistrarTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSProviderUpdateRevocationTransactionEntity *>* providerUpdateRevocationTransactions = [DSProviderUpdateRevocationTransactionEntity objectsMatching:@"providerRegistrationTransactionHash == %@",uint256_data(providerRegistrationTransaction.txHash)];
            for (DSProviderUpdateRevocationTransactionEntity *e in providerUpdateRevocationTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
        }
        
        NSArray * blockchainIdentityRegistrationTransactions = [self.blockchainIdentityRegistrationTransactions allValues];
        
        for (DSBlockchainIdentityRegistrationTransaction * blockchainIdentityRegistrationTransaction in blockchainIdentityRegistrationTransactions) {
            NSArray<DSBlockchainIdentityResetTransactionEntity *>* blockchainIdentityResetTransactions = [DSBlockchainIdentityResetTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
            for (DSBlockchainIdentityResetTransactionEntity *e in blockchainIdentityResetTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainIdentityResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSBlockchainIdentityCloseTransactionEntity *>* blockchainIdentityCloseTransactions = [DSBlockchainIdentityCloseTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
            for (DSBlockchainIdentityCloseTransactionEntity *e in blockchainIdentityCloseTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainIdentityCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSBlockchainIdentityTopupTransactionEntity *>* blockchainIdentityTopupTransactions = [DSBlockchainIdentityTopupTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
            for (DSBlockchainIdentityTopupTransactionEntity *e in blockchainIdentityTopupTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainIdentityTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            NSArray<DSTransition *>* transitions = [DSTransitionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainIdentityRegistrationTransaction.txHash)];
            for (DSTransitionEntity *e in transitions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
        }
    }];
}

// MARK: == Blockchain Identities Transaction Retrieval

- (DSBlockchainIdentityRegistrationTransaction*)blockchainIdentityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSBlockchainIdentityRegistrationTransaction * blockchainIdentityRegistrationTransaction in [self.blockchainIdentityRegistrationTransactions allValues]) {
        if (uint160_eq(blockchainIdentityRegistrationTransaction.pubkeyHash, publicKeyHash)) {
            return blockchainIdentityRegistrationTransaction;
        }
    }
    return nil;
}

- (DSBlockchainIdentityResetTransaction*)blockchainIdentityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSBlockchainIdentityResetTransaction * blockchainIdentityResetTransaction in [self.blockchainIdentityResetTransactions allValues]) {
        if (uint160_eq(blockchainIdentityResetTransaction.replacementPublicKeyHash, publicKeyHash)) {
            return blockchainIdentityResetTransaction;
        }
    }
    return nil;
}

- (NSArray<DSTransaction*>*)subscriptionTransactionsForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash {
    NSLog(@"blockchainIdentityRegistrationTransactionHash %@",uint256_hex(blockchainIdentityRegistrationTransactionHash));
    NSMutableArray<DSTransaction*> * subscriptionTransactions = [NSMutableArray array];
    for (DSBlockchainIdentityTopupTransaction * blockchainIdentityTopupTransaction in [self.blockchainIdentityTopupTransactions allValues]) {
        if (uint256_eq(blockchainIdentityTopupTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainIdentityTopupTransaction];
        }
    }
    for (DSBlockchainIdentityResetTransaction * blockchainIdentityResetTransaction in [self.blockchainIdentityResetTransactions allValues]) {
        if (uint256_eq(blockchainIdentityResetTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainIdentityResetTransaction];
        }
    }
    for (DSBlockchainIdentityCloseTransaction * blockchainIdentityCloseTransaction in [self.blockchainIdentityCloseTransactions allValues]) {
        if (uint256_eq(blockchainIdentityCloseTransaction.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainIdentityCloseTransaction];
        }
    }
    for (DSTransition * transition in [self.transitions allValues]) {
        NSLog(@"transition blockchainIdentityRegistrationTransactionHash %@",uint256_hex(transition.registrationTransactionHash));
        if (uint256_eq(transition.registrationTransactionHash, blockchainIdentityRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:transition];
        }
    }
    return [subscriptionTransactions copy];
}

-(UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash {
    NSMutableOrderedSet * subscriptionTransactions = [NSMutableOrderedSet orderedSetWithArray:[self subscriptionTransactionsForRegistrationTransactionHash:blockchainIdentityRegistrationTransactionHash]];
    UInt256 lastSubscriptionTransactionHash = blockchainIdentityRegistrationTransactionHash;
    while ([subscriptionTransactions count]) {
        BOOL found = FALSE;
        for (DSTransaction * transaction in [subscriptionTransactions copy]) {
            if ([transaction isKindOfClass:[DSBlockchainIdentityTopupTransaction class]]) {
                [subscriptionTransactions removeObject:transaction]; //remove topups
            } else if ([transaction isKindOfClass:[DSBlockchainIdentityResetTransaction class]]) {
                DSBlockchainIdentityResetTransaction * blockchainIdentityResetTransaction = (DSBlockchainIdentityResetTransaction*)transaction;
                if (uint256_eq(blockchainIdentityResetTransaction.previousBlockchainIdentityTransactionHash, lastSubscriptionTransactionHash)) {
                    lastSubscriptionTransactionHash = blockchainIdentityResetTransaction.txHash;
                    found = TRUE;
                    [subscriptionTransactions removeObject:blockchainIdentityResetTransaction];
                }
            } else if ([transaction isKindOfClass:[DSBlockchainIdentityCloseTransaction class]]) {
                DSBlockchainIdentityCloseTransaction * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransaction*)transaction;
                if (uint256_eq(blockchainIdentityCloseTransaction.previousBlockchainIdentityTransactionHash, lastSubscriptionTransactionHash)) {
                    lastSubscriptionTransactionHash = blockchainIdentityCloseTransaction.txHash;
                    found = TRUE;
                    [subscriptionTransactions removeObject:blockchainIdentityCloseTransaction];
                }
            } else if ([transaction isKindOfClass:[DSTransition class]]) {
                DSTransition * transition = (DSTransition*)transaction;
                if (uint256_eq(transition.previousTransitionHash, lastSubscriptionTransactionHash)) {
                    lastSubscriptionTransactionHash = transition.txHash;
                    NSLog(@"%@",uint256_hex(transition.txHash));
                    found = TRUE;
                    [subscriptionTransactions removeObject:transition];
                }
            }
        }
        if (!found) break;
    }
    return lastSubscriptionTransactionHash;
}

@end
