//
//  DSMasternodeListEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "DSMasternodeListEntity+CoreDataProperties.h"

@implementation DSMasternodeListEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeListEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSMasternodeListEntity"];
}

@dynamic block;
@dynamic masternodes;
@dynamic quorums;

@end
