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
#import "DSChain.h"

@interface DSSpecialTransactionsWalletHolder()

@property (nonatomic,weak) DSWallet * wallet;
@property (nonatomic,strong) NSMutableDictionary * providerRegistrationTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateServiceTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRegistrarTransactions;
@property (nonatomic,strong) NSMutableDictionary * providerUpdateRevocationTransactions;
@property (nonatomic,strong) NSMutableDictionary * blockchainUserRegistrationTransactions;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSSpecialTransactionsWalletHolder

-(instancetype)initWithWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    
    self.providerRegistrationTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateServiceTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRegistrarTransactions = [NSMutableDictionary dictionary];
    self.providerUpdateRevocationTransactions = [NSMutableDictionary dictionary];
    self.blockchainUserRegistrationTransactions = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    return self;
}

-(NSArray<NSDictionary*>*)transactionDictionaries {
    return @[self.providerRegistrationTransactions,self.providerUpdateServiceTransactions,self.providerUpdateRegistrarTransactions,self.providerUpdateRevocationTransactions,self.blockchainUserRegistrationTransactions];
}

-(NSUInteger)allTransactionsCount {
    return self.providerRegistrationTransactions.count + self.providerUpdateServiceTransactions.count + self.providerUpdateRegistrarTransactions.count + self.providerUpdateRevocationTransactions.count + self.blockchainUserRegistrationTransactions.count;
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
    _wallet = wallet;
    [self loadTransactions];
}

-(void)loadTransactions {
    if (_wallet.isTransient) return;
    [self.managedObjectContext performBlockAndWait:^{
        [DSTransactionEntity setContext:self.managedObjectContext];
        [DSSpecialTransactionEntity setContext:self.managedObjectContext];
        [DSTxInputEntity setContext:self.managedObjectContext];
        [DSTxOutputEntity setContext:self.managedObjectContext];
        [DSDerivationPathEntity setContext:self.managedObjectContext];
        NSMutableArray * derivationPathEntities = [NSMutableArray array];
        for (DSDerivationPath * derivationPath in [self derivationPaths]) {
            DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath];
            [derivationPathEntities addObject:derivationPathEntity];
        }
        NSArray<DSSpecialTransactionEntity *>* specialTransactionEntities = [DSSpecialTransactionEntity objectsMatching:@"(ANY addresses.derivationPath IN %@)",derivationPathEntities];
            for (DSSpecialTransactionEntity *e in specialTransactionEntities) {
                @autoreleasepool {
                    DSTransaction *transaction = [e transactionForChain:self.wallet.chain];

                    if (! transaction) continue;
                    if ([transaction.entityClass isEqual:[DSProviderRegistrationTransaction class]]) {
                        [self.providerRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                    } else if ([transaction.entityClass isEqual:[DSProviderUpdateServiceTransaction class]]) {
                        [self.providerUpdateServiceTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                    } else if ([transaction.entityClass isEqual:[DSProviderUpdateRegistrarTransaction class]]) {
                        [self.providerUpdateRegistrarTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                    } else if ([transaction.entityClass isEqual:[DSProviderUpdateRevocationTransaction class]]) {
                        [self.providerUpdateRevocationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                    } else if ([transaction.entityClass isEqual:[DSBlockchainUserRegistrationTransaction class]]) {
                        [self.blockchainUserRegistrationTransactions setObject:transaction forKey:uint256_data(transaction.txHash)];
                    }

                }
            }
    }];
}

@end
