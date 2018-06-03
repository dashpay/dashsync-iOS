//
//  DSMasternodeBroadcastEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 6/4/18.
//
//

#import "DSMasternodeBroadcastEntity+CoreDataProperties.h"

@implementation DSMasternodeBroadcastEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeBroadcastEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSMasternodeBroadcastEntity"];
}

@dynamic address;
@dynamic mnbHash;
@dynamic port;
@dynamic protocolVersion;
@dynamic signatureTimestamp;
@dynamic utxo;

@end
