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
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
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
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSDerivationPath.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSQuorumEntry.h"
#import "DSMasternodeList.h"
#import "DSTransactionManager.h"

#define REQUEST_MASTERNODE_BROADCAST_COUNT 500
#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@",peer.chain.uniqueID,FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 5


@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) DSMasternodeList * currentMasternodeList;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,assign) UInt256 lastQueriedBlockHash; //last by height, not by time queried
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSMasternodeList*>* masternodeListsByBlockHash;
@property (nonatomic,strong) NSMutableDictionary<NSData*,NSNumber*>* masternodeListsBlockHashHeights;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSLocalMasternode*> *localMasternodesDictionaryByRegistrationTransactionHash;
@property (nonatomic,strong) NSMutableArray <NSData*>* masternodeListRetrievalQueue;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    _chain = chain;
    _masternodeListRetrievalQueue = [NSMutableArray array];
    _masternodeListsByBlockHash = [NSMutableDictionary dictionary];
    _masternodeListsBlockHashHeights = [NSMutableDictionary dictionary];
    _localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    self.lastQueriedBlockHash = UINT256_ZERO;
    return self;
}

-(DSMasternodeList*)masternodeListForBlockHash:(UInt256)blockHash {
    return [self.masternodeListsByBlockHash objectForKey:uint256_data(blockHash)];
}

-(DSMasternodeList*)masternodeListAtBlockHeight:(uint32_t)blockHeight {
    DSMerkleBlock * merkleBlock = [self.chain blockFromChainTip:8];
    return [self masternodeListBeforeBlockHash:merkleBlock.blockHash];
}

-(void)setUp {
    [self loadMasternodeLists];
    [self loadLocalMasternodes];
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}

// MARK: - Masternode List Sync

// Syncing the masternode list starts by syncing the current list
// When syncing quorums masternode lists

-(UInt256)closestKnownBlockHashForBlockHash:(UInt256)blockHash {
    DSMasternodeList * masternodeList = [self masternodeListBeforeBlockHash:blockHash];
    if (masternodeList) return masternodeList.blockHash;
    else return self.chain.genesisHash;
}

-(void)dequeueMasternodeListRequest {
    if (![self.masternodeListRetrievalQueue count]) return;
    UInt256 blockHash = [self.masternodeListRetrievalQueue objectAtIndex:0].UInt256;
    
    //we should check the associated block still exists
    __block BOOL hasBlock;
    [self.managedObjectContext performBlockAndWait:^{
        hasBlock = !![DSMerkleBlockEntity countObjectsMatching:@"blockHash == %@",uint256_data(blockHash)];
    }];
    if (hasBlock) {
        UInt256 previousBlockHash = [self closestKnownBlockHashForBlockHash:blockHash];
        DSDLog(@"Requesting masternode list and quorums from %u to %u (%@ to %@)",[self heightForBlockHash:previousBlockHash],[self heightForBlockHash:blockHash], uint256_reverse_hex(previousBlockHash), uint256_reverse_hex(blockHash));
        [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:previousBlockHash forBlockHash:blockHash];
    } else {
        DSDLog(@"Missing block (%@)",uint256_reverse_hex(blockHash));
        [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
        [self dequeueMasternodeListRequest];
    }
    
}

-(void)getRecentMasternodeList:(NSUInteger)blocksAgo {
    @synchronized (self.masternodeListRetrievalQueue) {
        BOOL emptyRequestQueue = ![self.masternodeListRetrievalQueue count];
        DSMerkleBlock * merkleBlock = [self.chain blockFromChainTip:blocksAgo];
        self.lastQueriedBlockHash = merkleBlock.blockHash;
        [self.masternodeListRetrievalQueue addObject:[NSData dataWithUInt256:merkleBlock.blockHash]];
        if (emptyRequestQueue) {
            [self dequeueMasternodeListRequest];
        }
    }
}

-(void)getCurrentMasternodeList {
    @synchronized (self.masternodeListRetrievalQueue) {
        self.lastQueriedBlockHash = self.chain.lastBlock.blockHash;
        BOOL emptyRequestQueue = ![self.masternodeListRetrievalQueue count];
        [self.masternodeListRetrievalQueue addObject:[NSData dataWithUInt256:self.chain.lastBlock.blockHash]];
        if (emptyRequestQueue) {
            [self dequeueMasternodeListRequest];
        }
    }
}

-(uint32_t)heightForBlockHash:(UInt256)blockhash {
    NSNumber * cachedHeightNumber = [self.masternodeListsBlockHashHeights objectForKey:uint256_data(blockhash)];
    if (cachedHeightNumber) return [cachedHeightNumber intValue];
    uint32_t chainHeight = [self.chain heightForBlockHash:blockhash];
    if (chainHeight) [self.masternodeListsBlockHashHeights setObject:@(chainHeight) forKey:uint256_data(blockhash)];
    return chainHeight;
}

-(void)getMasternodeListsForBlockHashes:(NSArray*)blockHashes {
    @synchronized (self.masternodeListRetrievalQueue) {
        NSArray * orderedBlockHashes = [blockHashes sortedArrayUsingComparator:^NSComparisonResult(NSData *  _Nonnull obj1, NSData *  _Nonnull obj2) {
            uint32_t height1 = [self heightForBlockHash:obj1.UInt256];
            uint32_t height2 = [self heightForBlockHash:obj2.UInt256];
            return (height1>height2)?NSOrderedDescending:NSOrderedAscending;
        }];
        for (NSData * blockHash in orderedBlockHashes) {
            DSDLog(@"adding retrieval of masternode list at height %u to queue (%@)",[self  heightForBlockHash:blockHash.UInt256],blockHash.reverse.hexString);
        }
        BOOL emptyRequestQueue = ![self.masternodeListRetrievalQueue count];
        [self.masternodeListRetrievalQueue addObjectsFromArray:orderedBlockHashes];
        if (emptyRequestQueue) {
            [self dequeueMasternodeListRequest];
        }
    }
}

-(DSMasternodeList*)masternodeListBeforeBlockHash:(UInt256)blockHash {
    uint32_t minDistance = UINT32_MAX;
    uint32_t blockHeight = [self heightForBlockHash:blockHash];
    DSMasternodeList * closestMasternodeList = nil;
    for (NSData * blockHashData in self.masternodeListsByBlockHash) {
        uint32_t masternodeListBlockHeight = [self heightForBlockHash:blockHashData.UInt256];
        if (blockHeight <= masternodeListBlockHeight) continue;
        uint32_t distance = blockHeight - masternodeListBlockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            closestMasternodeList = self.masternodeListsByBlockHash[blockHashData];
        }
    }
    return closestMasternodeList;
}

