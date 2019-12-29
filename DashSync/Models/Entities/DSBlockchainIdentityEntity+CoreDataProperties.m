//
//  DSBlockchainIdentityEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityEntity"];
}

@dynamic uniqueId;
@dynamic creditFundingTransactions;
@dynamic keyPaths;
@dynamic transitions;
@dynamic ownContact;

@end
