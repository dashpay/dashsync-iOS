//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityRegistrationTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityRegistrationTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *identityIdentifier;
@property (nullable, nonatomic, retain) DSContactEntity *ownContact;
@property (nullable, nonatomic, retain) NSSet<DSTransitionEntity *> *transitions;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityKeyPathEntity *> *usedKeyPaths;

@end

@interface DSBlockchainIdentityRegistrationTransitionEntity (CoreDataGeneratedAccessors)

- (void)addTransitionsObject:(DSTransitionEntity *)value;
- (void)removeTransitionsObject:(DSTransitionEntity *)value;
- (void)addTransitions:(NSSet<DSTransitionEntity *> *)values;
- (void)removeTransitions:(NSSet<DSTransitionEntity *> *)values;

- (void)addUsedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)removeUsedKeyPathsObject:(DSBlockchainIdentityKeyPathEntity *)value;
- (void)addUsedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;
- (void)removeUsedKeyPaths:(NSSet<DSBlockchainIdentityKeyPathEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
