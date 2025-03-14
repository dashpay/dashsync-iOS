//
//  DSAddressEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 5/8/19.
//
//

#import "DSAddressEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSAddressEntity (CoreDataProperties)

+ (NSFetchRequest<DSAddressEntity *> *)fetchRequest;

@property (nonnull, nonatomic, copy) NSString *address;
@property (nonatomic, assign) uint32_t index;
@property (nonatomic, assign) uint32_t identityIndex;
@property (nonatomic, assign) BOOL internal;
@property (nonatomic, assign) BOOL standalone;
@property (nullable, nonatomic, retain) DSDerivationPathEntity *derivationPath;
@property (nonnull, nonatomic, retain) NSSet<DSTxInputEntity *> *usedInInputs;
@property (nonnull, nonatomic, retain) NSSet<DSTxOutputEntity *> *usedInOutputs;
//@property (nonnull, nonatomic, retain) NSSet<DSSimplifiedMasternodeEntryEntity *> *usedInSimplifiedMasternodeEntries;
@property (nonnull, nonatomic, retain) NSSet<DSSpecialTransactionEntity *> *usedInSpecialTransactions;

@end

@interface DSAddressEntity (CoreDataGeneratedAccessors)

- (void)addUsedInInputsObject:(DSTxInputEntity *)value;
- (void)removeUsedInInputsObject:(DSTxInputEntity *)value;
- (void)addUsedInInputs:(NSSet<DSTxInputEntity *> *)values;
- (void)removeUsedInInputs:(NSSet<DSTxInputEntity *> *)values;

- (void)addUsedInOutputsObject:(DSTxOutputEntity *)value;
- (void)removeUsedInOutputsObject:(DSTxOutputEntity *)value;
- (void)addUsedInOutputs:(NSSet<DSTxOutputEntity *> *)values;
- (void)removeUsedInOutputs:(NSSet<DSTxOutputEntity *> *)values;

//- (void)addUsedInSimplifiedMasternodeEntriesObject:(DSSimplifiedMasternodeEntryEntity *)value;
//- (void)removeUsedInSimplifiedMasternodeEntriesObject:(DSSimplifiedMasternodeEntryEntity *)value;
//- (void)addUsedInSimplifiedMasternodeEntries:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;
//- (void)removeUsedInSimplifiedMasternodeEntries:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;

- (void)addUsedInSpecialTransactionsObject:(DSSpecialTransactionEntity *)value;
- (void)removeUsedInSpecialTransactionsObject:(DSSpecialTransactionEntity *)value;
- (void)addUsedInSpecialTransactions:(NSSet<DSSpecialTransactionEntity *> *)values;
- (void)removeUsedInSpecialTransactions:(NSSet<DSSpecialTransactionEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
