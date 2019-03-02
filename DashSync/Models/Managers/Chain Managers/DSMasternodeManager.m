//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSMasternodeManager.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataProperties.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSPeer.h"
#import "NSData+Dash.h"
#import "DSPeerManager.h"
#import "DSTransactionFactory.h"
#import "NSMutableData+Dash.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSMerkleBlock.h"
#import "DSChainManager+Protected.h"
#import "DSPeerManager+Protected.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "DSLocalMasternode+Protected.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSProviderRegistrationTransaction.h"

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

#define REQUEST_MASTERNODE_BROADCAST_COUNT 500
#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@",peer.chain.uniqueID,FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 5


@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,assign) UInt256 baseBlockHash;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSSimplifiedMasternodeEntry*> *simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSLocalMasternode*> *localMasternodesDictionaryByRegistrationTransactionHash;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash = [NSMutableDictionary dictionary];
    _localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    self.baseBlockHash = chain.masternodeBaseBlockHash;
    DSDLog(@"Setting base block hash to %@",[NSData dataWithUInt256:self.baseBlockHash].hexString);
    return self;
}

-(void)setUp {
    [self loadSimplifiedMasternodeEntries:NSUIntegerMax];
    [self loadLocalMasternodes];
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}

// MARK: - Masternode List Sync

-(void)getMasternodeList {
    if (!uint256_eq(self.baseBlockHash, self.chain.lastBlock.blockHash)) {
        [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:self.baseBlockHash forBlockHash:self.chain.lastBlock.blockHash];
    }
}

-(void)wipeMasternodeInfo {
    [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash removeAllObjects];
    [self.localMasternodesDictionaryByRegistrationTransactionHash removeAllObjects];
    self.baseBlockHash = UINT256_ZERO;
}

-(void)loadSimplifiedMasternodeEntries:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSSimplifiedMasternodeEntryEntity fetchRequest] copy];
    if (count && count != NSUIntegerMax) {
        [fetchRequest setFetchLimit:count];
    }
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",self.chain.chainEntity]];
    NSArray * simplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity fetchObjects:fetchRequest];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in simplifiedMasternodeEntryEntities) {
        [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash setObject:simplifiedMasternodeEntryEntity.simplifiedMasternodeEntry forKey:simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash.reverse];
    }
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


//-(void)verify {
//    NSMutableData * simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes = [NSMutableData data];
//    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in self.simplifiedMasternodeListDictionaryByRegistrationTransactionHash) {
//        [simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes appendUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
//    }
//    NSMutableData *d = [NSMutableData data];
//    UInt256 merkleRoot, t = UINT256_ZERO;
//    int hashIdx = 0, flagIdx = 0;
//    NSValue *root = [self _walk:&hashIdx :&flagIdx :0 :^id (id hash, BOOL flag) {
//        return hash;
//    } :^id (id left, id right) {
//        UInt256 l, r;
//
//        if (! right) right = left; // if right branch is missing, duplicate left branch
//        [left getValue:&l];
//        [right getValue:&r];
//        d.length = 0;
//        [d appendBytes:&l length:sizeof(l)];
//        [d appendBytes:&r length:sizeof(r)];
//        return uint256_obj(d.SHA256_2);
//    } :simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes :flags];
//
//    [root getValue:&merkleRoot];
//}

#define LOG_MASTERNODE_DIFF 1

