//
//  DSMasternodeList.m
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//

#import "DSMasternodeList.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChain.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSQuorumEntry.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

// from https://en.bitcoin.it/wiki/Protocol_specification#Merkle_Trees
// Merkle trees are binary trees of hashes. Merkle trees in bitcoin use a double SHA-256, the SHA-256 hash of the
// SHA-256 hash of something. If, when forming a row in the tree (other than the root of the tree), it would have an odd
// number of elements, the final double-hash is duplicated to ensure that the row has an even number of hashes. First
// form the bottom row of the tree with the ordered double-SHA-256 hashes of the byte streams of the transactions in the
// block. Then the row above it consists of half that number of hashes. Each entry is the double-SHA-256 of the 64-byte
// concatenation of the corresponding two hashes below it in the tree. This procedure repeats recursively until we reach
// a row consisting of just a single double-hash. This is the merkle root of the tree.
//
// from https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki#Partial_Merkle_branch_format
// The encoding works as follows: we traverse the tree in depth-first order, storing a bit for each traversed node,
// signifying whether the node is the parent of at least one matched leaf txid (or a matched txid itself). In case we
// are at the leaf level, or this bit is 0, its merkle node hash is stored, and its children are not explored further.
// Otherwise, no hash is stored, but we recurse into both (or the only) child branch. During decoding, the same
// depth-first traversal is performed, consuming bits and hashes as they written during encoding.
//
// example tree with three transactions, where only tx2 is matched by the bloom filter:
//
//     merkleRoot
//      /     \
//    m1       m2
//   /  \     /  \
// tx1  tx2 tx3  tx3
//
// flag bits (little endian): 00001011 [merkleRoot = 1, m1 = 1, tx1 = 0, tx2 = 1, m2 = 0, byte padding = 000]
// hashes: [tx1, tx2, m2]

inline static int ceil_log2(int x)
{
    int r = (x & (x - 1)) ? 1 : 0;
    
    while ((x >>= 1) != 0) r++;
    return r;
}

@interface DSMasternodeList()

@property (nonatomic,strong) NSMutableDictionary<NSData*,DSSimplifiedMasternodeEntry*> *mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;
@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,assign) UInt256 blockHash;
@property (nonatomic,assign) UInt256 masternodeMerkleRoot;
@property (nonatomic,assign) UInt256 quorumMerkleRoot;
@property (nonatomic,assign) uint32_t knownHeight;
@property (nonatomic,strong) NSMutableDictionary <NSNumber*,NSMutableDictionary<NSData*,DSQuorumEntry*>*> * mQuorums;

@end

@implementation DSMasternodeList

+(instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries quorumEntries:(NSArray<DSQuorumEntry*>*)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain*)chain {
    NSMutableDictionary * masternodeDictionary = [NSMutableDictionary dictionary];
    for (DSSimplifiedMasternodeEntry * entry in simplifiedMasternodeEntries) {
        [masternodeDictionary setObject:entry forKey:uint256_data(entry.providerRegistrationTransactionHash).reverse];
    }
    NSMutableDictionary * quorumDictionary = [NSMutableDictionary dictionary];
    for (DSQuorumEntry * entry in quorumEntries) {
        NSMutableDictionary * quorumDictionaryForType = [quorumDictionary objectForKey:@(entry.llmqType)];
        if (!quorumDictionaryForType) {
            quorumDictionaryForType = [NSMutableDictionary dictionary];
            [quorumDictionary setObject:quorumDictionaryForType forKey:@(entry.llmqType)];
        }
        [quorumDictionaryForType setObject:entry forKey:uint256_data(entry.quorumHash)];
    }
    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:masternodeDictionary quorumEntriesDictionary:quorumDictionary atBlockHash:blockHash atBlockHeight:blockHeight withMasternodeMerkleRootHash:masternodeMerkleRootHash withQuorumMerkleRootHash:quorumMerkleRootHash onChain:chain];
}

+(instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber*,NSDictionary<NSData*,DSQuorumEntry*>*>*)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain*)chain {
    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:simplifiedMasternodeEntries quorumEntriesDictionary:quorumEntries  atBlockHash:blockHash atBlockHeight:blockHeight withMasternodeMerkleRootHash:masternodeMerkleRootHash withQuorumMerkleRootHash:quorumMerkleRootHash onChain:chain];
}