-(void)wipeMasternodeInfo {
    [self.masternodeListsByBlockHash removeAllObjects];
    [self.localMasternodesDictionaryByRegistrationTransactionHash removeAllObjects];
}

-(void)loadMasternodeLists {
    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest * fetchRequest = [[DSMasternodeListEntity fetchRequest] copy];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"block.chain == %@",self.chain.chainEntity]];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"block.height" ascending:YES]]];
        NSArray * masternodeListEntities = [DSMasternodeListEntity fetchObjects:fetchRequest];
        NSMutableDictionary * simplifiedMasternodeEntryPool = [NSMutableDictionary dictionary];
        NSMutableDictionary * quorumEntryPool = [NSMutableDictionary dictionary];
        for (DSMasternodeListEntity * masternodeListEntity in masternodeListEntities) {
            DSMasternodeList * masternodeList = [masternodeListEntity masternodeListWithSimplifiedMasternodeEntryPool:[simplifiedMasternodeEntryPool copy] quorumEntryPool:quorumEntryPool];
            [self.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(masternodeList.blockHash)];
            [self.masternodeListsBlockHashHeights setObject:@([self.chain heightForBlockHash:masternodeList.blockHash]) forKey:uint256_data(masternodeList.blockHash)];
            [simplifiedMasternodeEntryPool addEntriesFromDictionary:masternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash];
            [quorumEntryPool addEntriesFromDictionary:masternodeList.quorums];
            DSDLog(@"Loading Masternode List at height %u for blockHash %@ with %lu entries",masternodeList.height,uint256_hex(masternodeList.blockHash),(unsigned long)masternodeList.simplifiedMasternodeEntries.count);
            self.currentMasternodeList = masternodeList;
        }
    }];
}

