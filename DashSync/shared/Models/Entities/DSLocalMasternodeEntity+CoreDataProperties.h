//
//  DSLocalMasternodeEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/3/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternodeEntity (CoreDataProperties)

+ (NSFetchRequest<DSLocalMasternodeEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *operatorKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSString *ownerKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSString *votingKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSString *holdingKeysWalletUniqueId;
@property (assign, nonatomic) uint32_t operatorKeysIndex;
@property (assign, nonatomic) uint32_t ownerKeysIndex;
@property (assign, nonatomic) uint32_t votingKeysIndex;
@property (assign, nonatomic) uint32_t holdingKeysIndex;
@property (nullable, nonatomic, retain) DSProviderRegistrationTransactionEntity *providerRegistrationTransaction;
//@property (nullable, nonatomic, retain) DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntry;
@property (nullable, nonatomic, retain) NSOrderedSet<DSProviderUpdateRegistrarTransactionEntity *> *providerUpdateRegistrarTransactions;
@property (nullable, nonatomic, retain) NSOrderedSet<DSProviderUpdateServiceTransactionEntity *> *providerUpdateServiceTransactions;
@property (nullable, nonatomic, retain) NSOrderedSet<DSProviderUpdateRevocationTransactionEntity *> *providerUpdateRevocationTransactions;

@end

@interface DSLocalMasternodeEntity (CoreDataGeneratedAccessors)

- (void)addProviderUpdateRegistrarTransactionsObject:(DSProviderUpdateRegistrarTransactionEntity *)value;
- (void)removeProviderUpdateRegistrarTransactionsObject:(DSProviderUpdateRegistrarTransactionEntity *)value;
- (void)addProviderUpdateRegistrarTransactions:(NSSet<DSProviderUpdateRegistrarTransactionEntity *> *)values;
- (void)removeProviderUpdateRegistrarTransactions:(NSSet<DSProviderUpdateRegistrarTransactionEntity *> *)values;

- (void)addProviderUpdateServiceTransactionsObject:(DSProviderUpdateServiceTransactionEntity *)value;
- (void)removeProviderUpdateServiceTransactionsObject:(DSProviderUpdateServiceTransactionEntity *)value;
- (void)addProviderUpdateServiceTransactions:(NSSet<DSProviderUpdateServiceTransactionEntity *> *)values;
- (void)removeProviderUpdateServiceTransactions:(NSSet<DSProviderUpdateServiceTransactionEntity *> *)values;

- (void)addProviderUpdateRevocationTransactionsObject:(DSProviderUpdateRevocationTransactionEntity *)value;
- (void)removeProviderUpdateRevocationTransactionsObject:(DSProviderUpdateRevocationTransactionEntity *)value;
- (void)addProviderUpdateRevocationTransactions:(NSSet<DSProviderUpdateRevocationTransactionEntity *> *)values;
- (void)removeProviderUpdateRevocationTransactions:(NSSet<DSProviderUpdateRevocationTransactionEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
