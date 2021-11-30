//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSMasternodeDiffMessageContext.h"
#import "NSData+Dash.h"

@implementation DSMasternodeDiffMessageContext

@end

@implementation DSTestStructContext

- (instancetype)initWith:(TestStruct *)testStruct {
    if (!(self = [super init])) return nil;
    NSLog(@"DSTestStructContext.initWith %p", testStruct);
    self.height = testStruct->height;
    NSLog(@"DSTestStructContext height: %u", testStruct->height);
    NSData *hashData = [NSData dataWithBytes:testStruct->hash length:32];
    self.testHash = hashData.UInt256;
    NSLog(@"DSTestStructContext hash: %p: %@", testStruct->hash, hashData.hexString);
    uintptr_t keys_count = testStruct->keys_count;
    NSLog(@"DSTestStructContext keys_count: %lu", keys_count);
    NSMutableArray<NSData *> *hashes = [NSMutableArray array];
    for (int i = 0; i < keys_count; i++) {
        uint8_t(*key)[32] = testStruct->keys[i];
        NSData *hashData = [NSData dataWithBytes:key length:32];
        NSLog(@"DSTestStructContext key[%i]: %p: %@", i, key, hashData.hexString);
        [hashes addObject:hashData];
    }
    self.keys = hashes;
    NSLog(@"DSTestStructContext keys: %p", hashes);
    return self;
}

@end
