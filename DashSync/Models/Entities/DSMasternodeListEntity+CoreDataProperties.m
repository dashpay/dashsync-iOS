//
//  DSMasternodeListEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//
//

#import "DSMasternodeListEntity+CoreDataProperties.h"

@implementation DSMasternodeListEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeListEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSMasternodeListEntity"];
}

@dynamic masternodes;
@dynamic block;

@end
