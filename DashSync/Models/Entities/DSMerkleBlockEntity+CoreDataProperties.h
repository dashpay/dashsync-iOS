//
//  DSMerkleBlockEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/11/19.
//
//

#import "DSMerkleBlockEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSMerkleBlockEntity (CoreDataProperties)

+ (NSFetchRequest<DSMerkleBlockEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *blockHash;
@property (nullable, nonatomic, retain) NSData *flags;
@property (nullable, nonatomic, retain) NSData *hashes;
@property (nonatomic, assign) int32_t height;
@property (nullable, nonatomic, retain) NSData *merkleRoot;
@property (nonatomic, assign) int32_t nonce;
@property (nullable, nonatomic, retain) NSData *prevBlock;
@property (nonatomic, assign) int32_t target;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) int32_t totalTransactions;
@property (nonatomic, assign) int32_t version;
@property (nullable, nonatomic, retain) NSData *aggregateWork;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSChainLockEntity *chainLock;
@property (nullable, nonatomic, retain) DSMasternodeListEntity *masternodeList;
@property (nullable, nonatomic, retain) NSSet<DSQuorumEntryEntity *> *usedByQuorums;

@end

@interface DSMerkleBlockEntity (CoreDataGeneratedAccessors)

- (void)addQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)removeQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)addQuorums:(NSSet<DSQuorumEntryEntity *> *)values;
- (void)removeQuorums:(NSSet<DSQuorumEntryEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
