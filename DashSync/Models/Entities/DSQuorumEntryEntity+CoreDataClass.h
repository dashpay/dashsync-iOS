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

@class DSChainEntity, DSQuorumCommitmentTransactionEntity,DSChain,DSPotentialQuorumEntry,DSMerkleBlockEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity : NSManagedObject

@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;

+ (instancetype)quorumEntryEntityFromPotentialQuorumEntry:(DSPotentialQuorumEntry *)potentialQuorumEntry;

- (void)setAttributesFromPotentialQuorumEntry:(DSPotentialQuorumEntry *)potentialQuorumEntry onBlock:(DSMerkleBlockEntity *)block;

+ (void)deleteHavingQuorumHashes:(NSArray*)quorumHashes onChain:(DSChainEntity*)chainEntity;
+ (DSQuorumEntryEntity* _Nullable)quorumEntryForHash:(NSData*)quorumEntryHash onChain:(DSChainEntity* _Nonnull)chainEntity;

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSQuorumEntryEntity+CoreDataProperties.h"
