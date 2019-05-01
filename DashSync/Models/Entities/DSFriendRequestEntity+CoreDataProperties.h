//
//  DSFriendRequestEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSFriendRequestEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSFriendRequestEntity (CoreDataProperties)

+ (NSFetchRequest<DSFriendRequestEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *sourceBlockchainUserRegistrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *destinationBlockchainUserRegistrationTransactionHash;
@property (nullable, nonatomic, retain) DSContactEntity *destinationContact;
@property (nullable, nonatomic, retain) DSContactEntity *sourceContact;
@property (nullable, nonatomic, retain) DSTransitionEntity *transition;
@property (nullable, nonatomic, retain) NSData *extendedPublicKey;
@property (nullable, nonatomic, retain) DSDerivationPathEntity *derivationPath;

@end

NS_ASSUME_NONNULL_END
