//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSQuorumSnapshotEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "NSData+Dash.h"
@implementation DSQuorumSnapshotEntity


+ (instancetype)quorumSnapshotEntityFromPotentialQuorumSnapshot:(DSQuorumSnapshot *)potentialQuorumSnapshot inContext:(NSManagedObjectContext *)context {
    UInt256 quorumSnapshotBlockHash = potentialQuorumSnapshot.blockHash;
    DSMerkleBlockEntity *block = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:quorumSnapshotBlockHash inContext:context];
    DSQuorumSnapshotEntity *quorumSnapshotEntity = nil;
    if (block) {
        quorumSnapshotEntity = block.quorumSnapshot;
    }
    if (!quorumSnapshotEntity) {
        quorumSnapshotEntity = [DSQuorumSnapshotEntity managedObjectInBlockedContext:context];
        [quorumSnapshotEntity updateAttributesFromPotentialQuorumSnapshot:potentialQuorumSnapshot onBlock:block];
    } else {
        [quorumSnapshotEntity updateAttributesFromPotentialQuorumSnapshot:potentialQuorumSnapshot onBlock:block];
    }

    return quorumSnapshotEntity;
}

+ (instancetype)quorumSnapshotEntityForMerkleBlockEntity:(DSMerkleBlockEntity *)blockEntity quorumSnapshot:(DSQuorumSnapshot *)quorumSnapshot inContext:(NSManagedObjectContext *)context {
    NSArray *objects = [DSQuorumSnapshotEntity objectsForPredicate:[NSPredicate predicateWithFormat:@"block = %@", blockEntity] inContext:context];
    DSQuorumSnapshotEntity *entity = NULL;
    if (objects.count) {
        NSAssert(objects.count == 1, @"There should only ever be 1 quorum snapshot for either mainnet, testnet, or a devnet Identifier");
        entity = objects[0];

    } else {
        entity = [self managedObjectInBlockedContext:context];
    }
    [entity updateAttributesFromPotentialQuorumSnapshot:quorumSnapshot onBlock:blockEntity];
    return entity;
}

- (void)updateAttributesFromPotentialQuorumSnapshot:(DSQuorumSnapshot *)quorumSnapshot onBlock:(DSMerkleBlockEntity *) block {
    self.block = block;
    NSError *error = nil;
    NSData *archivedMemberList = [NSKeyedArchiver archivedDataWithRootObject:quorumSnapshot.memberList requiringSecureCoding:YES error:&error];
    NSAssert(error == nil, @"There should not be an error when decrypting memberList");
    if (!error) {
        self.memberList = archivedMemberList;
    }
    NSData *archivedSkipList = [NSKeyedArchiver archivedDataWithRootObject:quorumSnapshot.skipList requiringSecureCoding:YES error:&error];
    NSAssert(error == nil, @"There should not be an error when decrypting skipList");
    if (!error) {
        self.skipList = archivedSkipList;
    }
    self.skipListMode = quorumSnapshot.skipListMode;
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *quorumSnapshots = [self objectsInContext:chainEntity.managedObjectContext matching:@"(block.chain == %@)", chainEntity];
    for (DSQuorumSnapshotEntity *quorumSnapshot in quorumSnapshots) {
        [chainEntity.managedObjectContext deleteObject:quorumSnapshot];
    }
}

@end
