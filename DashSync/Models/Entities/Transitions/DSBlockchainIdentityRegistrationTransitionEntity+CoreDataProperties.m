//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityRegistrationTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityRegistrationTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityRegistrationTransitionEntity"];
}

@dynamic identityIdentifier;
@dynamic ownContact;
@dynamic transitions;
@dynamic usedKeyPaths;

@end