//-(void)loadQuorumEntries:(NSUInteger)count {
//    NSFetchRequest * fetchRequest = [[DSQuorumEntryEntity fetchRequest] copy];
//    if (count && count != NSUIntegerMax) {
//        [fetchRequest setFetchLimit:count];
//    }
//    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",self.chain.chainEntity]];
//    NSArray * quorumEntryEntities = [DSQuorumEntryEntity fetchObjects:fetchRequest];
//    for (DSQuorumEntryEntity * quorumEntryEntity in quorumEntryEntities) {
//        if ([self.quorumsDictionary objectForKey:@(quorumEntryEntity.llmqType)]) {
//            NSMutableDictionary * llmqDictionaryByCommitmentHash = [self.quorumsDictionary objectForKey:@(quorumEntryEntity.llmqType)];
//            [llmqDictionaryByCommitmentHash setObject:quorumEntryEntity forKey:quorumEntryEntity.commitmentHashData];
//
//            NSMutableDictionary * llmqDictionaryByCommitmentHashForBlockHash = [self.quorumsBlockHashToCommitmentHashDictionary objectForKey:@(quorumEntryEntity.llmqType)];
//            [llmqDictionaryByCommitmentHashForBlockHash setObject:quorumEntryEntity.commitmentHashData forKey:quorumEntryEntity.quorumHashData];
//        } else {
//            [self.quorumsDictionary setObject:[NSMutableDictionary dictionaryWithObject:quorumEntryEntity forKey:quorumEntryEntity.commitmentHashData] forKey:@(quorumEntryEntity.llmqType)];
//            [self.quorumsBlockHashToCommitmentHashDictionary setObject:[NSMutableDictionary dictionaryWithObject:quorumEntryEntity.commitmentHashData forKey:quorumEntryEntity.quorumHashData] forKey:@(quorumEntryEntity.llmqType)];
//        }
//
//    }
//}


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

#define LOG_MASTERNODE_DIFF 0

