//
//  DSBlockchainIdentityEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSBlockchainIdentityKeyPathEntity, DSChainEntity, DSContactEntity, DSCreditFundingTransactionEntity, DSTransitionEntity, DSBlockchainIdentityUsernameEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"
