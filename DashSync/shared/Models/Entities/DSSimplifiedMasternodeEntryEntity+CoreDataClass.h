//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "BigIntTypes.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSAddressEntity, DSChainEntity, DSGovernanceVoteEntity, DSLocalMasternodeEntity, DSMasternodeListEntity, DSTransactionLockVoteEntity, DSSimplifiedMasternodeEntry, DSMasternodeList;

NS_ASSUME_NONNULL_BEGIN

@interface DSSimplifiedMasternodeEntryEntity : NSManagedObject

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *_Nonnull)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight;
- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *_Nonnull)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *_Nullable)localMasternodes;
- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *_Nullable)localMasternodes onChainEntity:(DSChainEntity *_Nullable)chainEntity;
- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *_Nonnull)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight onChainEntity:(DSChainEntity *_Nullable)chainEntity;
+ (void)deleteHavingProviderTransactionHashes:(NSArray *)providerTransactionHashes onChainEntity:(DSChainEntity *_Nonnull)chainEntity;
+ (DSSimplifiedMasternodeEntryEntity *_Nullable)simplifiedMasternodeEntryForHash:(NSData *)simplifiedMasternodeEntryHash onChainEntity:(DSChainEntity *_Nonnull)chainEntity;
+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash onChainEntity:(DSChainEntity *_Nonnull)chainEntity;

- (DSSimplifiedMasternodeEntry *_Nullable)simplifiedMasternodeEntry;
- (DSSimplifiedMasternodeEntry *_Nullable)simplifiedMasternodeEntryWithBlockHeightLookup:(uint32_t (^_Nullable)(UInt256 blockHash))blockHeightLookup;
+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
