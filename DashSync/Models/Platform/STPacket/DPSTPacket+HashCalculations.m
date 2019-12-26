//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DPSTPacket+HashCalculations.h"

#import "DPSerializeUtils.h"
#import <TinyCborObjc/NSObject+DSCborEncoding.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DPSTPacket (HashCalculations)

- (nullable NSString *)dp_calculateItemsMerkleRootWithOperation:(id<DPMerkleRootOperation>)merkleRootOperation {
    NSArray<NSData *> *documentsHashes = [self dp_calculateDocumentsHashes];
    NSArray<NSData *> *contractsHashes = [self dp_calculateContractsHashes];

    // Always concatenate arrays in bitwise order of their names
    NSArray *itemsHashes = [contractsHashes arrayByAddingObjectsFromArray:documentsHashes];
    if (itemsHashes.count == 0) {
        return nil;
    }

    NSData *merkleRootData = [merkleRootOperation merkleRootFromHashes:itemsHashes];
    if (!merkleRootData) {
        return nil;
    }

    NSString *hash = [merkleRootData ds_hexStringFromData];

    return hash;
}

- (nullable NSString *)dp_calculateItemsHash {
    NSArray<NSData *> *documentsHashes = [self dp_calculateDocumentsHashes];
    NSArray<NSData *> *contractsHashes = [self dp_calculateContractsHashes];
    if (documentsHashes.count == 0 && contractsHashes.count == 0) {
        return nil;
    }

    NSDictionary<NSString *, NSArray *> *itemsHashesDictionary = @{
        @"documents" : documentsHashes,
        @"contracts" : contractsHashes,
    };

    NSString *hash = [DPSerializeUtils serializeAndHashObjectToString:itemsHashesDictionary];

    return hash;
}

#pragma mark - Private

- (NSArray<NSData *> *)dp_calculateDocumentsHashes {
    NSMutableArray<NSData *> *hashes = [NSMutableArray array];
    for (DPDocument *document in self.documents) {
        [hashes addObject:document.serializedHash];
    }

    return [hashes copy];
}

- (NSArray<NSData *> *)dp_calculateContractsHashes {
    NSMutableArray<NSData *> *hashes = [NSMutableArray array];
    for (DPContract *contract in self.contracts) {
        [hashes addObject:contract.serializedHash];
    }

    return [hashes copy];
}

@end

NS_ASSUME_NONNULL_END
