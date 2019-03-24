//
//  DSContactEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSContactEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSContactEntity (CoreDataProperties)

+ (NSFetchRequest<DSContactEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *blockHeight;
@property (nullable, nonatomic, copy) NSString *publicKeyIdentifier;
@property (nullable, nonatomic, copy) NSString *username;
@property (nullable, nonatomic, retain) NSData *blockchainUserRegistrationHash;
@property (nullable, nonatomic, copy) NSString *publicMessage;
@property (nullable, nonatomic, retain) DSAccountEntity *account;
@property (nullable, nonatomic, retain) DSDerivationPathEntity *derivationPath;
@property (nullable, nonatomic, retain) DSBlockchainUserRegistrationTransactionEntity *ownerBlockchainUserRegistrationTransaction;
@property (nullable, nonatomic, retain) NSSet<DSContactRequestEntity *> *sourcedRequests;
@property (nullable, nonatomic, retain) NSSet<DSContactRequestEntity *> *recipientRequests;
@property (nullable, nonatomic, retain) DSTransitionEntity *profileTransition;

@end

@interface DSContactEntity (CoreDataGeneratedAccessors)

- (void)addSourcedRequestsObject:(DSContactRequestEntity *)value;
- (void)removeSourcedRequestsObject:(DSContactRequestEntity *)value;
- (void)addSourcedRequests:(NSSet<DSContactRequestEntity *> *)values;
- (void)removeSourcedRequests:(NSSet<DSContactRequestEntity *> *)values;

- (void)addRecipientRequestsObject:(DSContactRequestEntity *)value;
- (void)removeRecipientRequestsObject:(DSContactRequestEntity *)value;
- (void)addRecipientRequests:(NSSet<DSContactRequestEntity *> *)values;
- (void)removeRecipientRequests:(NSSet<DSContactRequestEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
