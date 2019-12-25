//
//  DSTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSTransitionEntity+CoreDataProperties.h"

@implementation DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSTransitionEntity"];
}

@dynamic creditFee;
@dynamic signature;
@dynamic registrationTransactionHash;
@dynamic signatureId;
@dynamic timestamp;
@dynamic blockchainIdentityRegistrationTransaction;

@end
