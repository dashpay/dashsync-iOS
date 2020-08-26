//
//  DSAccountEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/22/18.
//
//

#import "DSAccountEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSAccountEntity (CoreDataProperties)

+ (NSFetchRequest<DSAccountEntity *> *)fetchRequest;

@property (nonatomic) uint32_t index;
@property (nullable, nonatomic, copy) NSString *walletUniqueID;
@property (nullable, nonatomic, retain) DSChainEntity * chain;
@property (nullable, nonatomic, retain) NSSet<DSTxOutputEntity *> *transactionOutputs;
@property (nullable, nonatomic, retain) NSSet<DSDerivationPathEntity *> *derivationPaths;

@end

@interface DSAccountEntity (CoreDataGeneratedAccessors)

- (void)addTransactionOutputsObject:(DSTxOutputEntity *)value;
- (void)removeTransactionOutputsObject:(DSTxOutputEntity *)value;
- (void)addTransactionOutputs:(NSSet<DSTxOutputEntity *> *)values;
- (void)removeTransactionOutputs:(NSSet<DSTxOutputEntity *> *)values;
- (void)addDerivationPathsObject:(DSDerivationPathEntity *)value;
- (void)removeDerivationPathsObject:(DSDerivationPathEntity *)value;
- (void)addDerivationPaths:(NSSet<DSDerivationPathEntity *> *)values;
- (void)removeDerivationPaths:(NSSet<DSDerivationPathEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
