//
//  DSBlockchainIdentityResetTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityResetTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityResetTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityResetTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityResetTransitionEntity"];
}

@dynamic creditFee;
@dynamic oldPubKeyPayloadSignature;
@dynamic previousBlockchainIdentityTransactionHash;
@dynamic registrationTransactionHash;
@dynamic replacementPublicKey;

@end