-(void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData*)message {
#if LOG_MASTERNODE_DIFF
    NSUInteger chunkSize = 4096;
    NSUInteger chunks = ceilf(((float)message.length)/chunkSize);
    for (int i = 0;i<chunks;) {
        NSInteger lengthLeft = message.length - i*chunkSize;
        if (lengthLeft < 0) continue;
        DSDLog(@"Logging masternode DIFF message chunk %d %@",i,[message subdataWithRange:NSMakeRange(i*chunkSize, MIN(lengthLeft, chunkSize))].hexString);
        i++;
    }
    DSDLog(@"Logging masternode DIFF message hash %@",[NSData dataWithUInt256:message.SHA256].hexString);
#endif
    
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    
    if (length - offset < 32) return;
    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    if (!uint256_eq(baseBlockHash, self.baseBlockHash)) return;
    
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    DSDLog(@"baseBlockHash %@ (%@) blockHash %@ (%@)",[NSData dataWithUInt256:baseBlockHash].hexString,[NSData dataWithUInt256:baseBlockHash].reverse.hexString,[NSData dataWithUInt256:blockHash].hexString,[NSData dataWithUInt256:blockHash].reverse.hexString);
    
    if (length - offset < 4) return;
    uint32_t totalTransactions = [message UInt32AtOffset:offset];
    offset += 4;
    
    if (length - offset < 1) return;
    
    NSNumber * merkleHashCountLength;
    NSUInteger merkleHashCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleHashCountLength]*sizeof(UInt256);
    offset += [merkleHashCountLength unsignedLongValue];
    
    
    NSData * merkleHashes = [message subdataWithRange:NSMakeRange(offset, merkleHashCount)];
    offset += merkleHashCount;
    
    NSNumber * merkleFlagCountLength;
    NSUInteger merkleFlagCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleFlagCountLength];
    offset += [merkleFlagCountLength unsignedLongValue];
    
    
    NSData * merkleFlags = [message subdataWithRange:NSMakeRange(offset, merkleFlagCount)];
    offset += merkleFlagCount;
    
    __unused NSData * leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
    DSCoinbaseTransaction *coinbaseTransaction = (DSCoinbaseTransaction*)[DSTransactionFactory transactionWithMessage:[message subdataWithRange:NSMakeRange(offset, message.length - offset)] onChain:self.chain];
    if (![coinbaseTransaction isMemberOfClass:[DSCoinbaseTransaction class]]) return;
    offset += coinbaseTransaction.payloadOffset;
    
    if (length - offset < 1) return;
    NSNumber * deletedMasternodeCountLength;
    uint64_t deletedMasternodeCount = [message varIntAtOffset:offset length:&deletedMasternodeCountLength];
    offset += [deletedMasternodeCountLength unsignedLongValue];
    
    NSMutableArray * deletedMasternodeHashes = [NSMutableArray array];
    
    while (deletedMasternodeCount >= 1) {
        if (length - offset < 32) return;
        [deletedMasternodeHashes addObject:[NSData dataWithUInt256:[message UInt256AtOffset:offset]].reverse];
        offset += 32;
        deletedMasternodeCount--;
    }
    
    if (length - offset < 1) return;
    NSNumber * addedMasternodeCountLength;
    uint64_t addedMasternodeCount = [message varIntAtOffset:offset length:&addedMasternodeCountLength];
    offset += [addedMasternodeCountLength unsignedLongValue];
    
    leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
    NSMutableDictionary * addedOrModifiedMasternodes = [NSMutableDictionary dictionary];
    
    while (addedMasternodeCount >= 1) {
        if (length - offset < [DSSimplifiedMasternodeEntry payloadLength]) return;
        NSData * data = [message subdataWithRange:NSMakeRange(offset, [DSSimplifiedMasternodeEntry payloadLength])];
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithData:data onChain:self.chain];
        [addedOrModifiedMasternodes setObject:simplifiedMasternodeEntry forKey:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash].reverse];
        offset += [DSSimplifiedMasternodeEntry payloadLength];
        addedMasternodeCount--;
    }
    
    NSMutableDictionary * addedMasternodes = [addedOrModifiedMasternodes mutableCopy];
    [addedMasternodes removeObjectsForKeys:self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allKeys];
    NSMutableSet * modifiedMasternodeKeys = [NSMutableSet setWithArray:[addedOrModifiedMasternodes allKeys]];
    [modifiedMasternodeKeys intersectSet:[NSSet setWithArray:self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allKeys]];
    NSMutableDictionary * modifiedMasternodes = [NSMutableDictionary dictionary];
    for (NSData * data in modifiedMasternodeKeys) {
        [modifiedMasternodes setObject:self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data] forKey:data];
    }
    
    NSMutableDictionary * tentativeMasternodeList = [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash mutableCopy];
    
    [tentativeMasternodeList removeObjectsForKeys:deletedMasternodeHashes];
    [tentativeMasternodeList addEntriesFromDictionary:addedOrModifiedMasternodes];
    
    NSArray * proTxHashes = [tentativeMasternodeList allKeys];
    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
    }];
    
    NSMutableArray * simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes = [NSMutableArray array];
    for (NSData * proTxHash in proTxHashes) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [tentativeMasternodeList objectForKey:proTxHash];
        [simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes addObject:[NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash]];
    }
    
    UInt256 merkleRootMNList = [[NSData merkleRootFromHashes:simplifiedMasternodeListDictionaryByRegistrationTransactionHashHashes] UInt256];
    
    BOOL rootMNListValid = uint256_eq(coinbaseTransaction.merkleRootMNList, merkleRootMNList);
    
    DSMerkleBlock * lastBlock = peer.chain.lastBlock;
    while (lastBlock && !uint256_eq(lastBlock.blockHash, blockHash)) {
        lastBlock = peer.chain.recentBlocks[uint256_obj(lastBlock.prevBlock)];
    }
    
    if (!lastBlock) return;
    
    //we need to check that the coinbase is in the transaction hashes we got back
    UInt256 coinbaseHash = coinbaseTransaction.txHash;
    BOOL foundCoinbase = FALSE;
    for (int i = 0;i<merkleHashes.length;i+=32) {
        UInt256 randomTransactionHash = [merkleHashes UInt256AtOffset:i];
        if (uint256_eq(coinbaseHash, randomTransactionHash)) {
            foundCoinbase = TRUE;
            break;
        }
    }

    //we also need to check that the coinbase is in the merkle block
    DSMerkleBlock * coinbaseVerificationMerkleBlock = [[DSMerkleBlock alloc] initWithBlockHash:blockHash merkleRoot:lastBlock.merkleRoot totalTransactions:totalTransactions hashes:merkleHashes flags:merkleFlags];
    
    BOOL validCoinbase = [coinbaseVerificationMerkleBlock isMerkleTreeValid];
    
    if (foundCoinbase && validCoinbase && rootMNListValid) {
        //yay this is the correct masternode list verified deterministically
        self.baseBlockHash = blockHash;
        self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash = tentativeMasternodeList;
        [self.chain updateAddressUsageOfSimplifiedMasternodeEntries:addedOrModifiedMasternodes.allValues];
        [self.managedObjectContext performBlockAndWait:^{
            [DSSimplifiedMasternodeEntryEntity setContext:self.managedObjectContext];
            [DSChainEntity setContext:self.managedObjectContext];
            [DSLocalMasternodeEntity setContext:self.managedObjectContext];
            [DSAddressEntity setContext:self.managedObjectContext];
            DSChainEntity * chainEntity = self.chain.chainEntity;
            if (deletedMasternodeHashes.count) {
                NSMutableArray * nonReversedDeletedMasternodeHashes = [NSMutableArray array];
                for (NSData * deletedMasternodeHash in deletedMasternodeHashes) {
                    [nonReversedDeletedMasternodeHashes addObject:deletedMasternodeHash.reverse];
                }
                [DSSimplifiedMasternodeEntryEntity deleteHavingProviderTransactionHashes:nonReversedDeletedMasternodeHashes onChain:chainEntity];
            }
            for (NSString * addedMasternodeKey in addedMasternodes) {
                DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [addedMasternodes objectForKey:addedMasternodeKey];
                DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity managedObject];
                [simplifiedMasternodeEntryEntity setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry onChain:chainEntity];
            }
            for (NSData * simplifiedMasternodeEntryHash in modifiedMasternodes) {
                DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = modifiedMasternodes[simplifiedMasternodeEntryHash];
                DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity simplifiedMasternodeEntryForHash:[NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash] onChain:chainEntity];
                [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry];
            }
            chainEntity.baseBlockHash = [NSData dataWithUInt256:blockHash];
            [DSSimplifiedMasternodeEntryEntity saveContext];
        }];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
    } else {
        NSArray * faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        
        if (faultyPeers.count == MAX_FAULTY_DML_PEERS) {
            //we will redownload the full list on next connection
            [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash removeAllObjects];
            //no need to remove local masternodes
            self.baseBlockHash = UINT256_ZERO;
            
            NSManagedObjectContext * context = [NSManagedObject context];
            [context performBlockAndWait:^{
                [DSChainEntity setContext:context];
                [DSSimplifiedMasternodeEntryEntity setContext:context];
                DSChainEntity * chainEntity = peer.chain.chainEntity;
                [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
                [DSSimplifiedMasternodeEntryEntity saveContext];
            }];
            
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        } else {
            
            if (!faultyPeers) {
                faultyPeers = @[peer.location];
            } else {
                if (![faultyPeers containsObject:peer.location]) {
                    faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
                }
            }
            [[NSUserDefaults standardUserDefaults] setObject:faultyPeers forKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListValidationErrorNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
        [self.peerManager peerMisbehaving:peer];
    }
    
}

-(NSUInteger)simplifiedMasternodeEntryCount {
    return [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash count];
}

-(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntryForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return simplifiedMasternodeEntry;
        }
    }
    return nil;
}

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash {
    return [self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
}

-(BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    if (self.chain.protocolVersion < 70211) {
        return FALSE;
    } else {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [self simplifiedMasternodeEntryForLocation:IPAddress port:port];
        return (!!simplifiedMasternodeEntry);
    }
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
    
    if (uint256_is_zero(simplifiedMasternodeEntry.confirmedHash)) {
        return UINT256_ZERO;
    }
    NSMutableData * data = [NSMutableData data];
    [data appendData:[NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHashHashedWithProviderRegistrationTransactionHash]];
    [data appendData:[NSData dataWithUInt256:quorumHash]];
    return data.SHA256;
}

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount forBlockHash:(UInt256)blockHash {
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

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount {
    return [self masternodesForQuorumHash:quorumHash quorumCount:quorumCount forBlockHash:self.baseBlockHash];
}

// MARK: - Local Masternodes

-(void)loadLocalMasternodes {
    NSFetchRequest * fetchRequest = [[DSLocalMasternodeEntity fetchRequest] copy];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"providerRegistrationTransaction.transactionHash.chain == %@",self.chain.chainEntity]];
    NSArray * localMasternodeEntities = [DSLocalMasternodeEntity fetchObjects:fetchRequest];
    for (DSLocalMasternodeEntity * localMasternodeEntity in localMasternodeEntities) {
        [localMasternodeEntity loadLocalMasternode]; // lazy loaded into the list
    }
}

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet {
    return [self createNewMasternodeWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet inVotingWallet:wallet];
}

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)fundsWallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet {
    DSLocalMasternode * localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet inOperatorWallet:operatorWallet inOwnerWallet:ownerWallet inVotingWallet:votingWallet];
    return localMasternode;
}

