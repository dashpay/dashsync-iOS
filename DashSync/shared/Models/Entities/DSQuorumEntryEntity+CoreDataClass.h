//
//  DSQuorumEntryEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSKeyManager.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSChainEntity, DSInstantSendLockEntity, DSMasternodeListEntity, DSMerkleBlockEntity, DSQuorumCommitmentTransactionEntity, DSChain, DSChainLockEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity : NSManagedObject

@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
//@property (nonatomic, readonly) DSQuorumEntry *quorumEntry;

+ (instancetype _Nullable)quorumEntryEntityFromPotentialQuorumEntry:(DLLMQEntry *)potentialQuorumEntry
                                                          inContext:(NSManagedObjectContext *)context
                                                            onChain:(DSChain *)chain;
+ (instancetype _Nullable)quorumEntryEntityFromPotentialQuorumEntryForMerging:(DLLMQEntry *)potentialQuorumEntry
                                                                    inContext:(NSManagedObjectContext *)context
                                                                      onChain:(DSChain *)chain;

- (void)setAttributesFromPotentialQuorumEntry:(DLLMQEntry *)potentialQuorumEntry
                                      onBlock:(DSMerkleBlockEntity *_Nullable)block
                                      onChain:(DSChain *)chain;

//+ (void)deleteHavingQuorumHashes:(NSArray *)quorumHashes onChainEntity:(DSChainEntity *)chainEntity;
//+ (DSQuorumEntryEntity *_Nullable)quorumEntryForHash:(NSData *)quorumEntryHash onChainEntity:(DSChainEntity *)chainEntity;

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

- (UInt256)orderingHashForRequestID:(UInt256)requestID;

@end

NS_ASSUME_NONNULL_END

#import "DSQuorumEntryEntity+CoreDataProperties.h"
