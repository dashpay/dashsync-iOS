//
//  DSQuorumEntryEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BigIntTypes.h"

@class DSChainEntity, DSInstantSendLockEntity, DSMasternodeListEntity, DSMerkleBlockEntity, DSQuorumCommitmentTransactionEntity, DSChain, DSQuorumEntry, DSChainLockEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity : NSManagedObject

@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, readonly) DSQuorumEntry * quorumEntry;

+ (instancetype _Nullable)quorumEntryEntityFromPotentialQuorumEntry:(DSQuorumEntry *)potentialQuorumEntry inContext:(NSManagedObjectContext *)context;

- (void)setAttributesFromPotentialQuorumEntry:(DSQuorumEntry *)potentialQuorumEntry onBlock:(DSMerkleBlockEntity * _Nullable)block;

+ (void)deleteHavingQuorumHashes:(NSArray*)quorumHashes onChainEntity:(DSChainEntity*)chainEntity;
+ (DSQuorumEntryEntity* _Nullable)quorumEntryForHash:(NSData*)quorumEntryHash onChainEntity:(DSChainEntity*)chainEntity;

+ (void)deleteAllOnChainEntity:(DSChainEntity*)chainEntity;

- (UInt256)orderingHashForRequestID:(UInt256)requestID;

@end

NS_ASSUME_NONNULL_END

#import "DSQuorumEntryEntity+CoreDataProperties.h"
