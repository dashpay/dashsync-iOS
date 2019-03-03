//
//  DSSpecialTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/2/19.
//
//

#import "DSSpecialTransactionEntity+CoreDataProperties.h"

@implementation DSSpecialTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSSpecialTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSSpecialTransactionEntity"];
}

@dynamic specialTransactionVersion;
@dynamic addresses;

@end
