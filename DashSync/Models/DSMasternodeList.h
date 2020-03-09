//
//  DSMasternodeList.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//

#import "BigIntTypes.h"
#import "DSQuorumEntry.h"
#import <Foundation/Foundation.h>

#define MASTERNODE_LIST_ADDED_NODES @"MASTERNODE_LIST_ADDED_NODES"
#define MASTERNODE_LIST_REMOVED_NODES @"MASTERNODE_LIST_REMOVED_NODES"

NS_ASSUME_NONNULL_BEGIN

@class DSSimplifiedMasternodeEntry, DSChain, DSQuorumEntry;

@interface DSMasternodeList : NSObject

@property (nonatomic, readonly) NSArray<DSSimplifiedMasternodeEntry *> *simplifiedMasternodeEntries;
@property (nonatomic, readonly) NSArray<NSData *> *providerTxOrderedHashes;
@property (nonatomic, readonly) NSArray<NSData *> *hashesForMerkleRoot;
@property (nonatomic, readonly) NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *quorums;
@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) UInt256 masternodeMerkleRoot;
@property (nonatomic, readonly) UInt256 quorumMerkleRoot;
@property (nonatomic, readonly) NSUInteger quorumsCount;
@property (nonatomic, readonly) NSUInteger validQuorumsCount;
@property (nonatomic, readonly) uint64_t masternodeCount;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) NSArray *reversedRegistrationTransactionHashes;
@property (nonatomic, readonly) NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;

+ (instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntries:(NSArray<DSQuorumEntry *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain;

+ (instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain;

+ (instancetype)masternodeListAtBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight fromBaseMasternodeList:(DSMasternodeList *)baseMasternodeList addedMasternodes:(NSDictionary *)addedMasternodes removedMasternodeHashes:(NSArray *)removedMasternodeHashes modifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums removedQuorumHashesByType:(NSDictionary *)removedQuorumHashesByType onChain:(DSChain *)chain;

- (NSDictionary<NSData *, id> *)scoreDictionaryForQuorumModifier:(UInt256)quorumModifier;

- (NSArray *)scoresForQuorumModifier:(UInt256)quorumModifier;

- (NSUInteger)validQuorumsCountOfType:(DSLLMQType)type;

- (NSDictionary *)quorumsOfType:(DSLLMQType)type;

- (NSUInteger)quorumsCountOfType:(DSLLMQType)type;

- (NSArray<DSSimplifiedMasternodeEntry *> *)masternodesForQuorumModifier:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount;

- (BOOL)validateQuorumsWithMasternodeLists:(NSDictionary *)masternodeLists;

- (UInt256)calculateMasternodeMerkleRoot;

- (NSDictionary *)compare:(DSMasternodeList *)other;

- (NSDictionary *)compareWithPrevious:(DSMasternodeList *)other;

- (NSDictionary *)listOfChangedNodesComparedTo:(DSMasternodeList *)previous;

- (NSDictionary *)compare:(DSMasternodeList *)other usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs;

- (DSQuorumEntry *)quorumEntryForInstantSendRequestID:(UInt256)requestID;

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID;

- (NSArray<DSQuorumEntry *> *)quorumEntriesRankedForInstantSendRequestID:(UInt256)requestID;

@end

NS_ASSUME_NONNULL_END
