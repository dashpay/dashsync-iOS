//
//  DSBlockchainUserRegistrationTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataProperties.h"

@implementation DSBlockchainUserRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserRegistrationTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainUserRegistrationTransactionEntity"];
}

@dynamic username;
@dynamic publicKey;
@dynamic payloadSignature;

@end
