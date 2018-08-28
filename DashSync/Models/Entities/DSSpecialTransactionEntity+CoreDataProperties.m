//
//  DSSpecialTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSSpecialTransactionEntity+CoreDataProperties.h"

@implementation DSSpecialTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSSpecialTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSSpecialTransactionEntity"];
}

@dynamic specialTransactionVersion;

@end