-(void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    NSArray * faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    
    if (faultyPeers.count == MAX_FAULTY_DML_PEERS) {
        //no need to remove local masternodes
        [self.masternodeListRetrievalQueue removeAllObjects];
        
        NSManagedObjectContext * context = [NSManagedObject context];
        [context performBlockAndWait:^{
            [DSMasternodeListEntity setContext:context];
            DSChainEntity * chainEntity = peer.chain.chainEntity;
            [DSMasternodeListEntity deleteAllOnChain:chainEntity];
            [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
        }];
        
        [self.masternodeListsByBlockHash removeAllObjects];
        
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
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDiffValidationErrorNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
}

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
    
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    DSDLog(@"baseBlockHash %@ (%u) blockHash %@ (%u)",uint256_reverse_hex(baseBlockHash), [self.chain heightForBlockHash:baseBlockHash], uint256_reverse_hex(blockHash),[self.chain heightForBlockHash:blockHash]);
    
    DSMasternodeList * baseMasternodeList = [self.masternodeListsByBlockHash objectForKey:uint256_data(baseBlockHash)];
    
    if (!baseMasternodeList && !uint256_eq(self.chain.genesisHash, baseBlockHash) && !uint256_is_zero(baseBlockHash)) {
        //this could have been deleted in the meantime, if so rerequest
        [self issueWithMasternodeListFromPeer:peer];
        [self dequeueMasternodeListRequest];
        return;
    };
    
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
    if (baseMasternodeList) [addedMasternodes removeObjectsForKeys:baseMasternodeList.reversedRegistrationTransactionHashes];
    NSMutableSet * modifiedMasternodeKeys;
    if (baseMasternodeList) {
        modifiedMasternodeKeys = [NSMutableSet setWithArray:[addedOrModifiedMasternodes allKeys]];
        [modifiedMasternodeKeys intersectSet:[NSSet setWithArray:baseMasternodeList.reversedRegistrationTransactionHashes]];
    } else {
        modifiedMasternodeKeys = [NSMutableSet set];
    }
    NSMutableDictionary * modifiedMasternodes = [NSMutableDictionary dictionary];
    for (NSData * data in modifiedMasternodeKeys) {
        [modifiedMasternodes setObject:addedOrModifiedMasternodes[data] forKey:data];
    }
    
    NSMutableArray * quorumsForDeletion = [@[] mutableCopy];
    
    NSMutableDictionary * deletedQuorums = [NSMutableDictionary dictionary];
    NSMutableDictionary * addedQuorums = [NSMutableDictionary dictionary];
    
    BOOL quorumsActive = (coinbaseTransaction.version >= 2);
    
    BOOL validQuorums = TRUE;
    
    if (quorumsActive) {
        if (length - offset < 1) return;
        NSNumber * deletedQuorumsCountLength;
        uint64_t deletedQuorumsCount = [message varIntAtOffset:offset length:&deletedQuorumsCountLength];
        offset += [deletedQuorumsCountLength unsignedLongValue];
        
        while (deletedQuorumsCount >= 1) {
            if (length - offset < 33) return;
            DSLLMQ llmq;
            llmq.type = [message UInt8AtOffset:offset];
            llmq.hash = [message UInt256AtOffset:offset + 1];
            if (![deletedQuorums objectForKey:@(llmq.type)]) {
                [deletedQuorums setObject:[NSMutableArray arrayWithObject:[NSData dataWithUInt256:llmq.hash]] forKey:@(llmq.type)];
            } else {
                NSMutableArray * mutableLLMQArray = [deletedQuorums objectForKey:@(llmq.type)];
                [mutableLLMQArray addObject:[NSData dataWithUInt256:llmq.hash]];
            }
            offset += 33;
            deletedQuorumsCount--;
        }
        
        if (length - offset < 1) return;
        NSNumber * addedQuorumsCountLength;
        uint64_t addedQuorumsCount = [message varIntAtOffset:offset length:&addedQuorumsCountLength];
        offset += [addedQuorumsCountLength unsignedLongValue];
        
        leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
        
        NSMutableArray * neededMasternodeLists = [NSMutableArray array];
        
        while (addedQuorumsCount >= 1) {
            DSQuorumEntry * potentialQuorumEntry = [DSQuorumEntry potentialQuorumEntryWithData:message dataOffset:(uint32_t)offset onChain:self.chain];
            
            DSMasternodeList * quorumMasternodeList = [self.masternodeListsByBlockHash objectForKey:uint256_data(potentialQuorumEntry.quorumHash)];
            
            if (quorumMasternodeList) {
                validQuorums &= [potentialQuorumEntry validateWithMasternodeList:quorumMasternodeList];
                if (!validQuorums) {
                    DSDLog(@"Invalid Quorum Found");
                }
            } else {
                if ([self heightForBlockHash:potentialQuorumEntry.quorumHash]) {
                    [neededMasternodeLists addObject:uint256_data(potentialQuorumEntry.quorumHash)];
                }
            }
            
            if (![addedQuorums objectForKey:@(potentialQuorumEntry.llmqType)]) {
                [addedQuorums setObject:[NSMutableDictionary dictionaryWithObject:potentialQuorumEntry forKey:[NSData dataWithUInt256:potentialQuorumEntry.quorumHash]] forKey:@(potentialQuorumEntry.llmqType)];
            } else {
                NSMutableDictionary * mutableLLMQDictionary = [addedQuorums objectForKey:@(potentialQuorumEntry.llmqType)];
                [mutableLLMQDictionary setObject:potentialQuorumEntry forKey:[NSData dataWithUInt256:potentialQuorumEntry.quorumHash]];
            }
            offset += potentialQuorumEntry.length;
            addedQuorumsCount--;
        }
        
        if ([neededMasternodeLists count] && uint256_eq(self.lastQueriedBlockHash,blockHash)) {
            //This is the current one, get more previous masternode lists we need to verify quorums
            
            [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
            [neededMasternodeLists addObject:uint256_data(self.chain.lastBlock.blockHash)]; //also get the current one again
            [self getMasternodeListsForBlockHashes:neededMasternodeLists];
            return;
        }
    }
    
    DSMasternodeList * masternodeList = [DSMasternodeList masternodeListAtBlockHash:blockHash fromBaseMasternodeList:baseMasternodeList addedMasternodes:addedMasternodes removedMasternodeHashes:deletedMasternodeHashes modifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums removedQuorumHashesByType:deletedQuorums onChain:self.chain];
    
    BOOL rootMNListValid = uint256_eq(coinbaseTransaction.merkleRootMNList, masternodeList.masternodeMerkleRoot);
    
    if (!rootMNListValid) {
        DSDLog(@"Masternode Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)",coinbaseTransaction.height,coinbaseTransaction.version,uint256_hex(coinbaseTransaction.merkleRootMNList),uint256_hex(masternodeList.masternodeMerkleRoot));
    }
    
    BOOL rootQuorumListValid = TRUE;
    
    if (quorumsActive) {
        rootQuorumListValid = uint256_eq(coinbaseTransaction.merkleRootLLMQList, masternodeList.quorumMerkleRoot);
        
        if (!rootQuorumListValid) {
            DSDLog(@"Quorum Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)",coinbaseTransaction.height,coinbaseTransaction.version,uint256_hex(coinbaseTransaction.merkleRootLLMQList),uint256_hex(masternodeList.quorumMerkleRoot));
        }
    }
    
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
    
    if (foundCoinbase && validCoinbase && rootMNListValid && rootQuorumListValid && validQuorums) {
        DSDLog(@"Valid masternode list found at height %u",[self heightForBlockHash:blockHash]);
        //yay this is the correct masternode list verified deterministically for the given block
        [self.chain updateAddressUsageOfSimplifiedMasternodeEntries:addedOrModifiedMasternodes.allValues];
        [self.managedObjectContext performBlockAndWait:^{
            //masternodes
            [DSSimplifiedMasternodeEntryEntity setContext:self.managedObjectContext];
            [DSChainEntity setContext:self.managedObjectContext];
            [DSLocalMasternodeEntity setContext:self.managedObjectContext];
            [DSAddressEntity setContext:self.managedObjectContext];
            [DSMasternodeListEntity setContext:self.managedObjectContext];
            DSChainEntity * chainEntity = self.chain.chainEntity;
            DSMerkleBlockEntity * merkleBlockEntity = [DSMerkleBlockEntity anyObjectMatching:@"blockHash == %@",uint256_data(blockHash)];
            if (!merkleBlockEntity) return;
            DSMasternodeListEntity * masternodeListEntity = [DSMasternodeListEntity managedObject];
            masternodeListEntity.block = merkleBlockEntity;
            for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in masternodeList.simplifiedMasternodeEntries) {
                DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity simplifiedMasternodeEntryForProviderRegistrationTransactionHash:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash] onChain:chainEntity];
                if (!simplifiedMasternodeEntryEntity) {
                    simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity managedObject];
                    [simplifiedMasternodeEntryEntity setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry onChain:chainEntity];
                }
                [masternodeListEntity addMasternodesObject:simplifiedMasternodeEntryEntity];
            }
            for (NSData * simplifiedMasternodeEntryHash in modifiedMasternodes) {
                DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = modifiedMasternodes[simplifiedMasternodeEntryHash];
                DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity simplifiedMasternodeEntryForProviderRegistrationTransactionHash:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash] onChain:chainEntity];
                [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry];
            }
            
            if (addedQuorums.count > 0 || quorumsForDeletion.count) {
                //quorums
                [DSQuorumEntryEntity setContext:self.managedObjectContext];
                [DSMerkleBlockEntity setContext:self.managedObjectContext];
                for (NSNumber * llmqType in addedQuorums) {
                    for (NSData * quorumHash in addedQuorums[llmqType]) {
                        DSQuorumEntry * potentialQuorumEntry = addedQuorums[llmqType][quorumHash];
                        DSQuorumEntryEntity * quorumEntry = [DSQuorumEntryEntity quorumEntryEntityFromPotentialQuorumEntry:potentialQuorumEntry];
                        [masternodeListEntity addQuorumsObject:quorumEntry];
                    }
                }
            }
            chainEntity.baseBlockHash = [NSData dataWithUInt256:blockHash];
            NSError * error = [DSSimplifiedMasternodeEntryEntity saveContext];
            if (error) {
                [self.masternodeListRetrievalQueue removeAllObjects];
                chainEntity.baseBlockHash = uint256_data(self.chain.genesisHash);
                [DSLocalMasternodeEntity deleteAllOnChain:chainEntity];
                [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
                [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
                [self wipeMasternodeInfo];
                [DSSimplifiedMasternodeEntryEntity saveContext];
            } else {
                [self.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(blockHash)];
            }
            
            
        }];
        
        NSAssert([self.masternodeListRetrievalQueue containsObject:uint256_data(blockHash)], @"This should still be here");
        [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
        [self dequeueMasternodeListRequest];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        
        //check for instant send locks that were awaiting a quorum
        
        if (![self.masternodeListRetrievalQueue count]) {
        
            [self.chain.chainManager.transactionManager checkWaitingInstantSendLocksAgainstMasternodeList:masternodeList];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            
            if (quorumsActive && (addedQuorums.count || quorumsForDeletion.count)) {
                [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            }
        });
    } else {
        [self issueWithMasternodeListFromPeer:peer];
    }
    
}