-(instancetype)initWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber*,NSDictionary<NSData*,DSQuorumEntry*>*>*)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    self.masternodeMerkleRoot = masternodeMerkleRootHash;
    self.quorumMerkleRoot = quorumMerkleRootHash;
    self.knownHeight = blockHeight;
    self.chain = chain;
    self.blockHash = blockHash;
    self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash = [simplifiedMasternodeEntries mutableCopy];
    self.mQuorums = [quorumEntries mutableCopy];
    return self;
}

#define LOG_DIFFS_BETWEEN_MASTERNODE_LISTS 1

+(instancetype)masternodeListAtBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight fromBaseMasternodeList:(DSMasternodeList*)baseMasternodeList addedMasternodes:(NSDictionary*)addedMasternodes removedMasternodeHashes:(NSArray*)removedMasternodeHashes modifiedMasternodes:(NSDictionary*)modifiedMasternodes addedQuorums:(NSDictionary*)addedQuorums removedQuorumHashesByType:(NSDictionary*)removedQuorumHashesByType onChain:(DSChain*)chain {
    NSMutableDictionary * tentativeMasternodeList = baseMasternodeList?[baseMasternodeList.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash mutableCopy]:[NSMutableDictionary dictionary];
    
    [tentativeMasternodeList removeObjectsForKeys:removedMasternodeHashes];
    [tentativeMasternodeList addEntriesFromDictionary:addedMasternodes];
    
#if LOG_DIFFS_BETWEEN_MASTERNODE_LISTS
    DSDLog(@"MNDiff: %lu added, %lu removed, %lu modified ",(unsigned long)addedMasternodes.count,(unsigned long)removedMasternodeHashes.count,(unsigned long)modifiedMasternodes.count);
#endif
    
    for (NSData * data in modifiedMasternodes) {
        DSSimplifiedMasternodeEntry * oldMasternodeEntry = tentativeMasternodeList[data];
        //the masternode has changed
        DSSimplifiedMasternodeEntry * modifiedMasternode = modifiedMasternodes[data];
        [modifiedMasternode keepInfoOfPreviousEntryVersion:oldMasternodeEntry atBlockHash:blockHash];
        [tentativeMasternodeList setObject:modifiedMasternode forKey:data];
    }
    
    NSMutableDictionary * tentativeQuorumList = baseMasternodeList?[baseMasternodeList.mQuorums mutableCopy]:[NSMutableDictionary dictionary];
    
    //we need to do a deep mutable copy
    for (NSNumber * quorumType in [tentativeQuorumList copy]) {
        tentativeQuorumList[quorumType] = [tentativeQuorumList[quorumType] mutableCopy];
    }
    
    for (NSNumber * quorumType in addedQuorums) {
        if (![tentativeQuorumList objectForKey:quorumType]) {
            [tentativeQuorumList setObject:[NSMutableDictionary dictionary] forKey:quorumType];
        }
    }
    
    for (NSNumber * quorumType in tentativeQuorumList) {
        NSMutableDictionary * quorumsOfType = tentativeQuorumList[quorumType];
        if (removedQuorumHashesByType[quorumType]) {
            [quorumsOfType removeObjectsForKeys:removedQuorumHashesByType[quorumType]];
        }
        if (addedQuorums[quorumType]) {
            [quorumsOfType addEntriesFromDictionary:addedQuorums[quorumType]];
        }
    }
    
    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:tentativeMasternodeList quorumEntriesDictionary:tentativeQuorumList atBlockHash:blockHash atBlockHeight:blockHeight withMasternodeMerkleRootHash:UINT256_ZERO withQuorumMerkleRootHash:UINT256_ZERO onChain:chain];
}

-(UInt256)masternodeMerkleRoot {
    if (uint256_is_zero(_masternodeMerkleRoot)) {
        self.masternodeMerkleRoot = [self calculateMasternodeMerkleRoot];
    }
    return _masternodeMerkleRoot;
}

-(NSArray*)providerTxOrderedHashes {
    NSArray * proTxHashes = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allKeys];
    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
    }];
    return proTxHashes;
}

