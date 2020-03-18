//
//  DSContactEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSDashpayUserEntity+CoreDataProperties.h"

@implementation DSDashpayUserEntity (CoreDataProperties)

+ (NSFetchRequest<DSDashpayUserEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSDashpayUserEntity"];
}

@dynamic profileDocumentRevision;
@dynamic contactRequestDocumentRevision;
@dynamic displayName;
@dynamic associatedBlockchainIdentityUniqueId;
@dynamic publicMessage;
@dynamic associatedBlockchainIdentity;
@dynamic outgoingRequests;
@dynamic incomingRequests;
@dynamic friends;
@dynamic encryptionPublicKey;
@dynamic avatarPath;
@dynamic chain;
@dynamic isRegistered;
@dynamic encryptionPublicKeyType;
@dynamic encryptionPublicKeyIndex;

@end
