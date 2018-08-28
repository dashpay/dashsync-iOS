//
//  DSBlockchainUserResetTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainUserResetTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainUserResetTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserResetTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainUserResetTransactionEntity"];
}

@dynamic creditFee;
@dynamic oldPubKeyPayloadSignature;
@dynamic previousBlockchainUserTransactionHash;
@dynamic registrationTransactionHash;
@dynamic replacementPublicKey;

@end
