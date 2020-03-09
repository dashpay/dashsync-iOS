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

@dynamic documentRevision;
@dynamic username;
@dynamic displayName;
@dynamic associatedBlockchainIdentityUniqueId;
@dynamic publicMessage;
@dynamic associatedBlockchainIdentity;
@dynamic outgoingRequests;
@dynamic incomingRequests;
@dynamic profileTransition;
@dynamic friends;
@dynamic encryptionPublicKey;
@dynamic avatarPath;
@dynamic chain;
@dynamic isRegistered;
@dynamic encryptionPublicKeyType;
@dynamic encryptionPublicKeyIndex;

@end
