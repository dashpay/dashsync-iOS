//
//  DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityKeyPathEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityKeyPathEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSObject *path;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *addedInIdentityUpdates;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityRegistrationTransitionEntity *> *addedInRegistrations;
@property (nullable, nonatomic, retain) DSDerivationPathEntity *derivationPath;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *removedInIdentityUpdates;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *blockchainIdentity;

@end

@interface DSBlockchainIdentityKeyPathEntity (CoreDataGeneratedAccessors)

- (void)addAddedInIdentityUpdatesObject:(DSBlockchainIdentityUpdateTransitionEntity *)value;
- (void)removeAddedInIdentityUpdatesObject:(DSBlockchainIdentityUpdateTransitionEntity *)value;
- (void)addAddedInIdentityUpdates:(NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *)values;
- (void)removeAddedInIdentityUpdates:(NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *)values;

- (void)addAddedInRegistrationsObject:(DSBlockchainIdentityRegistrationTransitionEntity *)value;
- (void)removeAddedInRegistrationsObject:(DSBlockchainIdentityRegistrationTransitionEntity *)value;
- (void)addAddedInRegistrations:(NSSet<DSBlockchainIdentityRegistrationTransitionEntity *> *)values;
- (void)removeAddedInRegistrations:(NSSet<DSBlockchainIdentityRegistrationTransitionEntity *> *)values;

- (void)addRemovedInIdentityUpdatesObject:(DSBlockchainIdentityUpdateTransitionEntity *)value;
- (void)removeRemovedInIdentityUpdatesObject:(DSBlockchainIdentityUpdateTransitionEntity *)value;
- (void)addRemovedInIdentityUpdates:(NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *)values;
- (void)removeRemovedInIdentityUpdates:(NSSet<DSBlockchainIdentityUpdateTransitionEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
