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


#import "NSData+Bitcoin.h"
#import "BigIntTypes.h"
#import <TinyCborObjc/NSObject+DSCborEncoding.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DPBaseObject

- (void)resetSerializedValues {
    _serialized = nil;
    _serializedHash = nil;
}

#pragma mark - DPPSerializableObject

@synthesize serialized = _serialized;
@synthesize serializedHash = _serializedHash;

- (DPMutableJSONObject *)json {
    NSAssert(NO, @"Should be overriden in subclass");
    return [DPMutableJSONObject dictionary];
}

- (NSData *)serialized {
    if (_serialized == nil) {
        _serialized = [self.json ds_cborEncodedObject];
    }
    return _serialized;
}

- (NSData *)serializedHash {
    if (_serializedHash == nil) {
        _serializedHash = uint256_data([self.serialized SHA256_2]);
    }
    return _serializedHash;
}

@end

NS_ASSUME_NONNULL_END
