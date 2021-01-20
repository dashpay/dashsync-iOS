//
//  DSProviderUpdateRevocationTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//
//

#import "DSProviderUpdateRevocationTransactionEntity+CoreDataProperties.h"

@implementation DSProviderUpdateRevocationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateRevocationTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSProviderUpdateRevocationTransactionEntity"];
}

@dynamic payloadSignature;
@dynamic reason;
@dynamic providerRegistrationTransactionHash;
@dynamic localMasternode;

@end
