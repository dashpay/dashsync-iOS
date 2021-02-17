//
//  DSContractEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSBlockchainIdentityEntity, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSContractEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSContractEntity+CoreDataProperties.h"
