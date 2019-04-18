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

#import <Foundation/Foundation.h>

#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSUInt256IndexPath : NSObject <NSCopying, NSCoding> {
    @private
    UInt256 *_indexes;
    NSUInteger _hash;
    NSUInteger _length;
}

+ (instancetype)indexPathWithIndex:(UInt256)index;

+ (instancetype)indexPathWithIndexes:(const UInt256 [_Nullable])indexes length:(NSUInteger)length;

- (instancetype)initWithIndexes:(const UInt256 [_Nullable])indexes length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSingleIndex:(UInt256)index;

- (DSUInt256IndexPath *)indexPathByAddingIndex:(UInt256)index;
- (DSUInt256IndexPath *)indexPathByRemovingLastIndex;

- (UInt256)indexAtPosition:(NSUInteger)position;
@property (readonly) NSUInteger length;

- (void)getIndexes:(UInt256 *)indexes range:(NSRange)positionRange;

- (NSComparisonResult)compare:(DSUInt256IndexPath *)otherObject;

@end

NS_ASSUME_NONNULL_END
