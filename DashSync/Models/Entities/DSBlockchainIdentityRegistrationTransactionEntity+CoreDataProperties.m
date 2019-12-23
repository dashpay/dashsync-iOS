//
//  DSBlockchainIdentityRegistrationTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/30/19.
//
//

#import "DSBlockchainIdentityRegistrationTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityRegistrationTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityRegistrationTransactionEntity"];
}

@dynamic payloadSignature;
@dynamic publicKey;
@dynamic username;
@dynamic ownContact;
@dynamic transitions;

@end
