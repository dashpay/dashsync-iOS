//
//  DSMerkleBlockEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 6/11/19.
//
//

#import "DSMerkleBlockEntity+CoreDataProperties.h"

@implementation DSMerkleBlockEntity (CoreDataProperties)

+ (NSFetchRequest<DSMerkleBlockEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSMerkleBlockEntity"];
}

@dynamic blockHash;
@dynamic flags;
@dynamic hashes;
@dynamic height;
@dynamic merkleRoot;
@dynamic nonce;
@dynamic prevBlock;
@dynamic target;
@dynamic timestamp;
@dynamic totalTransactions;
@dynamic version;
@dynamic chain;
@dynamic masternodeList;
@dynamic usedByQuorums;

@end
