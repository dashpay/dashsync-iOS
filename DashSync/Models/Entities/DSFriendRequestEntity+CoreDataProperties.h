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

@property (nonnull, nonatomic, retain) DSDashpayUserEntity *destinationContact;
@property (nonnull, nonatomic, retain) DSDashpayUserEntity *sourceContact;
@property (nonnull, nonatomic, retain) DSDerivationPathEntity *derivationPath;
@property (nonnull, nonatomic, retain) DSAccountEntity *account;
@property (nonnull, nonatomic, retain) NSData * friendshipIdentifier;

@end

NS_ASSUME_NONNULL_END