-(NSUInteger)simplifiedMasternodeEntryCount {
    return [self.currentMasternodeList masternodeCount];
}

-(NSUInteger)activeQuorumsCount {
    return self.currentMasternodeList.quorums.count;
}

-(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntryForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return simplifiedMasternodeEntry;
        }
    }
    return nil;
}

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);
    
    return [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
}

-(BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    if (self.chain.protocolVersion < 70211) {
        return FALSE;
    } else {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [self simplifiedMasternodeEntryForLocation:IPAddress port:port];
        return (!!simplifiedMasternodeEntry);
    }
}



// MARK: - Quorums

-(DSQuorumEntry*)quorumEntryForInstantSendRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock * merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    DSMasternodeList * masternodeList = [self masternodeListBeforeBlockHash:merkleBlock.blockHash];
    NSArray * quorumsForIS = [masternodeList.quorums[@(1)] allValues];
    UInt256 lowestValue = UINT256_MAX;
    DSQuorumEntry * firstQuorum = nil;
    for (DSQuorumEntry * quorumEntry in quorumsForIS) {
        UInt256 orderingHash = uint256_reverse([quorumEntry orderingHashForRequestID:requestID]);
        if (uint256_sup(lowestValue, orderingHash)) {
            lowestValue = orderingHash;
            firstQuorum = quorumEntry;
        }
    }
    return firstQuorum;
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
    NSParameterAssert(wallet);
    
    return [self createNewMasternodeWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet inVotingWallet:wallet];
}

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)fundsWallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet {
    DSLocalMasternode * localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet inOperatorWallet:operatorWallet inOwnerWallet:ownerWallet inVotingWallet:votingWallet];
    return localMasternode;
}

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet* _Nullable)fundsWallet fundsWalletIndex:(uint32_t)fundsWalletIndex inOperatorWallet:(DSWallet* _Nullable)operatorWallet operatorWalletIndex:(uint32_t)operatorWalletIndex inOwnerWallet:(DSWallet* _Nullable)ownerWallet ownerWalletIndex:(uint32_t)ownerWalletIndex inVotingWallet:(DSWallet* _Nullable)votingWallet votingWalletIndex:(uint32_t)votingWalletIndex {
    DSLocalMasternode * localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet fundsWalletIndex:fundsWalletIndex inOperatorWallet:operatorWallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerWalletIndex inVotingWallet:votingWallet votingWalletIndex:votingWalletIndex];
    return localMasternode;
}

