//
//  DSCoinbaseTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/23/19.
//
//

#import "DSCoinbaseTransactionEntity+CoreDataProperties.h"

@implementation DSCoinbaseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSCoinbaseTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSCoinbaseTransactionEntity"];
}

@dynamic height;
@dynamic merkleRootMNList;

@end
