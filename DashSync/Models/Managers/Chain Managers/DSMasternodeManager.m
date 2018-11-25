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


@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,assign) UInt256 baseBlockHash;
@property (nonatomic,strong) NSMutableDictionary *simplifiedMasternodeList;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _simplifiedMasternodeList = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    return self;
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}

// MARK: - Masternode List Sync

-(void)getMasternodeList {
    [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:self.baseBlockHash forBlockHash:self.chain.lastBlock.blockHash];
}

-(void)wipeMasternodeInfo {
    [self.simplifiedMasternodeList removeAllObjects];
    self.baseBlockHash = UINT256_ZERO;
}

-(void)loadSimplifiedMasternodeEntries:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSSimplifiedMasternodeEntryEntity fetchRequest] copy];
    [fetchRequest setFetchLimit:count];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",self.chain.chainEntity]];
    NSArray * simplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity fetchObjects:fetchRequest];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in simplifiedMasternodeEntryEntities) {
        [self.simplifiedMasternodeList setObject:simplifiedMasternodeEntryEntity.simplifiedMasternodeEntry forKey:simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash];
    }
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch :(NSData*)simplifiedMasternodeListHashes :(NSData*)flags
{
    if ((*flagIdx)/8 >= flags.length || (*hashIdx + 1)*sizeof(UInt256) > simplifiedMasternodeListHashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == ceil_log2((int)_simplifiedMasternodeList.count)) {
        UInt256 hash = [simplifiedMasternodeListHashes hashAtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListHashes :flags];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch :simplifiedMasternodeListHashes :flags];
    
    return branch(left, right);
}


//-(void)verify {
//    NSMutableData * simplifiedMasternodeListHashes = [NSMutableData data];
//    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in self.simplifiedMasternodeList) {
//        [simplifiedMasternodeListHashes appendUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
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
//    } :simplifiedMasternodeListHashes :flags];
//
//    [root getValue:&merkleRoot];
//}

-(void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData*)message {
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    
    if (length - offset < 32) return;
    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    if (!uint256_eq(baseBlockHash, self.baseBlockHash)) return;
    
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    NSLog(@"baseBlockHash %@ blockHash %@",[NSData dataWithUInt256:baseBlockHash].hexString,[NSData dataWithUInt256:blockHash].hexString);
    
    if (length - offset < 4) return;
    uint32_t totalTransactions = [message UInt32AtOffset:offset];
    offset += 4;
    
    if (length - offset < 1) return;
    
    NSNumber * merkleHashCountLength;
    uint64_t merkleHashCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleHashCountLength]*sizeof(UInt256);
    offset += [merkleHashCountLength unsignedLongValue];
    
    
    NSData * merkleHashes = [message subdataWithRange:NSMakeRange(offset, merkleHashCount)];
    offset += merkleHashCount;
    
    NSNumber * merkleFlagCountLength;
    uint64_t merkleFlagCount = [message varIntAtOffset:offset length:&merkleFlagCountLength];
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
        [deletedMasternodeHashes addObject:[NSData dataWithUInt256:[message UInt256AtOffset:offset]]];
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
    [addedMasternodes removeObjectsForKeys:self.simplifiedMasternodeList.allKeys];
    NSMutableSet * modifiedMasternodeKeys = [NSMutableSet setWithArray:[addedOrModifiedMasternodes allKeys]];
    [modifiedMasternodeKeys intersectSet:[NSSet setWithArray:self.simplifiedMasternodeList.allKeys]];
    NSMutableDictionary * modifiedMasternodes = [NSMutableDictionary dictionary];
    for (NSData * data in modifiedMasternodeKeys) {
        [modifiedMasternodes setObject:self.simplifiedMasternodeList[data] forKey:data];
    }
    
    NSMutableDictionary * tentativeMasternodeList = [self.simplifiedMasternodeList mutableCopy];
    
    [tentativeMasternodeList removeObjectsForKeys:deletedMasternodeHashes];
    [tentativeMasternodeList addEntriesFromDictionary:addedOrModifiedMasternodes];
    
    NSArray * proTxHashes = [tentativeMasternodeList allKeys];
    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
    }];
    
    NSMutableArray * simplifiedMasternodeListHashes = [NSMutableArray array];
    for (NSData * proTxHash in proTxHashes) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [tentativeMasternodeList objectForKey:proTxHash];
        [simplifiedMasternodeListHashes addObject:[NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash]];
    }
    
    UInt256 merkleRootMNList = [[NSData merkleRootFromHashes:simplifiedMasternodeListHashes] UInt256];
    
    BOOL rootMNListValid = uint256_eq(coinbaseTransaction.merkleRootMNList, merkleRootMNList);
    
    DSMerkleBlock * lastBlock = peer.chain.lastBlock;
    while (lastBlock && !uint256_eq(lastBlock.blockHash, blockHash)) {
        lastBlock = peer.chain.recentBlocks[uint256_obj(lastBlock.prevBlock)];
    }
    
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
        self.simplifiedMasternodeList = tentativeMasternodeList;
        [self.managedObjectContext performBlockAndWait:^{
            [DSSimplifiedMasternodeEntryEntity setContext:self.managedObjectContext];
            [DSChainEntity setContext:self.managedObjectContext];
            DSChainEntity * chainEntity = self.chain.chainEntity;
            if (deletedMasternodeHashes.count) {
                [DSSimplifiedMasternodeEntryEntity deleteHavingProviderTransactionHashes:deletedMasternodeHashes onChain:chainEntity];
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListValidationErrorNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
        [self.peerManager peerMisbehaving:peer];
    }
    
}

-(NSUInteger)simplifiedMasternodeEntryCount {
    return [self.simplifiedMasternodeList count];
}

-(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntryForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in [self.simplifiedMasternodeList allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return simplifiedMasternodeEntry;
        }
    }
    return nil;
}

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash {
    return [self.simplifiedMasternodeList objectForKey:providerRegistrationTransactionHash];
}

-(BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    if (self.chain.protocolVersion < 70211) {
        return FALSE;
    } else {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [self simplifiedMasternodeEntryForLocation:IPAddress port:port];
        return (!!simplifiedMasternodeEntry);
    }
}

@end
