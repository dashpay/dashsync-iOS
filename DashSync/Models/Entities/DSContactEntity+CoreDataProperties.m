//
//  DSContactEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSContactEntity+CoreDataProperties.h"

@implementation DSContactEntity (CoreDataProperties)

+ (NSFetchRequest<DSContactEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSContactEntity"];
}

@dynamic blockHeight;
@dynamic documentRevision;
@dynamic documentScopeID;
@dynamic username;
@dynamic associatedBlockchainIdentityRegistrationHash;
@dynamic publicMessage;
@dynamic associatedBlockchainIdentityRegistrationTransaction;
@dynamic outgoingRequests;
@dynamic incomingRequests;
@dynamic profileTransition;
@dynamic friends;
@dynamic encryptionPublicKey;
@dynamic avatarPath;
@dynamic chain;

@end
