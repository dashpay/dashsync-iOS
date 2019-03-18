//
//  DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternodeEntity;

@interface DSSimplifiedMasternodeEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSSimplifiedMasternodeEntryEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *providerRegistrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *confirmedHash;
@property (nonatomic, assign) uint64_t address; //it's really on 32 bits but unsigned
@property (nonatomic, assign) uint16_t port;
@property (nullable, nonatomic, retain) NSData *operatorBLSPublicKey;
@property (nullable, nonatomic, retain) NSData *keyIDVoting;
@property (nonatomic, assign) Boolean isValid;
@property (nullable, nonatomic, retain) NSData *simplifiedMasternodeEntryHash;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity * localMasternode;
@property (nullable, nonatomic, retain) NSOrderedSet<DSAddressEntity *> *addresses;

@end

@interface DSSimplifiedMasternodeEntryEntity (CoreDataGeneratedAccessors)

- (void)insertObject:(DSAddressEntity *)value inAddressesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAddressesAtIndex:(NSUInteger)idx;
- (void)insertAddresses:(NSArray<DSAddressEntity *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeAddressesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInAddressesAtIndex:(NSUInteger)idx withObject:(DSAddressEntity *)value;
- (void)replaceAddressesAtIndexes:(NSIndexSet *)indexes withAddresses:(NSArray<DSAddressEntity *> *)values;
- (void)addAddressesObject:(DSAddressEntity *)value;
- (void)removeAddressesObject:(DSAddressEntity *)value;
- (void)addAddresses:(NSOrderedSet<DSAddressEntity *> *)values;
- (void)removeAddresses:(NSOrderedSet<DSAddressEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
