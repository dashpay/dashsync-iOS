//
//  DSBlockchainIdentityKeyPathEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSBlockchainIdentityEntity, DSBlockchainIdentityRegistrationTransitionEntity, DSBlockchainIdentityUpdateTransitionEntity, DSDerivationPathEntity, NSObject;

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityKeyPathEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h"
