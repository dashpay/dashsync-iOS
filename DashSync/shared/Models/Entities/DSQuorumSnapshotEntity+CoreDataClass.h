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

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import "DSChainEntity+CoreDataProperties.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSQuorumSnapshot.h"
#import "dash_shared_core.h"

@class DSChainEntity, DSMerkleBlockEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumSnapshotEntity : NSManagedObject

+ (instancetype)quorumSnapshotEntityFromPotentialQuorumSnapshot:(DSQuorumSnapshot *)potentialQuorumSnapshot inContext:(NSManagedObjectContext *)context;
+ (instancetype)quorumSnapshotEntityForMerkleBlockEntity:(DSMerkleBlockEntity *)blockEntity quorumSnapshot:(DSQuorumSnapshot *)quorumSnapshot inContext:(NSManagedObjectContext *)context;
+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity;

- (void)updateAttributesFromPotentialQuorumSnapshot:(DSQuorumSnapshot *)quorumSnapshot onBlock:(DSMerkleBlockEntity *) block;

@end

NS_ASSUME_NONNULL_END

#import "DSQuorumSnapshotEntity+CoreDataProperties.h"
