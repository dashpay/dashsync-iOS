//
//  DSInstantSendLockEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/7/19.
//
//

#import "DSInstantSendLockEntity+CoreDataProperties.h"

@implementation DSInstantSendLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSInstantSendLockEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSInstantSendLockEntity"];
}

@dynamic fromValidQuorum;
@dynamic inputsOutpoints;
@dynamic transactionHash;
@dynamic instantSendLockHash;
@dynamic signature;
@dynamic chain;
@dynamic transaction;
@dynamic simplifiedMasternodeEntries;

@end
