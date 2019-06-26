//
//  DSQuorumCommitmentTransaction.h
//  DashSync
//
//  Created by Sam Westrich on 4/24/19.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumCommitmentTransaction : DSTransaction

@property (nonatomic,assign) uint32_t quorumCommitmentHeight;
@property (nonatomic,assign) uint16_t llmqType;
@property (nonatomic,assign) uint16_t quorumCommitmentTransactionVersion;
@property (nonatomic,assign) UInt256 quorumHash;
@property (nonatomic,assign) uint16_t signersCount;
@property (nonatomic,strong) NSData * signersBitset;
@property (nonatomic,assign) uint16_t validMembersCount;
@property (nonatomic,strong) NSData * validMembersBitset;
@property (nonatomic,assign) UInt384 quorumPublicKey;
@property (nonatomic,assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic,assign) UInt768 quorumThresholdSignature;
@property (nonatomic,assign) UInt768 allCommitmentAggregatedSignature;

@end

NS_ASSUME_NONNULL_END
