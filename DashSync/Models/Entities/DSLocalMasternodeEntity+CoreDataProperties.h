//
//  DSLocalMasternodeEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternodeEntity (CoreDataProperties)

+ (NSFetchRequest<DSLocalMasternodeEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *operatorKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSString *ownerKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSString *votingKeysWalletUniqueId;
@property (nullable, nonatomic, copy) NSNumber *operatorKeysIndex;
@property (nullable, nonatomic, copy) NSNumber *ownerKeysIndex;
@property (nullable, nonatomic, copy) NSNumber *votingKeysIndex;
@property (nullable, nonatomic, retain) DSProviderRegistrationTransactionEntity *providerRegistrationTransaction;

@end

NS_ASSUME_NONNULL_END
