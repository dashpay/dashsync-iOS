//
//  DSTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *creditFee;
@property (nullable, nonatomic, retain) NSData *signature;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, copy) NSNumber *signatureId;
@property (nullable, nonatomic, copy) NSNumber *timestamp;
@property (nullable, nonatomic, retain) DSBlockchainIdentityRegistrationTransitionEntity *blockchainIdentityRegistrationTransaction;

@end

NS_ASSUME_NONNULL_END
