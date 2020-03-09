//
//  DSBlockchainIdentityKeyPathEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityKeyPathEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityKeyPathEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityKeyPathEntity"];
}

@dynamic path;
@dynamic addedInRegistrations;
@dynamic addedInIdentityUpdates;
@dynamic removedInIdentityUpdates;
@dynamic derivationPath;

@end
