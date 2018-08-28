//
//  DSBlockchainUserTopupTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserTopupTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainUserTopupTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserTopupTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainUserTopupTransactionEntity"];
}

@dynamic registrationTransactionHash;

@end
