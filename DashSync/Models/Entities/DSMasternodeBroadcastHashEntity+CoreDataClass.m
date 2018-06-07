//
//  DSMasternodeBroadcastHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/8/18.
//
//

#import "DSMasternodeBroadcastHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSMasternodeBroadcastHashEntity

+(NSArray*)masternodeBroadcastHashEntitiesWithHashes:(NSOrderedSet*)masternodeBroadcastHashes {
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:masternodeBroadcastHashes.count];
    for (NSData * masternodeBroadcastHash in masternodeBroadcastHashes) {
        DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity = [self managedObject];
        masternodeBroadcastHashEntity.masternodeBroadcastHash = masternodeBroadcastHash;
    }
    return [rArray copy];
}

@end