-(DSLocalMasternode*)localMasternodeFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry claimedWithOwnerWallet:(DSWallet*)ownerWallet ownerKeyIndex:(uint32_t)ownerKeyIndex {
    NSParameterAssert(simplifiedMasternodeEntry);
    NSParameterAssert(ownerWallet);
    
    DSLocalMasternode * localMasternode = [self localMasternodeHavingProviderRegistrationTransactionHash:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
    
    if (localMasternode) return localMasternode;
    
    uint32_t votingIndex;
    DSWallet * votingWallet = [simplifiedMasternodeEntry.chain walletHavingProviderVotingAuthenticationHash:simplifiedMasternodeEntry.keyIDVoting foundAtIndex:&votingIndex];
    
    uint32_t operatorIndex;
    DSWallet * operatorWallet = [simplifiedMasternodeEntry.chain walletHavingProviderOperatorAuthenticationKey:simplifiedMasternodeEntry.operatorPublicKey foundAtIndex:&operatorIndex];
    
    if (votingWallet || operatorWallet) {
        return [[DSLocalMasternode alloc] initWithIPAddress:simplifiedMasternodeEntry.address onPort:simplifiedMasternodeEntry.port inFundsWallet:nil fundsWalletIndex:0 inOperatorWallet:operatorWallet operatorWalletIndex:operatorIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerKeyIndex inVotingWallet:votingWallet votingWalletIndex:votingIndex];
    } else {
        return nil;
    }
}

-(DSLocalMasternode*)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction save:(BOOL)save {
    NSParameterAssert(providerRegistrationTransaction);
    
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
        
        if (localMasternode.noLocalWallet) return nil;
        [self.localMasternodesDictionaryByRegistrationTransactionHash setObject:localMasternode forKey:uint256_data(providerRegistrationTransaction.txHash)];
        [localMasternode save];
        return localMasternode;
    }
}

-(DSLocalMasternode*)localMasternodeHavingProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    DSLocalMasternode * localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransactionHash)];
    
    return localMasternode;

}

-(DSLocalMasternode*)localMasternodeUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath*)derivationPath {
    NSParameterAssert(derivationPath);
    
    for (DSLocalMasternode * localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderFunds:
                if (localMasternode.holdingKeysWallet == derivationPath.wallet && localMasternode.holdingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOwnerKeys:
                if (localMasternode.ownerKeysWallet == derivationPath.wallet && localMasternode.ownerWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && localMasternode.operatorWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && localMasternode.votingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            default:
                break;
        }
    }
    return nil;
}

-(NSUInteger)localMasternodesCount {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash count];
}


@end
