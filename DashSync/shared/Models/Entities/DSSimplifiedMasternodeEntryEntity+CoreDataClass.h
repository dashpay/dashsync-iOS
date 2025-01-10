//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSChain.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSAddressEntity, DSChainEntity, DSGovernanceVoteEntity, DSLocalMasternodeEntity, DSMasternodeListEntity, DSTransactionLockVoteEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSSimplifiedMasternodeEntryEntity : NSManagedObject

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *_Nonnull)simplifiedMasternodeEntry
                                        atBlockHeight:(uint32_t)blockHeight
                                              onChain:(DSChain *)chain;
- (void)updateAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *_Nonnull)simplifiedMasternodeEntry
                                        atBlockHeight:(uint32_t)blockHeight
                               knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownOperatorAddresses
                                 knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownVotingAddresses
                                platformNodeAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)platformNodeAddresses
                                     localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *_Nullable)localMasternodes
                                              onChain:(DSChain *)chain;
- (void)setAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *)simplifiedMasternodeEntry
                                     atBlockHeight:(uint32_t)blockHeight
                            knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownOperatorAddresses
                              knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)knownVotingAddresses
                             platformNodeAddresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)platformNodeAddresses
                                  localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *_Nullable)localMasternodes
                                           onChain:(DSChain *)chain
                                     onChainEntity:(DSChainEntity *_Nullable)chainEntity;
- (void)setAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *_Nonnull)simplifiedMasternodeEntry
                                     atBlockHeight:(uint32_t)blockHeight
                                           onChain:(DSChain *)chain
                                     onChainEntity:(DSChainEntity *_Nullable)chainEntity;
+ (void)deleteHavingProviderTransactionHashes:(NSArray *)providerTransactionHashes
                                onChainEntity:(DSChainEntity *_Nonnull)chainEntity;
+ (DSSimplifiedMasternodeEntryEntity *_Nullable)simplifiedMasternodeEntryForHash:(NSData *)simplifiedMasternodeEntryHash
                                                                   onChainEntity:(DSChainEntity *_Nonnull)chainEntity;
+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash
                                                                                         onChainEntity:(DSChainEntity *_Nonnull)chainEntity;

//- (DMasternodeEntry *_Nullable)simplifiedMasternodeEntry;
- (DMasternodeEntry *_Nullable)simplifiedMasternodeEntryWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