-(DSLocalMasternode*)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction {

    //First check to see if we have a local masternode for this provider registration hash
    
    @synchronized (self) {
        DSLocalMasternode * localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransaction.txHash)];
        
        if (localMasternode) {
            //We do
            //todo Update keys
            return localMasternode;
        }
        //We don't
        localMasternode = [[DSLocalMasternode alloc] initWithProviderTransactionRegistration:providerRegistrationTransaction];
        
        [self.localMasternodesDictionaryByRegistrationTransactionHash setObject:localMasternode forKey:uint256_data(providerRegistrationTransaction.txHash)];
        [localMasternode save];
        return localMasternode;
    }
}

-(DSLocalMasternode*)localMasternodeHavingProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    DSLocalMasternode * localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransactionHash)];
    
    return localMasternode;

}

-(NSUInteger)localMasternodesCount {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash count];
}

- (NSArray*)localMasternodes {
//    if (self.localMasternodesDictionaryByRegistrationTransactionHash) return self.localMasternodesDictionaryByRegistrationTransactionHash;
//    @synchronized(self) {
//        self.localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
//    }
//    return [self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueID];
    return nil;
}

-(void)checkForLocalMasternodes:(NSDictionary<NSData*,DSSimplifiedMasternodeEntry*> *)masternodeList {

}

@end