-(NSArray*)hashesForMerkleRoot {
    
    NSArray * proTxHashes = [self providerTxOrderedHashes];
    
    NSMutableArray * simplifiedMasternodeListByRegistrationTransactionHashHashes = [NSMutableArray array];
    for (NSData * proTxHash in proTxHashes) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:proTxHash];
        [simplifiedMasternodeListByRegistrationTransactionHashHashes addObject:[NSData dataWithUInt256:[simplifiedMasternodeEntry simplifiedMasternodeEntryHashAtBlockHash:self.blockHash]]];
    }
    return simplifiedMasternodeListByRegistrationTransactionHashHashes;
}

-(UInt256)calculateMasternodeMerkleRoot {
    return [[NSData merkleRootFromHashes:[self hashesForMerkleRoot]] UInt256];
}

-(UInt256)quorumMerkleRoot {
    if (uint256_is_zero(_quorumMerkleRoot)) {
        NSMutableArray * llmqCommitmentHashes = [NSMutableArray array];
        for (NSNumber * number in self.mQuorums) {
            for (DSQuorumEntry * quorumEntry in [self.mQuorums[number] allValues]) {
                [llmqCommitmentHashes addObject:uint256_data(quorumEntry.quorumEntryHash)];
            }
        }
        NSArray * sortedLlmqHashes = [llmqCommitmentHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            UInt256 hash1 = uint256_reverse([(NSData*)obj1 UInt256]);
            UInt256 hash2 = uint256_reverse([(NSData*)obj2 UInt256]);
            return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
        }];
    
        self.quorumMerkleRoot = [[NSData merkleRootFromHashes:sortedLlmqHashes] UInt256];
    }
    return _quorumMerkleRoot;
}


-(DSMutableOrderedDataKeyDictionary*)calculateScores:(UInt256)modifier {
    NSMutableDictionary <NSData*,id>* scores = [NSMutableDictionary dictionary];
    
    for (NSData * registrationTransactionHash in self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
        if (uint256_is_zero(simplifiedMasternodeEntry.confirmedHash)) {
            continue;
        }
        NSMutableData * data = [NSMutableData data];
        [data appendData:[NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHashHashedWithProviderRegistrationTransactionHash].reverse];
        [data appendData:[NSData dataWithUInt256:modifier].reverse];
        UInt256 score = data.SHA256;
        scores[[NSData dataWithUInt256:score]] = simplifiedMasternodeEntry;
    }
    DSMutableOrderedDataKeyDictionary * rankedScores = [[DSMutableOrderedDataKeyDictionary alloc] initWithMutableDictionary:scores keyAscending:YES];
    [rankedScores addIndex:@"providerRegistrationTransactionHash"];
    return rankedScores;
}

-(UInt256)masternodeScore:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry modifier:(UInt256)modifier {
    NSParameterAssert(simplifiedMasternodeEntry);
    
    if (uint256_is_zero(simplifiedMasternodeEntry.confirmedHash)) {
        return UINT256_ZERO;
    }
    NSMutableData * data = [NSMutableData data];
    [data appendData:[NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHashHashedWithProviderRegistrationTransactionHash]];
    [data appendData:[NSData dataWithUInt256:modifier]];
    return data.SHA256;
}

-(NSDictionary <NSData*,id>*)scoreDictionaryForQuorumModifier:(UInt256)quorumModifier {
    NSMutableDictionary <NSData*,id>* scoreDictionary = [NSMutableDictionary dictionary];
    for (NSData * registrationTransactionHash in self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
        UInt256 score = [self masternodeScore:simplifiedMasternodeEntry modifier:quorumModifier];
        if (uint256_is_zero(score)) continue;
        scoreDictionary[[NSData dataWithUInt256:score]] = simplifiedMasternodeEntry;
    }
    return scoreDictionary;
}

-(NSArray*)scoresForQuorumModifier:(UInt256)quorumModifier {
    NSDictionary <NSData*,id>* scoreDictionary = [self scoreDictionaryForQuorumModifier:quorumModifier];
    NSArray * scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedAscending:NSOrderedDescending;
    }];
    return scores;
}

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount {
    NSDictionary <NSData*,id>* scoreDictionary = [self scoreDictionaryForQuorumModifier:quorumModifier];
    NSArray * scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedAscending:NSOrderedDescending;
    }];
    NSMutableArray * masternodes = [NSMutableArray array];
    NSUInteger maxCount = MIN(quorumCount, self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count);
    DSMerkleBlock * block = [self.chain blockForBlockHash:self.blockHash];
    for (int i = 0; i<maxCount;i++) {
        NSData * score = [scores objectAtIndex:i];
        DSSimplifiedMasternodeEntry * masternode = scoreDictionary[score];
        if ([masternode isValidAtBlock:block]) {
            [masternodes addObject:masternode];
        } else {
            maxCount++;
            if (maxCount > self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count) break;
        }
    }
    return masternodes;
}

