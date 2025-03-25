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
@property (nullable, nonatomic, retain) NSData *chainWork;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSChainLockEntity *chainLock;

@end

NS_ASSUME_NONNULL_END
