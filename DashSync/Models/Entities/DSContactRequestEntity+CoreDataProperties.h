//
//  DSContactRequestEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSContactRequestEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSContactRequestEntity (CoreDataProperties)

+ (NSFetchRequest<DSContactRequestEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *sourceBlockchainUserRegistrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *destinationBlockchainUserRegistrationTransactionHash;
@property (nullable, nonatomic, retain) DSContactEntity *destinationContact;
@property (nullable, nonatomic, retain) DSContactEntity *sourceContact;
@property (nullable, nonatomic, retain) DSTransitionEntity *transition;

@end

NS_ASSUME_NONNULL_END
