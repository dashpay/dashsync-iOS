//
//  DSBlockchainIdentityUsernameEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 1/31/20.
//
//

#import "DSBlockchainIdentityUsernameEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityUsernameEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityUsernameEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityUsernameEntity"];
}

@dynamic status;
@dynamic stringValue;
@dynamic blockchainIdentity;
@dynamic salt;

@end
