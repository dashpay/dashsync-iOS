//
//  DSBlockchainIdentityKeyPathEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import "DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityKeyPathEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityKeyPathEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityKeyPathEntity"];
}

@dynamic path;
@dynamic derivationPath;
@dynamic blockchainIdentity;
@dynamic keyType;
@dynamic keyStatus;
@dynamic keyID;
@dynamic securityLevel;
@dynamic purpose;
@dynamic publicKeyData;

@end
