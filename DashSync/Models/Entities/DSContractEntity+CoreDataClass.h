//
//  DSContractEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSBlockchainIdentityEntity, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSContractEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSContractEntity+CoreDataProperties.h"