-(NSArray*)simplifiedMasternodeEntries {
    return self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allValues;
}

-(NSArray*)reversedRegistrationTransactionHashes {
    return self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allKeys;
}

-(uint64_t)masternodeCount {
    return [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash count];
}

-(NSUInteger)quorumsCount {
    NSUInteger count = 0;
    for (NSNumber * type in self.mQuorums) {
        count += self.mQuorums[type].count;
    }
    return count;
}

-(NSUInteger)quorumsCountOfType:(DSLLMQType)type  {
    return self.mQuorums[@(type)].count;
}

-(NSUInteger)validQuorumsCount {
    NSUInteger count = 0;
    for (NSNumber * type in self.mQuorums) {
        for (NSData * quorumHashData in self.mQuorums[type]) {
            DSQuorumEntry * quorum = self.mQuorums[type][quorumHashData];
            if (quorum.verified) count++;
        }
    }
    return count;
}

-(NSUInteger)validQuorumsCountOfType:(DSLLMQType)type {
    NSUInteger count = 0;
    for (NSData * quorumHashData in self.mQuorums[@(type)]) {
        DSQuorumEntry * quorum = self.mQuorums[@(type)][quorumHashData];
        if (quorum.verified) count++;
    }
    return count;
}


-(NSDictionary*)quorums {
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
    for (NSNumber * number in self.mQuorums) {
        [dictionary setObject:[[self.mQuorums objectForKey:number] copy] forKey:number];
    }
    return [dictionary copy];
}

-(NSDictionary*)simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash {
    return [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash copy];
}

-(uint32_t)height {
    if (!self.knownHeight || self.knownHeight == UINT32_MAX) {
        self.knownHeight = [self.chain heightForBlockHash:self.blockHash];
    }
    return self.knownHeight;
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch :(NSData*)simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :(NSData*)flags
{
    if ((*flagIdx)/8 >= flags.length || (*hashIdx + 1)*sizeof(UInt256) > simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == ceil_log2((int)_mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count)) {
        UInt256 hash = [simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes hashAtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :flags];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :flags];
    
    return branch(left, right);
}

-(BOOL)validateQuorumsWithMasternodeLists:(NSDictionary*)masternodeLists {
    for (DSQuorumEntry * quorum in self.quorums) {
        BOOL verified = quorum.verified;
        if (!verified) {
            DSMasternodeList * quorumMasternodeList = [masternodeLists objectForKey:uint256_data(quorum.quorumHash)];
            BOOL valid = [quorum validateWithMasternodeList:quorumMasternodeList];
            if (!valid) return FALSE;
        }
    }
    return TRUE;
}

-(NSString*)description {
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" {%u}",self.height]];
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%u}",self.height]];
}

-(NSDictionary*)compareWithPrevious:(DSMasternodeList*)other {
    return [self compare:other usingOurString:@"current" usingTheirString:@"previous"];
}


-(NSDictionary*)compare:(DSMasternodeList*)other {
    return [self compare:other usingOurString:@"ours" usingTheirString:@"theirs"];
}

-(NSDictionary*)compare:(DSMasternodeList*)other usingOurString:(NSString*)ours usingTheirString:(NSString*)theirs {
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
    for (NSData * data in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
        DSSimplifiedMasternodeEntry * ourEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
        DSSimplifiedMasternodeEntry * theirEntry = other.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
        if (ourEntry && theirEntry) {
            NSDictionary * entryComparison = [ourEntry compare:theirEntry ourBlockHash:self.blockHash theirBlockHash:other.blockHash usingOurString:ours usingTheirString:theirs];
            if (entryComparison.count) {
                [dictionary setObject:entryComparison forKey:data];
            }
        } else if (ourEntry) {
            [dictionary setObject:@{@"absent":uint256_hex(ourEntry.providerRegistrationTransactionHash)} forKey:data];
        }
    }
    return dictionary;
}

@end
