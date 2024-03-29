//
//  DSMerkleBlockEntity+CoreDataClass.h
//
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

#import "BigIntTypes.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSChainEntity, DSBlock, DSChain, DSMerkleBlock, DSMasternodeListEntity, DSQuorumEntryEntity, DSQuorumSnapshotEntity, DSChainLockEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSMerkleBlockEntity : NSManagedObject

- (instancetype)setAttributesFromBlock:(DSBlock *)block forChainEntity:(DSChainEntity *)chainEntity;
- (instancetype)setAttributesFromMerkleBlock:(DSMerkleBlock *)merkleBlock forChainEntity:(DSChainEntity *)chainEntity; //this is faster when you know the chain entity already
- (DSMerkleBlock *)merkleBlock;

+ (NSArray<DSMerkleBlockEntity *> *)lastTerminalBlocks:(uint32_t)blockcount onChainEntity:(DSChainEntity *)chainEntity;
+ (DSMerkleBlockEntity *)blockWithHash:(UInt256)hash onChainEntity:(DSChainEntity *)chainEntity;
+ (void)deleteBlocksOnChainEntity:(DSChainEntity *)chainEntity;

+ (instancetype)merkleBlockEntityForBlockHash:(UInt256)blockHash inContext:(NSManagedObjectContext *)context;
+ (instancetype)merkleBlockEntityForBlockHashFromCheckpoint:(UInt256)blockHash chain:(DSChain *)chain inContext:(NSManagedObjectContext *)context;
+ (instancetype)createMerkleBlockEntityForBlockHash:(UInt256)blockHash
                                        blockHeight:(uint32_t)blockHeight
                                        chainEntity:(DSChainEntity *)chainEntity
                                          inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "DSMerkleBlockEntity+CoreDataProperties.h"
