//
//  DSContractEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import "DSContractEntity+CoreDataProperties.h"

@implementation DSContractEntity (CoreDataProperties)

+ (NSFetchRequest<DSContractEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSContractEntity"];
}

@dynamic identifier;
@dynamic state;
@dynamic chain;
@dynamic creator;

@end
