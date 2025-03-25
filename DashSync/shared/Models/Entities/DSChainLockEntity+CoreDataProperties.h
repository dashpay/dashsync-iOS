//
//  DSChainLockEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import "DSChainLockEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSChainLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainLockEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *signature;
@property (assign, nonatomic) BOOL validSignature;
@property (nullable, nonatomic, retain) DSMerkleBlockEntity *merkleBlock;
@property (nullable, nonatomic, retain) DSChainEntity *chainIfLastChainLock;

@end

NS_ASSUME_NONNULL_END
