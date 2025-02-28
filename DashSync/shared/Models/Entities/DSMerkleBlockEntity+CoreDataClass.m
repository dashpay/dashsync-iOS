//
//  DSMerkleBlockEntity+CoreDataClass.m
//
//  Created by Sam Westrich on 5/20/18.
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

#import "DSChain+Checkpoint.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLockEntity+CoreDataClass.h"
#import "DSCheckpoint.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSMerkleTree.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSMerkleBlockEntity

- (instancetype)setAttributesFromBlock:(DSBlock *)block forChainEntity:(DSChainEntity *)chainEntity {
    if ([block isKindOfClass:[DSMerkleBlock class]]) {
        return [self setAttributesFromMerkleBlock:(DSMerkleBlock *)block forChainEntity:chainEntity];
    }
    [self.managedObjectContext performBlockAndWait:^{
        self.blockHash = uint256_data(block.blockHash);
        self.version = block.version;
        self.prevBlock = uint256_data(block.prevBlock);
        self.merkleRoot = uint256_data(block.merkleRoot);
        self.timestamp = block.timestamp;
        self.target = block.target;
        self.nonce = block.nonce;
        self.totalTransactions = block.totalTransactions;
        self.height = block.height;
        self.chain = chainEntity;
        self.chainWork = uint256_data(block.chainWork);
        if (!self.chainLock && block.chainLocked && [block hasChainLockAwaitingSaving]) {
            [block saveAssociatedChainLock];
        }
        NSAssert((block.height == UINT32_MAX) == (uint256_is_zero(block.chainWork)), @"if block height is not set then there should be no aggregated work, and opposite is also true");
    }];

    return self;
}

- (instancetype)setAttributesFromMerkleBlock:(DSMerkleBlock *)block forChainEntity:(DSChainEntity *)chainEntity {
    [self.managedObjectContext performBlockAndWait:^{
        self.blockHash = uint256_data(block.blockHash);
        self.version = block.version;
        self.prevBlock = uint256_data(block.prevBlock);
        self.merkleRoot = uint256_data(block.merkleRoot);
        self.timestamp = block.timestamp;
        self.target = block.target;
        self.nonce = block.nonce;
        self.totalTransactions = block.totalTransactions;
        self.hashes = [NSData dataWithData:block.merkleTree.hashes];
        self.flags = [NSData dataWithData:block.merkleTree.flags];
        self.height = block.height;
        self.chain = chainEntity;
        self.chainWork = uint256_data(block.chainWork);
        if (!self.chainLock && block.chainLocked && [block hasChainLockAwaitingSaving]) {
            [block saveAssociatedChainLock];
        }
        NSAssert((block.height == UINT32_MAX) == (uint256_is_zero(block.chainWork)), @"if block height is not set then there should be no aggregated work, and opposite is also true");
    }];

    return self;
}

- (DSMerkleBlock *)merkleBlock {
    __block DSMerkleBlock *block = nil;

    [self.managedObjectContext performBlockAndWait:^{
        DSChain *chain = self.chain.chain;

        DSChainLock *chainLock = nil;
        if (self.chainLock) {
            chainLock = [self.chainLock chainLockForChain:chain];
        }
        block = [[DSMerkleBlock alloc] initWithVersion:self.version
                                             blockHash:self.blockHash.UInt256
                                             prevBlock:self.prevBlock.UInt256
                                            merkleRoot:self.merkleRoot.UInt256
                                             timestamp:self.timestamp
                                                target:self.target
                                             chainWork:self.chainWork.UInt256
                                                 nonce:self.nonce
                                     totalTransactions:self.totalTransactions
                                                hashes:self.hashes
                                                 flags:self.flags
                                                height:self.height
                                             chainLock:chainLock
                                               onChain:self.chain.chain];
    }];

    return block;
}

+ (NSArray<DSMerkleBlockEntity *> *)lastTerminalBlocks:(uint32_t)blockcount onChainEntity:(DSChainEntity *)chainEntity {
    __block NSArray *blocks = nil;
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [DSMerkleBlockEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(chain == %@)", chainEntity]];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:FALSE]]];
        [fetchRequest setFetchLimit:blockcount];
        blocks = [DSMerkleBlockEntity fetchObjects:fetchRequest inContext:chainEntity.managedObjectContext];
    }];
    return blocks;
}

+ (DSMerkleBlockEntity *)blockWithHash:(UInt256)hash onChainEntity:(DSChainEntity *)chainEntity {
    __block NSArray *blocks = nil;
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [DSMerkleBlockEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(chain == %@) && (blockHash == %@)", chainEntity, uint256_data(hash)]];
        [fetchRequest setFetchLimit:1];
        blocks = [DSMerkleBlockEntity fetchObjects:fetchRequest inContext:chainEntity.managedObjectContext];
    }];
    if (blocks.count) {
        return [blocks firstObject];
    } else {
        return nil;
    }
}

+ (void)deleteBlocksOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *merkleBlocksToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
        for (DSMerkleBlockEntity *merkleBlock in merkleBlocksToDelete) {
            [chainEntity.managedObjectContext deleteObject:merkleBlock];
        }
    }];
}

+ (instancetype)merkleBlockEntityForBlockHash:(NSData *)blockHash inContext:(NSManagedObjectContext *)context {
    return [DSMerkleBlockEntity anyObjectInContext:context matching:@"blockHash == %@", blockHash];
}

+ (instancetype)merkleBlockEntityForBlockHashFromCheckpoint:(UInt256)blockHash chain:(DSChain *)chain inContext:(NSManagedObjectContext *)context {
    DSCheckpoint *checkpoint = [chain checkpointForBlockHash:blockHash];
    if (checkpoint) {
        DSBlock *block = [checkpoint blockForChain:chain];
        DSChainEntity *chainEntity = [chain chainEntityInContext:context];
        return [[DSMerkleBlockEntity managedObjectInBlockedContext:context] setAttributesFromBlock:block forChainEntity:chainEntity];
    }
    return nil;
}

+ (instancetype)createMerkleBlockEntityForBlockHash:(NSData *)blockHash
                                        blockHeight:(uint32_t)blockHeight
                                        chainEntity:(DSChainEntity *)chainEntity
                                          inContext:(NSManagedObjectContext *)context {
    DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity managedObjectInBlockedContext:context];
    merkleBlockEntity.blockHash = blockHash;
    merkleBlockEntity.height = blockHeight;
    merkleBlockEntity.chain = chainEntity;
    return merkleBlockEntity;
}

@end
