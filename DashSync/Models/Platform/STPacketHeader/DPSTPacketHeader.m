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

#import "DPSTPacketHeader.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DPSTPacketHeader

- (instancetype)initWithContractId:(NSString *)contractId
                   itemsMerkleRoot:(NSString *)itemsMerkleRoot
                         itemsHash:(NSString *)itemsHash {
    NSParameterAssert(contractId);
    NSParameterAssert(itemsMerkleRoot);
    NSParameterAssert(itemsHash);

    self = [super init];
    if (self) {
        _contractId = [contractId copy];
        _itemsMerkleRoot = [itemsMerkleRoot copy];
        _itemsHash = [itemsHash copy];
    }
    return self;
}

- (void)setContractId:(NSString *)contractId {
    _contractId = [contractId copy];
    [self resetSerializedValues];
}

- (void)setItemsMerkleRoot:(NSString *)itemsMerkleRoot {
    _itemsMerkleRoot = [itemsMerkleRoot copy];
    [self resetSerializedValues];
}

- (void)setItemsHash:(NSString *)itemsHash {
    _itemsHash = [itemsHash copy];
    [self resetSerializedValues];
}

- (void)resetSerializedValues {
    [super resetSerializedValues];
    _json = nil;
}

#pragma mark - DPPSerializableObject

@synthesize json = _json;

- (DPMutableJSONObject *)json {
    if (_json == nil) {
        DPMutableJSONObject *json = [[DPMutableJSONObject alloc] init];
        json[@"contractId"] = self.contractId;
        json[@"itemsMerkleRoot"] = self.itemsMerkleRoot;
        json[@"itemsHash"] = self.itemsHash;
        _json = json;
    }
    return _json;
}

@end

NS_ASSUME_NONNULL_END
