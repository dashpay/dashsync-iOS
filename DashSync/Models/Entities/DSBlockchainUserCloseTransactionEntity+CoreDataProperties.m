//
//  DSBlockchainUserCloseTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainUserCloseTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainUserCloseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserCloseTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainUserCloseTransactionEntity"];
}

@dynamic creditFee;
@dynamic previousBlockchainUserTransactionHash;
@dynamic registrationTransactionHash;
@dynamic payloadSignature;

@end
