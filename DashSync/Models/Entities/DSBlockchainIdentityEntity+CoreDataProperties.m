//
//  DSBlockchainIdentityEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityEntity"];
}

@dynamic uniqueID;
@dynamic topUpFundingTransactions;
@dynamic registrationFundingTransaction;
@dynamic keyPaths;
@dynamic matchingDashpayUser;
@dynamic chain;
@dynamic usernames;
@dynamic creditBalance;
@dynamic registrationStatus;
@dynamic type;
@dynamic isLocal;
@dynamic dashpayUsername;

@end
