//
//  DSBlockchainIdentityUpdateTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityUpdateTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityUpdateTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityUpdateTransitionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityUpdateTransitionEntity"];
}

@dynamic addedKeyPaths;
@dynamic removedKeyPaths;

@end
