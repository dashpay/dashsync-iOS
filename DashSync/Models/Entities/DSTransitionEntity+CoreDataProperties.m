//
//  DSTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/14/19.
//
//

#import "DSTransitionEntity+CoreDataProperties.h"

@implementation DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSTransitionEntity"];
}

@dynamic previousSubcriptionHash;
@dynamic creditFee;
@dynamic packetHash;
@dynamic payloadSignature;
@dynamic registrationTransactionHash;
@dynamic blockchainUserRegistrationTransaction;

@end
