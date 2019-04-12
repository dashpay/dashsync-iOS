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
@dynamic username;
@dynamic blockchainUserRegistrationHash;
@dynamic publicMessage;
@dynamic account;
@dynamic derivationPath;
@dynamic ownerBlockchainUserRegistrationTransaction;
@dynamic outgoingRequests;
@dynamic incomingRequests;
@dynamic profileTransition;
@dynamic friends;
@dynamic encryptionPublicKey;

@end
