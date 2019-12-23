//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/30/19.
//
//

#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityRegistrationTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityRegistrationTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (nullable, nonatomic, retain) NSData *publicKey;
@property (nullable, nonatomic, copy) NSString *username;
@property (nullable, nonatomic, retain) DSContactEntity *ownContact;
@property (nullable, nonatomic, retain) NSSet<DSTransitionEntity *> *transitions;

@end

@interface DSBlockchainIdentityRegistrationTransitionEntity (CoreDataGeneratedAccessors)

- (void)addTransitionsObject:(DSTransitionEntity *)value;
- (void)removeTransitionsObject:(DSTransitionEntity *)value;
- (void)addTransitions:(NSSet<DSTransitionEntity *> *)values;
- (void)removeTransitions:(NSSet<DSTransitionEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
