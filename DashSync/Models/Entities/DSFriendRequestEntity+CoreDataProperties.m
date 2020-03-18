//
//  DSFriendRequestEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSFriendRequestEntity+CoreDataProperties.h"

@implementation DSFriendRequestEntity (CoreDataProperties)

+ (NSFetchRequest<DSFriendRequestEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSFriendRequestEntity"];
}

@dynamic destinationContact;
@dynamic sourceContact;
@dynamic derivationPath;
@dynamic account;
@dynamic friendshipIdentifier;

@end
