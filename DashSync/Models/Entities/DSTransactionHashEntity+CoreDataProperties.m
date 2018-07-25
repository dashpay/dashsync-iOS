//
//  DSTransactionHashEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import "DSTransactionHashEntity+CoreDataProperties.h"

@implementation DSTransactionHashEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransactionHashEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSTransactionHashEntity"];
}

@dynamic blockHeight;
@dynamic timestamp;
@dynamic txHash;
@dynamic transaction;
@dynamic chain;

@end
