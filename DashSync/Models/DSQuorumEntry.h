//
//  DSQuorumEntry.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

typedef NS_ENUM(uint16_t, DSLLMQType) {
    DSLLMQType_50_60 = 1, //every 24 blocks
    DSLLMQType_400_60 = 2, //288 blocks
    DSLLMQType_400_85 = 3, //576 blocks
    DSLLMQType_5_60 = 100 //24 blocks
};

@class DSChain,DSMasternodeList,DSQuorumEntryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntry : NSObject

@property (nonatomic, readonly) uint16_t version;
@property (nonatomic, readonly) UInt256 quorumHash;
@property (nonatomic, readonly) UInt256 llmqQuorumHash;
@property (nonatomic, readonly) UInt384 quorumPublicKey;
@property (nonatomic, readonly) UInt768 quorumThresholdSignature;
@property (nonatomic, readonly) UInt256 quorumVerificationVectorHash;
@property (nonatomic, readonly) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, readonly) int32_t signersCount;
@property (nonatomic, readonly) int16_t llmqType;
@property (nonatomic, readonly) int32_t validMembersCount;
@property (nonatomic, readonly) NSData * signersBitset;
@property (nonatomic, readonly) NSData * validMembersBitset;
@property (nonatomic, readonly) uint32_t length;
@property (nonatomic, readonly, getter=toData) NSData * data;
@property (nonatomic, readonly) UInt256 commitmentHash;
@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) BOOL verified;
@property (nonatomic, readonly) DSQuorumEntryEntity * matchingQuorumEntryEntity;

+(instancetype)potentialQuorumEntryWithData:(NSData*)data dataOffset:(uint32_t)dataOffset onChain:(DSChain*)chain;

-(BOOL)validateWithMasternodeList:(DSMasternodeList*)dictionary;

-(instancetype)initWithVersion:(uint16_t)version quorumHash:(UInt256)quorumHash quorumPublicKey:(UInt384)quorumPublicKey commitmentHash:(UInt256)commitmentHash verified:(BOOL)verified onChain:(DSChain*)chain;

-(UInt256)orderingHashForRequestID:(UInt256)requestID;

@end

NS_ASSUME_NONNULL_END
