//
//  DSGovernanceObjectEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DSGovernanceObject.h"

@class DSGovernanceObjectHashEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceObjectEntity : NSManagedObject

- (void)setAttributesFromGovernanceObject:(DSGovernanceObject *)governanceObject forHashEntity:(DSGovernanceObjectHashEntity*)hashEntity;
+ (NSUInteger)countForChain:(DSChainEntity* _Nonnull)chain;

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceObjectEntity+CoreDataProperties.h"
