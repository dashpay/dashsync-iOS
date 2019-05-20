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
#import "DSPotentialQuorumEntry.h"
#import "DSMasternodeList.h"

#define REQUEST_MASTERNODE_BROADCAST_COUNT 500
#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@",peer.chain.uniqueID,FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 5


@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,assign) UInt256 baseBlockHash;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSMasternodeList*>* masternodeListsByBlockHash;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSSimplifiedMasternodeEntry*> *knownMasternodeDictionaryByReversedRegistrationTransactionHash;
@property (nonatomic,strong) NSMutableDictionary<NSNumber*,NSMutableDictionary<NSData*,DSQuorumEntryEntity*>*> *quorumsDictionary;
@property (nonatomic,strong) NSMutableDictionary<NSNumber*,NSMutableDictionary<NSData*,NSData*>*> *quorumsBlockHashToCommitmentHashDictionary;
@property (nonatomic,strong) NSMutableDictionary<NSData*,DSLocalMasternode*> *localMasternodesDictionaryByRegistrationTransactionHash;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    _chain = chain;
    _quorumsDictionary = [NSMutableDictionary dictionary];
    _masternodeListsByBlockHash = [NSMutableDictionary dictionary];
    _knownMasternodeDictionaryByReversedRegistrationTransactionHash = [NSMutableDictionary dictionary];
    _quorumsBlockHashToCommitmentHashDictionary = [NSMutableDictionary dictionary];
    _localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    self.baseBlockHash = chain.masternodeBaseBlockHash;
    DSDLog(@"Setting base block hash to %@",uint256_reverse_hex(self.baseBlockHash));
    return self;
}

-(void)setUp {
    [self loadSimplifiedMasternodeEntries:NSUIntegerMax];
    [self loadQuorumEntries:NSUIntegerMax];
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
    [self.masternodeListsByBlockHash removeAllObjects];
    [self.localMasternodesDictionaryByRegistrationTransactionHash removeAllObjects];
    [self.quorumsDictionary removeAllObjects];
    [self.quorumsBlockHashToCommitmentHashDictionary removeAllObjects];
    self.baseBlockHash = self.chain.genesisHash;
}

-(void)loadSimplifiedMasternodeEntries:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSSimplifiedMasternodeEntryEntity fetchRequest] copy];
    if (count && count != NSUIntegerMax) {
        [fetchRequest setFetchLimit:count];
    }
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",self.chain.chainEntity]];
    NSArray * simplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity fetchObjects:fetchRequest];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in simplifiedMasternodeEntryEntities) {
        [self.knownMasternodeDictionaryByReversedRegistrationTransactionHash setObject:simplifiedMasternodeEntryEntity.simplifiedMasternodeEntry forKey:simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash.reverse];
    }
}

