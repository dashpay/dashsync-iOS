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

@property (nonatomic,strong) NSMutableDictionary<NSData*,DSSimplifiedMasternodeEntry*> *simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;
@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,assign) UInt256 blockHash;

@end

@implementation DSMasternodeList

+(instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries atBlockHash:(UInt256)blockHash onChain:(DSChain*)chain {
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];
    for (DSSimplifiedMasternodeEntry * entry in simplifiedMasternodeEntries) {
        [dictionary setObject:entry forKey:uint256_data(entry.providerRegistrationTransactionHash).reverse];
    }
    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:dictionary atBlockHash:blockHash onChain:chain];
}

+(instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries atBlockHash:(UInt256)blockHash onChain:(DSChain*)chain {
    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:simplifiedMasternodeEntries atBlockHash:blockHash onChain:chain];
}

-(instancetype)initWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries atBlockHash:(UInt256)blockHash onChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    self.chain = chain;
    self.blockHash = blockHash;
    self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash = [simplifiedMasternodeEntries mutableCopy];
    return self;
}


-(DSMutableOrderedDataKeyDictionary*)calculateScores:(UInt256)modifier {
    NSMutableDictionary <NSData*,id>* scores = [NSMutableDictionary dictionary];
    
    for (NSData * registrationTransactionHash in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
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

-(UInt256)masternodeScore:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry quorumHash:(UInt256)quorumHash {
    NSParameterAssert(simplifiedMasternodeEntry);
    
    if (uint256_is_zero(simplifiedMasternodeEntry.confirmedHash)) {
        return UINT256_ZERO;
    }
    NSMutableData * data = [NSMutableData data];
    [data appendData:[NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHashHashedWithProviderRegistrationTransactionHash]];
    [data appendData:[NSData dataWithUInt256:quorumHash]];
    return data.SHA256;
}

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount {
    NSMutableDictionary <NSData*,id>* scoreDictionary = [NSMutableDictionary dictionary];
    for (NSData * registrationTransactionHash in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
        UInt256 score = [self masternodeScore:simplifiedMasternodeEntry quorumHash:quorumHash];
        if (uint256_is_zero(score)) continue;
        scoreDictionary[[NSData dataWithUInt256:score]] = simplifiedMasternodeEntry;
    }
    NSArray * scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedAscending:NSOrderedDescending;
    }];
    NSMutableArray * masternodes = [NSMutableArray array];
    NSUInteger maxCount = MIN(quorumCount, self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count);
    for (int i = 0; i<maxCount;i++) {
        NSData * score = [scores objectAtIndex:i];
        DSSimplifiedMasternodeEntry * masternode = scoreDictionary[score];
        if (masternode.isValid) {
            [masternodes addObject:masternode];
        } else {
            maxCount++;
            if (maxCount > self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count) break;
        }
    }
    return masternodes;
}

-(NSArray*)simplifiedMasternodeEntries {
    return self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allValues;
}

-(NSArray*)reversedRegistrationTransactionHashes {
    return self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allKeys;
}

-(uint64_t)masternodeCount {
    return [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash count];
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch :(NSData*)simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :(NSData*)flags
{
    if ((*flagIdx)/8 >= flags.length || (*hashIdx + 1)*sizeof(UInt256) > simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == ceil_log2((int)_simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count)) {
        UInt256 hash = [simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes hashAtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :flags];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :flags];
    
    return branch(left, right);
}

@end
