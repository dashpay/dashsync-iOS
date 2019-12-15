//
//  DSBlockchainUserRegistrationTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/30/19.
//
//

#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainUserRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserRegistrationTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainUserRegistrationTransactionEntity"];
}

@dynamic payloadSignature;
@dynamic publicKey;
@dynamic username;
@dynamic ownContact;
@dynamic transitions;

@end
