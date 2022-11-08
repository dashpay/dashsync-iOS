//
//  DSMasternodeList.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//

#import "BigIntTypes.h"
#import "DSQuorumEntry.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

#define MASTERNODE_LIST_ADDED_NODES @"MASTERNODE_LIST_ADDED_NODES"
#define MASTERNODE_LIST_ADDED_VALIDITY @"MASTERNODE_LIST_ADDED_VALIDITY"
#define MASTERNODE_LIST_REMOVED_VALIDITY @"MASTERNODE_LIST_REMOVED_VALIDITY"
#define MASTERNODE_LIST_REMOVED_NODES @"MASTERNODE_LIST_REMOVED_NODES"

NS_ASSUME_NONNULL_BEGIN

@class DSSimplifiedMasternodeEntry, DSChain, DSQuorumEntry, DSPeer;

@interface DSMasternodeList : NSObject

@property (nonatomic, readonly) NSArray<DSSimplifiedMasternodeEntry *> *simplifiedMasternodeEntries;
@property (nonatomic, readonly) NSArray<NSData *> *providerTxOrderedHashes;
@property (nonatomic, readonly) NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *quorums;
@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) UInt256 masternodeMerkleRoot;
@property (nonatomic, readonly) UInt256 quorumMerkleRoot;
@property (nonatomic, readonly) NSUInteger quorumsCount;
@property (nonatomic, readonly) NSUInteger validQuorumsCount;
@property (nonatomic, readonly) uint64_t masternodeCount;
@property (nonatomic, readonly) uint64_t validMasternodeCount;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) NSArray *reversedRegistrationTransactionHashes;
@property (nonatomic, readonly) NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;

+ (instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntries:(NSArray<DSQuorumEntry *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain;
+ (instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain;

- (NSDictionary<NSData *, id> *)scoreDictionaryForQuorumModifier:(UInt256)quorumModifier atBlockHeight:(uint32_t)blockHeight;
- (NSArray *)scoresForQuorumModifier:(UInt256)quorumModifier atBlockHeight:(uint32_t)blockHeight;

- (NSUInteger)validQuorumsCountOfType:(DSLLMQType)type;
- (NSDictionary *)quorumsOfType:(DSLLMQType)type;
- (NSUInteger)quorumsCountOfType:(DSLLMQType)type;

- (NSArray<DSSimplifiedMasternodeEntry *> *)validMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount;

- (NSArray<DSSimplifiedMasternodeEntry *> *)allMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount blockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (NSArray<DSSimplifiedMasternodeEntry *> *)validMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount blockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (UInt256)calculateMasternodeMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (NSDictionary *)compare:(DSMasternodeList *)other;
- (NSDictionary *)compare:(DSMasternodeList *)other blockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (NSDictionary *)compareWithPrevious:(DSMasternodeList *)other;
- (NSDictionary *)compareWithPrevious:(DSMasternodeList *)other blockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (NSDictionary *)listOfChangedNodesComparedTo:(DSMasternodeList *)previous;
- (NSDictionary *)compare:(DSMasternodeList *)other usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs blockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (DSQuorumEntry *_Nullable)quorumEntryForLockRequestID:(UInt256)requestID ofQuorumType:(DSLLMQType)quorumType;
- (DSQuorumEntry *_Nullable)quorumEntryForPlatformWithQuorumHash:(UInt256)quorumHash;

- (NSArray<DSQuorumEntry *> *)quorumEntriesRankedForInstantSendRequestID:(UInt256)requestID;

- (NSArray<DSPeer *> *)peers:(uint32_t)peerCount withConnectivityNonce:(uint64_t)connectivityNonce;

- (UInt256)masternodeMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (NSArray<NSData *> *)hashesForMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (NSDictionary<NSData *, NSData *> *)hashDictionaryForMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (NSDictionary *)toDictionaryUsingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (DSSimplifiedMasternodeEntry *)masternodeForRegistrationHash:(UInt256)registrationHash;

- (DSMasternodeList *)mergedWithMasternodeList:(DSMasternodeList *)masternodeList;
- (BOOL)hasUnverifiedNonRotatedQuorums;
- (BOOL)hasUnverifiedRotatedQuorums;
- (void)saveToJsonFile:(NSString *)fileName;
- (void)saveToJsonFileExtended:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
