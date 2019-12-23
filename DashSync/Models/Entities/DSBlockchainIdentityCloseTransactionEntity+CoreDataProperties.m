//
//  DSBlockchainIdentityCloseTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityCloseTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityCloseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityCloseTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityCloseTransactionEntity"];
}

@dynamic creditFee;
@dynamic previousBlockchainIdentityTransactionHash;
@dynamic registrationTransactionHash;
@dynamic payloadSignature;

@end
