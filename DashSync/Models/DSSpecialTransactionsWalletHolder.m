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
#import "DSBlockchainUserResetTransactionEntity+CoreDataClass.h"
#import "DSBlockchainUserCloseTransactionEntity+CoreDataClass.h"
#import "DSBlockchainUserTopupTransactionEntity+CoreDataClass.h"
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
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSTransition.h"
#import "DSChain.h"

@interface DSSpecialTransactionsWalletHolder()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary * providerRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateServiceTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRegistrarTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRevocationTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainUserRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainUserTopupTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainUserResetTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainUserCloseTransactions;
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
    self.blockchainUserRegistrationTransactions = [NSMutableDictionary dictionary];
    self.blockchainUserTopupTransactions = [NSMutableDictionary dictionary];
    self.blockchainUserResetTransactions = [NSMutableDictionary dictionary];
    self.blockchainUserCloseTransactions = [NSMutableDictionary dictionary];
    self.transitions = [NSMutableDictionary dictionary];
    self.managedObjectContext = managedObjectContext?managedObjectContext:[NSManagedObject context];
    self.wallet = wallet;
    return self;
}

-(NSArray<NSMutableDictionary*>*)transactionDictionaries {
    return @[self.providerRegistrationTransactions,self.providerUpdateServiceTransactions,self.providerUpdateRegistrarTransactions,self.providerUpdateRevocationTransactions,self.blockchainUserRegistrationTransactions,self.blockchainUserCloseTransactions,self.blockchainUserResetTransactions,self.blockchainUserTopupTransactions,self.transitions];
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

- (void)registerTransaction:(DSTransaction*)transaction {
    if ([transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
        [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
        [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
        [self.blockchainUserRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSBlockchainUserResetTransaction class]]) {
        [self.blockchainUserResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSBlockchainUserCloseTransaction class]]) {
        [self.blockchainUserCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSBlockchainUserTopupTransaction class]]) {
        [self.blockchainUserTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else if ([transaction isMemberOfClass:[DSTransition class]]) {
        [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
    } else {
        NSAssert(FALSE,@"unknown transaction type being registered");
        return;
    }
    [transaction saveInitial];
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
                } else if ([transaction isMemberOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
                    [self.blockchainUserRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                } else if ([transaction isMemberOfClass:[DSBlockchainUserResetTransaction class]]) {
                    [self.blockchainUserResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
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
        
        NSArray * blockchainUserRegistrationTransactions = [self.blockchainUserRegistrationTransactions allValues];
        
        for (DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction in blockchainUserRegistrationTransactions) {
            NSArray<DSBlockchainUserResetTransactionEntity *>* blockchainUserResetTransactions = [DSBlockchainUserResetTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainUserRegistrationTransaction.txHash)];
            for (DSBlockchainUserResetTransactionEntity *e in blockchainUserResetTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainUserResetTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSBlockchainUserCloseTransactionEntity *>* blockchainUserCloseTransactions = [DSBlockchainUserCloseTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainUserRegistrationTransaction.txHash)];
            for (DSBlockchainUserCloseTransactionEntity *e in blockchainUserCloseTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainUserCloseTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            
            NSArray<DSBlockchainUserTopupTransactionEntity *>* blockchainUserTopupTransactions = [DSBlockchainUserTopupTransactionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainUserRegistrationTransaction.txHash)];
            for (DSBlockchainUserTopupTransactionEntity *e in blockchainUserTopupTransactions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.blockchainUserTopupTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
            NSArray<DSTransition *>* transitions = [DSTransitionEntity objectsMatching:@"registrationTransactionHash == %@",uint256_data(blockchainUserRegistrationTransaction.txHash)];
            for (DSTransitionEntity *e in transitions) {
                DSTransaction *transaction = [e transactionForChain:self.wallet.chain];
                
                if (! transaction) continue;
                [self.transitions setObject:transaction forKey:uint256_data(transaction.txHash)];
            }
        }
    }];
}

// MARK: == Blockchain Users Transaction Retrieval

- (DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction in [self.blockchainUserRegistrationTransactions allValues]) {
        if (uint160_eq(blockchainUserRegistrationTransaction.pubkeyHash, publicKeyHash)) {
            return blockchainUserRegistrationTransaction;
        }
    }
    return nil;
}

- (DSBlockchainUserResetTransaction*)blockchainUserResetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSBlockchainUserResetTransaction * blockchainUserResetTransaction in [self.blockchainUserResetTransactions allValues]) {
        if (uint160_eq(blockchainUserResetTransaction.replacementPublicKeyHash, publicKeyHash)) {
            return blockchainUserResetTransaction;
        }
    }
    return nil;
}

- (NSArray<DSTransaction*>*)subscriptionTransactionsForRegistrationTransactionHash:(UInt256)blockchainUserRegistrationTransactionHash {
    NSLog(@"blockchainUserRegistrationTransactionHash %@",uint256_hex(blockchainUserRegistrationTransactionHash));
    NSMutableArray<DSTransaction*> * subscriptionTransactions = [NSMutableArray array];
    for (DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction in [self.blockchainUserTopupTransactions allValues]) {
        if (uint256_eq(blockchainUserTopupTransaction.registrationTransactionHash, blockchainUserRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainUserTopupTransaction];
        }
    }
    for (DSBlockchainUserResetTransaction * blockchainUserResetTransaction in [self.blockchainUserResetTransactions allValues]) {
        if (uint256_eq(blockchainUserResetTransaction.registrationTransactionHash, blockchainUserRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainUserResetTransaction];
        }
    }
    for (DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction in [self.blockchainUserCloseTransactions allValues]) {
        if (uint256_eq(blockchainUserCloseTransaction.registrationTransactionHash, blockchainUserRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:blockchainUserCloseTransaction];
        }
    }
    for (DSTransition * transition in [self.transitions allValues]) {
        NSLog(@"transition blockchainUserRegistrationTransactionHash %@",uint256_hex(transition.registrationTransactionHash));
        if (uint256_eq(transition.registrationTransactionHash, blockchainUserRegistrationTransactionHash)) {
            [subscriptionTransactions addObject:transition];
        }
    }
    return [subscriptionTransactions copy];
}

-(UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainUserRegistrationTransactionHash {
    NSMutableOrderedSet * subscriptionTransactions = [NSMutableOrderedSet orderedSetWithArray:[self subscriptionTransactionsForRegistrationTransactionHash:blockchainUserRegistrationTransactionHash]];
    UInt256 lastSubscriptionTransactionHash = blockchainUserRegistrationTransactionHash;
    while ([subscriptionTransactions count]) {
        BOOL found = FALSE;
        for (DSTransaction * transaction in [subscriptionTransactions copy]) {
            if ([transaction isKindOfClass:[DSBlockchainUserTopupTransaction class]]) {
                [subscriptionTransactions removeObject:transaction]; //remove topups
            } else if ([transaction isKindOfClass:[DSBlockchainUserResetTransaction class]]) {
                DSBlockchainUserResetTransaction * blockchainUserResetTransaction = (DSBlockchainUserResetTransaction*)transaction;
                if (uint256_eq(blockchainUserResetTransaction.previousBlockchainUserTransactionHash, lastSubscriptionTransactionHash)) {
                    lastSubscriptionTransactionHash = blockchainUserResetTransaction.txHash;
                    found = TRUE;
                    [subscriptionTransactions removeObject:blockchainUserResetTransaction];
                }
            } else if ([transaction isKindOfClass:[DSBlockchainUserCloseTransaction class]]) {
                DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction = (DSBlockchainUserCloseTransaction*)transaction;
                if (uint256_eq(blockchainUserCloseTransaction.previousBlockchainUserTransactionHash, lastSubscriptionTransactionHash)) {
                    lastSubscriptionTransactionHash = blockchainUserCloseTransaction.txHash;
                    found = TRUE;
                    [subscriptionTransactions removeObject:blockchainUserCloseTransaction];
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
