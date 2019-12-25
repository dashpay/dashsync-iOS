//
//  DSBlockchainIdentityCloseTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityCloseTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityCloseTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityCloseTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityCloseTransitionEntity"];
}

@dynamic creditFee;
@dynamic previousBlockchainIdentityTransactionHash;
@dynamic registrationTransactionHash;
@dynamic payloadSignature;

@end
