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

#import "DPBaseObject.h"


#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import <TinyCborObjc/NSObject+DSCborEncoding.h>


@implementation DPBaseObject

- (void)resetSerializedValues {
    _serialized = nil;
    _serializedHash = nil;
    _serializedBaseData = nil;
    _serializedBaseDataHash = nil;
}

#pragma mark - DPPSerializableObject

@synthesize serialized = _serialized;
@synthesize serializedHash = _serializedHash;
@synthesize serializedBaseData = _serializedBaseData;
@synthesize serializedBaseDataHash = _serializedBaseDataHash;

- (DSMutableStringValueDictionary *)keyValueDictionary {
    NSAssert(NO, @"Should be overriden in subclass");
    return [DSMutableStringValueDictionary dictionary];
}

- (NSData *)serialized {
    if (_serialized == nil) {
        _serialized = [self.keyValueDictionary ds_cborEncodedObject];
    }
    return _serialized;
}

- (NSData *)serializedBaseData {
    if (_serializedBaseData == nil) {
        _serializedBaseData = [self.baseKeyValueDictionary ds_cborEncodedObject];
    }
    return _serializedBaseData;
}

- (NSData *)serializedHash {
    if (_serializedHash == nil) {
        _serializedHash = uint256_data([self.serialized SHA256_2]);
    }
    return _serializedHash;
}

- (NSData *)serializedBaseDataHash {
    if (_serializedBaseDataHash == nil) {
        _serializedBaseDataHash = uint256_data([self.serializedBaseData SHA256_2]);
    }
    return _serializedBaseDataHash;
}


@synthesize baseKeyValueDictionary;

@end
