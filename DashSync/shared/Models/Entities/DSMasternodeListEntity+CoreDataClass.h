//
//  DSMasternodeListEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSKeyManager.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSMerkleBlockEntity, DSQuorumEntryEntity, DSSimplifiedMasternodeEntryEntity, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity : NSManagedObject

- (DMasternodeList *)masternodeListWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

//- (DMasternodeList *)masternodeListWithSimplifiedMasternodeEntryPool:(DMasternodeEntryMap *)simplifiedMasternodeEntries
//                                                    quorumEntryPool:(DLLMQMap *)quorumEntries
//                                              withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeListEntity+CoreDataProperties.h"
