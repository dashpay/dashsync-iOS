//
//  DSProviderRegistrationTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//
//

#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"

@implementation DSProviderRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderRegistrationTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSProviderRegistrationTransactionEntity"];
}

@dynamic payloadSignature;
@dynamic providerType;
@dynamic providerMode;
@dynamic collateralOutpoint;
@dynamic ipAddress;
@dynamic port;
@dynamic ownerKeyHash;
@dynamic operatorKey;
@dynamic votingKeyHash;
@dynamic operatorReward;
@dynamic scriptPayout;

@end
