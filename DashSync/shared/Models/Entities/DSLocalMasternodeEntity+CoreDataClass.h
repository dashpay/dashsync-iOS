//
//  DSLocalMasternodeEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/3/19.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSProviderRegistrationTransactionEntity, DSProviderUpdateRegistrarTransactionEntity, DSProviderUpdateRevocationTransactionEntity, DSProviderUpdateServiceTransactionEntity, DSLocalMasternode, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternodeEntity : NSManagedObject

- (DSLocalMasternode *_Nullable)loadLocalMasternode;

- (void)setAttributesFromLocalMasternode:(DSLocalMasternode *)localMasternode;

+ (NSDictionary<NSData *, DSLocalMasternodeEntity *> *)findLocalMasternodesAndIndexForProviderRegistrationHashes:(NSSet<NSData *> *)providerRegistrationHashes inContext:(NSManagedObjectContext *)context;

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

+ (void)loadLocalMasternodesInContext:(NSManagedObjectContext *)context
                        onChainEntity:(DSChainEntity *)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSLocalMasternodeEntity+CoreDataProperties.h"
