//
//  DSContactRequestEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSContactRequestEntity+CoreDataProperties.h"

@implementation DSContactRequestEntity (CoreDataProperties)

+ (NSFetchRequest<DSContactRequestEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSContactRequestEntity"];
}

@dynamic sourceBlockchainUserRegistrationTransactionHash;
@dynamic destinationBlockchainUserRegistrationTransactionHash;
@dynamic destinationContact;
@dynamic sourceContact;
@dynamic transition;

@end
