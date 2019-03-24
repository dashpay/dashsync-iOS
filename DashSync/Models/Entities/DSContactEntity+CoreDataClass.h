//
//  DSContactEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSAccountEntity, DSBlockchainUserRegistrationTransactionEntity, DSContactRequestEntity, DSDerivationPathEntity, DSTransitionEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSContactEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSContactEntity+CoreDataProperties.h"
