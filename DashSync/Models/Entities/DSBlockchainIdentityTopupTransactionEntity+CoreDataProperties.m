//
//  DSBlockchainIdentityTopupTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityTopupTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityTopupTransactionEntity"];
}

@dynamic registrationTransactionHash;

@end
