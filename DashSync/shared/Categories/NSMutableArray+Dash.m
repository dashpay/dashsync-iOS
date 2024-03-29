//
//  Created by Sam Westrich
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

#import "NSMutableArray+Dash.h"
#import "NSMutableData+Dash.h"

@implementation NSMutableArray (Dash)

+ (NSMutableArray *)secureArrayWithArray:(NSArray *)array {
    return CFBridgingRelease(CFArrayCreateMutableCopy(SecureAllocator(), 0, (CFArrayRef)array));
}

- (NSMutableArray *)compactMap:(id (^)(id obj))block {
    NSMutableArray *result = [NSMutableArray array];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mObj = block(obj);
        if (mObj && mObj != [NSNull null]) {
            [result addObject:mObj];
        }
    }];
    return result;
}

- (NSMutableArray *)map:(id (^)(id obj))block {
    NSParameterAssert(block != nil);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:block(obj) ?: [NSNull null]];
    }];
    return result;
}

@end
