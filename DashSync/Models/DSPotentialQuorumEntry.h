//
//  DSPotentialQuorumEntry.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSPotentialQuorumEntry : NSObject

@property (nonatomic, readonly) UInt256 quorumHash;
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

+(instancetype)potentialQuorumEntryWithData:(NSData*)data dataOffset:(uint32_t)dataOffset onChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
