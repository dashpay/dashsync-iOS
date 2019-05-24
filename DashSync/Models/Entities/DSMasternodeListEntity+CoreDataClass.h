//
//  DSMasternodeListEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSMerkleBlockEntity, DSQuorumEntryEntity, DSSimplifiedMasternodeEntryEntity,DSMasternodeList,DSSimplifiedMasternodeEntry,DSQuorumEntry;

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity : NSManagedObject

-(DSMasternodeList*)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary <NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary <NSData*,DSQuorumEntry*>*)quorumEntries;

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeListEntity+CoreDataProperties.h"
