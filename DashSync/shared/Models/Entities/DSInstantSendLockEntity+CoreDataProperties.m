//
//  DSInstantSendLockEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//
//

#import "DSInstantSendLockEntity+CoreDataProperties.h"

@implementation DSInstantSendLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSInstantSendLockEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSInstantSendLockEntity"];
}

@dynamic signature;
@dynamic cycleHash;
@dynamic validSignature;
@dynamic transaction;
@dynamic quorum;

@end
