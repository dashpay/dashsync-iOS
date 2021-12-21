//
//  DSQuorumEntry.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "BigIntTypes.h"
#import "DSChain.h"
#import "mndiff.h"
#import <Foundation/Foundation.h>

@class DSChain, DSMasternodeList, DSQuorumEntryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntry : NSObject <NSCopying>

@property (nonatomic, readonly) uint16_t version;
@property (nonatomic, readonly) UInt256 quorumHash;
@property (nonatomic, readonly) UInt256 llmqQuorumHash;
@property (nonatomic, readonly) UInt384 quorumPublicKey;
@property (nonatomic, readonly) UInt768 quorumThresholdSignature;
@property (nonatomic, readonly) UInt256 quorumVerificationVectorHash;
@property (nonatomic, readonly) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, readonly) int32_t signersCount;
@property (nonatomic, readonly) DSLLMQType llmqType;
@property (nonatomic, readonly) int32_t validMembersCount;
@property (nonatomic, readonly) NSData *signersBitset;
@property (nonatomic, readonly) NSData *validMembersBitset;
@property (nonatomic, readonly) uint32_t length;
@property (nonatomic, readonly, getter=toData) NSData *data;
@property (nonatomic, readonly) UInt256 quorumEntryHash;
@property (nonatomic, readonly) UInt256 commitmentHash;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) BOOL verified;
@property (nonatomic, assign) BOOL saved;

- (instancetype)initWithVersion:(uint16_t)version type:(DSLLMQType)type quorumHash:(UInt256)quorumHash quorumPublicKey:(UInt384)quorumPublicKey quorumEntryHash:(UInt256)commitmentHash verified:(BOOL)verified onChain:(DSChain *)chain;
- (instancetype)initWithEntry:(QuorumEntry *)entry onChain:(DSChain *)chain;

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList;
- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList blockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (DSQuorumEntryEntity *)matchingQuorumEntryEntityInContext:(NSManagedObjectContext *)context;

- (UInt256)orderingHashForRequestID:(UInt256)requestID forQuorumType:(DSLLMQType)quorumType;

+ (uint32_t)quorumSizeForType:(DSLLMQType)type;

@end

NS_ASSUME_NONNULL_END
