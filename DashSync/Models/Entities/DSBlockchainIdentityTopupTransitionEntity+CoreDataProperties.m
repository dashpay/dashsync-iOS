//
//  DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityTopupTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityTopupTransitionEntity"];
}

@dynamic registrationTransactionHash;

@end
