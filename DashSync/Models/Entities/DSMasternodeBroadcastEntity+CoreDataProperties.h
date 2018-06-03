//
//  DSMasternodeBroadcastEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/4/18.
//
//

#import "DSMasternodeBroadcastEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeBroadcastEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeBroadcastEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *address;
@property (nullable, nonatomic, retain) NSData *mnbHash;
@property (nullable, nonatomic, copy) NSNumber *port;
@property (nullable, nonatomic, copy) NSNumber *protocolVersion;
@property (nullable, nonatomic, copy) NSNumber *signatureTimestamp;
@property (nullable, nonatomic, retain) NSData *utxo;

@end

NS_ASSUME_NONNULL_END
