//
//  DSBlockchainIdentityResetTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityResetTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityResetTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityResetTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityResetTransactionEntity"];
}

@dynamic creditFee;
@dynamic oldPubKeyPayloadSignature;
@dynamic previousBlockchainIdentityTransactionHash;
@dynamic registrationTransactionHash;
@dynamic replacementPublicKey;

@end
