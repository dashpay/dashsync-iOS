//
//  DSBlockchainIdentityUpdateTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityUpdateTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityUpdateTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityUpdateTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityKeyPathEntity *> *addedKeyPaths;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityKeyPathEntity *> *removedKeyPaths;

@end

@interface DSBlockchainIdentityUpdateTransitionEntity (CoreDataGeneratedAccessors)

- (void)addAddedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)removeAddedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)addAddedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;
- (void)removeAddedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;

- (void)addRemovedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)removeRemovedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)addRemovedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;
- (void)removeRemovedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