-(void)loadQuorumEntries:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSQuorumEntryEntity fetchRequest] copy];
    if (count && count != NSUIntegerMax) {
        [fetchRequest setFetchLimit:count];
    }
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",self.chain.chainEntity]];
    NSArray * quorumEntryEntities = [DSQuorumEntryEntity fetchObjects:fetchRequest];
    for (DSQuorumEntryEntity * quorumEntryEntity in quorumEntryEntities) {
        if ([self.quorumsDictionary objectForKey:@(quorumEntryEntity.llmqType)]) {
            NSMutableDictionary * llmqDictionaryByCommitmentHash = [self.quorumsDictionary objectForKey:@(quorumEntryEntity.llmqType)];
            [llmqDictionaryByCommitmentHash setObject:quorumEntryEntity forKey:quorumEntryEntity.commitmentHashData];
            
            NSMutableDictionary * llmqDictionaryByCommitmentHashForBlockHash = [self.quorumsBlockHashToCommitmentHashDictionary objectForKey:@(quorumEntryEntity.llmqType)];
            [llmqDictionaryByCommitmentHashForBlockHash setObject:quorumEntryEntity.commitmentHashData forKey:quorumEntryEntity.quorumHashData];
        } else {
            [self.quorumsDictionary setObject:[NSMutableDictionary dictionaryWithObject:quorumEntryEntity forKey:quorumEntryEntity.commitmentHashData] forKey:@(quorumEntryEntity.llmqType)];
            [self.quorumsBlockHashToCommitmentHashDictionary setObject:[NSMutableDictionary dictionaryWithObject:quorumEntryEntity.commitmentHashData forKey:quorumEntryEntity.quorumHashData] forKey:@(quorumEntryEntity.llmqType)];
        }
        
    }
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
    
    DSMasternodeList * baseMasternodeList = [self.masternodeListsByBlockHash objectForKey:uint256_data(baseBlockHash)];
    
    if (!baseMasternodeList) return;
    
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    DSDLog(@"baseBlockHash %@ (%@) blockHash %@ (%@)",uint256_hex(baseBlockHash),uint256_reverse_hex(baseBlockHash),uint256_hex(blockHash),uint256_reverse_hex(blockHash));
    
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
    [addedMasternodes removeObjectsForKeys:baseMasternodeList.reversedRegistrationTransactionHashes];
    NSMutableSet * modifiedMasternodeKeys = [NSMutableSet setWithArray:[addedOrModifiedMasternodes allKeys]];
    [modifiedMasternodeKeys intersectSet:[NSSet setWithArray:baseMasternodeList.reversedRegistrationTransactionHashes]];
    NSMutableDictionary * modifiedMasternodes = [NSMutableDictionary dictionary];
    for (NSData * data in modifiedMasternodeKeys) {
        [modifiedMasternodes setObject:addedOrModifiedMasternodes[data] forKey:data];
    }
    
    NSMutableDictionary * tentativeMasternodeList = [baseMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash mutableCopy];
    
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
    
    if (!rootMNListValid) {
        DSDLog(@"Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)",coinbaseTransaction.height,coinbaseTransaction.version,uint256_hex(coinbaseTransaction.merkleRootMNList),uint256_hex(merkleRootMNList));
    }
    
    DSMasternodeList * masternodeList = [DSMasternodeList masternodeListWithSimplifiedMasternodeEntriesDictionary:tentativeMasternodeList atBlockHash:blockHash onChain:self.chain];
    
    BOOL rootQuorumListValid = TRUE;
    
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
    
    NSMutableDictionary * tentativeQuorumList = [@{} mutableCopy];
    NSMutableArray * quorumsForDeletion = [@[] mutableCopy];
    
    NSMutableDictionary * addedQuorums = [NSMutableDictionary dictionary];
    
    if (foundCoinbase && validCoinbase && rootMNListValid && peer.version >= 70214) {
        if (length - offset < 1) return;
        NSNumber * deletedQuorumsCountLength;
        uint64_t deletedQuorumsCount = [message varIntAtOffset:offset length:&deletedQuorumsCountLength];
        offset += [deletedQuorumsCountLength unsignedLongValue];
        
        NSMutableDictionary * deletedQuorums = [NSMutableDictionary dictionary];
        
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
        
        NSMutableArray * llmqCommitmentHashes = [NSMutableArray array];
        
        while (addedQuorumsCount >= 1) {
            DSPotentialQuorumEntry * potentialQuorumEntry = [DSPotentialQuorumEntry potentialQuorumEntryWithData:message dataOffset:(uint32_t)offset onChain:self.chain];
            [potentialQuorumEntry validateWithMasternodeList:tentativeMasternodeList];
            DSDLog(@"%@",potentialQuorumEntry.data);
            if (![addedQuorums objectForKey:@(potentialQuorumEntry.llmqType)]) {
                [addedQuorums setObject:[NSMutableDictionary dictionaryWithObject:potentialQuorumEntry forKey:[NSData dataWithUInt256:potentialQuorumEntry.commitmentHash]] forKey:@(potentialQuorumEntry.llmqType)];
            } else {
                NSMutableDictionary * mutableLLMQDictionary = [addedQuorums objectForKey:@(potentialQuorumEntry.llmqType)];
                [mutableLLMQDictionary setObject:potentialQuorumEntry forKey:[NSData dataWithUInt256:potentialQuorumEntry.commitmentHash]];
            }
            [llmqCommitmentHashes addObject:[NSData dataWithUInt256:potentialQuorumEntry.commitmentHash]];
            offset += potentialQuorumEntry.length;
            addedQuorumsCount--;
        }
        
        for (NSNumber * number in self.quorumsDictionary) {
            tentativeQuorumList[number] = [self.quorumsDictionary[number] mutableCopy];
            if (deletedQuorums[number]) {
                //we need to translate from blockhash to commitment hash
                for (NSData * data in deletedQuorums[number]) {
                    NSData * commitmentHashData = self.quorumsBlockHashToCommitmentHashDictionary[number][data];
                    if (!commitmentHashData) {
                        DSDLog(@"Unknown quorum for block hash %@",data.reverse.hexString);
                    }
                    DSQuorumEntryEntity * quorumEntry = [tentativeQuorumList[number] objectForKey:commitmentHashData];
                    NSAssert(quorumEntry, @"quorum should be here already, though this might also be an attack from the remote node");
                    if (quorumEntry) {
                        [quorumsForDeletion addObject:quorumEntry];
                    }
                    [tentativeQuorumList[number] removeObjectForKey:commitmentHashData];
                }
            }
        }
        
        for (NSNumber * number in tentativeQuorumList) {
            for (NSData * commitmentHash in ((NSDictionary*)tentativeQuorumList[number]).allKeys) {
                [llmqCommitmentHashes addObject:commitmentHash];
            }
        }
        
        NSArray * sortedLlmqHashes = [llmqCommitmentHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            UInt256 hash1 = uint256_reverse([(NSData*)obj1 UInt256]);
            UInt256 hash2 = uint256_reverse([(NSData*)obj2 UInt256]);
            return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
        }];
        
        UInt256 merkleRootLLMQList = [[NSData merkleRootFromHashes:sortedLlmqHashes] UInt256];
        
        rootQuorumListValid = uint256_eq(coinbaseTransaction.merkleRootLLMQList, merkleRootLLMQList);
        
        if (!rootQuorumListValid) {
            DSDLog(@"Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)",coinbaseTransaction.height,coinbaseTransaction.version,uint256_hex(coinbaseTransaction.merkleRootLLMQList),uint256_hex(merkleRootLLMQList));
        }
        
    }
    
    if (foundCoinbase && validCoinbase && rootMNListValid && rootQuorumListValid) {
        //yay this is the correct masternode list verified deterministically
        [self.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(blockHash)];
        self.baseBlockHash = blockHash; //maybe remove this
        [self.chain updateAddressUsageOfSimplifiedMasternodeEntries:addedOrModifiedMasternodes.allValues];
        [self.managedObjectContext performBlockAndWait:^{
            //masternodes
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
                DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity simplifiedMasternodeEntryForProviderRegistrationTransactionHash:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash] onChain:chainEntity];
                [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry];
            }
            
            if (addedQuorums.count > 0 || quorumsForDeletion.count) {
                //quorums
                [DSQuorumEntryEntity setContext:self.managedObjectContext];
                [DSMerkleBlockEntity setContext:self.managedObjectContext];
                for (NSNumber * llmqType in addedQuorums) {
                    for (NSData * commitmentHash in addedQuorums[llmqType]) {
                        DSPotentialQuorumEntry * potentialQuorumEntry = addedQuorums[llmqType][commitmentHash];
                        DSQuorumEntryEntity * quorumEntry = [DSQuorumEntryEntity quorumEntryEntityFromPotentialQuorumEntry:potentialQuorumEntry];
                        NSAssert(quorumEntry, @"Quorum Entry must be created");
                        if (quorumEntry) {
                            if (!tentativeQuorumList[llmqType]) {
                                [tentativeQuorumList setObject:[@{quorumEntry.commitmentHashData:quorumEntry} mutableCopy] forKey:llmqType];
                            } else {
                                NSMutableDictionary * llmqsByType = [tentativeQuorumList objectForKey:llmqType];
                                [llmqsByType setObject:quorumEntry forKey:quorumEntry.commitmentHashData];
                            }
                        } else {
                            DSDLog(@"Quorum Entry not found for block %@",uint256_reverse_hex(potentialQuorumEntry.quorumHash));
                        }
                    }
                }
                
                for (DSQuorumEntryEntity * quorumEntry in quorumsForDeletion) {
                    [quorumEntry deleteObject];
                }
                self.quorumsDictionary = tentativeQuorumList;
            }
            chainEntity.baseBlockHash = [NSData dataWithUInt256:blockHash];
            NSError * error = [DSSimplifiedMasternodeEntryEntity saveContext];
            if (error) {
                chainEntity.baseBlockHash = uint256_data(self.chain.genesisHash);
                [DSLocalMasternodeEntity deleteAllOnChain:chainEntity];
                [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
                [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
                [self wipeMasternodeInfo];
                [DSSimplifiedMasternodeEntryEntity saveContext];
            }
        }];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
    } else {
        NSArray * faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        
        if (faultyPeers.count == MAX_FAULTY_DML_PEERS) {
            //no need to remove local masternodes
            self.baseBlockHash = self.chain.genesisHash;
            
            NSManagedObjectContext * context = [NSManagedObject context];
            [context performBlockAndWait:^{
                [DSChainEntity setContext:context];
                DSChainEntity * chainEntity = peer.chain.chainEntity;
                chainEntity.baseBlockHash = uint256_data(self.chain.genesisHash);
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
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDiffValidationErrorNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        });
        [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
    }
    
}

-(DSMasternodeList*)currentMasternodeList {
    return [self.masternodeListsByBlockHash objectForKey:uint256_data(self.baseBlockHash)];
}

-(NSUInteger)simplifiedMasternodeEntryCount {
    return [[self.masternodeListsByBlockHash objectForKey:uint256_data(self.baseBlockHash)] masternodeCount];
}

-(NSUInteger)quorumsCount {
    NSUInteger count = 0;
    for (NSNumber * type in self.quorumsBlockHashToCommitmentHashDictionary) {
        count += self.quorumsBlockHashToCommitmentHashDictionary[type].count;
    }
    return count;
}

-(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntryForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in [self.knownMasternodeDictionaryByReversedRegistrationTransactionHash allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return simplifiedMasternodeEntry;
        }
    }
    return nil;
}

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);
    
    return [self.knownMasternodeDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
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

-(DSQuorumEntry*)quorumEntryForInstantSendRequestID:(UInt256)requestID {
    __block DSQuorumEntry * quorumEntry = nil;
    [self.managedObjectContext performBlockAndWait:^{
        NSArray * quorumsForIS = [self.quorumsDictionary[@(1)] allValues];
        UInt256 lowestValue = UINT256_MAX;
        DSQuorumEntryEntity * firstQuorum;
        for (DSQuorumEntryEntity * quorumEntry in quorumsForIS) {
            UInt256 orderingHash = uint256_reverse([quorumEntry orderingHashForRequestID:requestID]);
            if (uint256_sup(lowestValue, orderingHash)) {
                lowestValue = orderingHash;
                firstQuorum = quorumEntry;
            }
        }
        quorumEntry = firstQuorum.quorumEntry;
    }];
    return quorumEntry;
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
