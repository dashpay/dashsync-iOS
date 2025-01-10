//
//  DSContractEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import "NSManagedObject+Sugar.h"

@class DSBlockchainIdentityEntity, DSChainEntity, DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSContractEntity : NSManagedObject

+ (instancetype)entityWithLocalContractIdentifier:(NSString *)identifier
                                          onChain:(DSChain *)chain
                                        inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "DSContractEntity+CoreDataProperties.h"
