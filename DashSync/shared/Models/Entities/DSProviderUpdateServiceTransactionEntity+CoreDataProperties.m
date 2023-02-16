//
//  DSProviderUpdateServiceTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//
//

#import "DSProviderUpdateServiceTransactionEntity+CoreDataProperties.h"

@implementation DSProviderUpdateServiceTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateServiceTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSProviderUpdateServiceTransactionEntity"];
}

@dynamic ipAddress;
@dynamic payloadSignature;
@dynamic port;
@dynamic scriptPayout;
@dynamic providerRegistrationTransactionHash;
@dynamic localMasternode;
@dynamic providerType;
@dynamic platformHTTPPort;
@dynamic platformP2PPort;
@dynamic platformNodeID;

@end
