//
//  DSMasternodeListEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSMerkleBlockEntity, DSSimplifiedMasternodeEntryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeListEntity+CoreDataProperties.h"
