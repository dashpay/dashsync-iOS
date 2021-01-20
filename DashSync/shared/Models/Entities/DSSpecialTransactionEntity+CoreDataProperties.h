//
//  DSSpecialTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/2/19.
//
//

#import "DSSpecialTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSSpecialTransactionEntity *> *)fetchRequest;

@property (nonatomic, assign) uint16_t specialTransactionVersion;
@property (nullable, nonatomic, retain) NSOrderedSet<DSAddressEntity *> *addresses;

@end

@interface DSSpecialTransactionEntity (CoreDataGeneratedAccessors)

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
