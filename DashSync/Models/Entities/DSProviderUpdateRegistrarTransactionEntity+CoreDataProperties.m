//
//  DSProviderUpdateRegistrarTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/22/19.
//
//

#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataProperties.h"

@implementation DSProviderUpdateRegistrarTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateRegistrarTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSProviderUpdateRegistrarTransactionEntity"];
}

@dynamic operatorKey;
@dynamic payloadSignature;
@dynamic providerMode;
@dynamic scriptPayout;
@dynamic votingKeyHash;
@dynamic providerRegistrationTransactionHash;
@dynamic localMasternode;

@end
