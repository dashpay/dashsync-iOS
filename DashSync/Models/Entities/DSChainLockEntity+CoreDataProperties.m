//
//  DSChainLockEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import "DSChainLockEntity+CoreDataProperties.h"

@implementation DSChainLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainLockEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSChainLockEntity"];
}

@dynamic signature;
@dynamic validSignature;
@dynamic quorum;
@dynamic merkleBlock;
@dynamic chainIfLastChainLock;

@end
