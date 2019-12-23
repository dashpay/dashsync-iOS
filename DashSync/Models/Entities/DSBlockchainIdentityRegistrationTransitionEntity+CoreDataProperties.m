//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/30/19.
//
//

#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityRegistrationTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityRegistrationTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityRegistrationTransitionEntity"];
}

@dynamic payloadSignature;
@dynamic publicKey;
@dynamic username;
@dynamic ownContact;
@dynamic transitions;

@end
