//
//  DSLocalMasternodeEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/3/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSProviderRegistrationTransactionEntity, DSProviderUpdateRegistrarTransactionEntity, DSProviderUpdateRevocationTransactionEntity, DSProviderUpdateServiceTransactionEntity, DSSimplifiedMasternodeEntryEntity,DSLocalMasternode,DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternodeEntity : NSManagedObject

- (DSLocalMasternode* _Nullable)loadLocalMasternode;

- (void)setAttributesFromLocalMasternode:(DSLocalMasternode*)localMasternode;

+ (NSDictionary<NSData*,DSLocalMasternodeEntity*>*)findLocalMasternodesAndIndexForProviderRegistrationHashes:(NSSet<NSData*>*)providerRegistrationHashes;

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSLocalMasternodeEntity+CoreDataProperties.h"
