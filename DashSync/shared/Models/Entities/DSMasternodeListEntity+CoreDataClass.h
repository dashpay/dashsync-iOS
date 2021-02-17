//
//  DSMasternodeListEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "BigIntTypes.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSMerkleBlockEntity, DSQuorumEntryEntity, DSSimplifiedMasternodeEntryEntity, DSMasternodeList, DSSimplifiedMasternodeEntry, DSQuorumEntry, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity : NSManagedObject

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries;

- (DSMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary<NSNumber *, NSDictionary *> *)quorumEntries withBlockHeightLookup:(uint32_t (^_Nullable)(UInt256 blockHash))blockHeightLookup;

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeListEntity+CoreDataProperties.h"
