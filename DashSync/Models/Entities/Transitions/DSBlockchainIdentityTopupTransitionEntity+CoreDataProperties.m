//
//  DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityTopupTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransitionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityTopupTransitionEntity"];
}

@dynamic topupAmount;

@end
