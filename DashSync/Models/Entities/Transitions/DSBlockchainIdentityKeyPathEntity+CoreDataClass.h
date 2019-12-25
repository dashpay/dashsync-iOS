//
//  DSBlockchainIdentityKeyPathEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSBlockchainIdentityRegistrationTransitionEntity, DSBlockchainIdentityUpdateTransitionEntity, DSDerivationPathEntity, NSObject;

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityKeyPathEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h"
