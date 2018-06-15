//
//  DSGovernanceVoteEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSGovernanceObjectEntity, DSGovernanceVoteHashEntity, DSMasternodeBroadcastEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceVoteEntity+CoreDataProperties.h"
