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

#import "DSUInt256IndexPath.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSUInt256IndexPath

+ (instancetype)indexPathWithIndex:(UInt256)index {
    return [[DSUInt256IndexPath alloc] initWithIndex:index];
}

+ (instancetype)indexPathWithIndexes:(const UInt256[_Nullable])indexes length:(NSUInteger)length {
    return [[DSUInt256IndexPath alloc] initWithIndexes:indexes length:length];
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes length:(NSUInteger)length {
    self = [super init];
    if (self) {
        _length = length;
        _indexes = NULL;
        if (length > 0) {
            const size_t size = sizeof(UInt256);
            const size_t memorySize = length * size;
            _indexes = calloc(memorySize, size);
            if (_indexes == NULL) {
                @throw [NSException exceptionWithName:NSMallocException
                                               reason:@"DSUInt256IndexPath could not allocate memory"
                                             userInfo:nil];
            }
            memcpy(_indexes, indexes, memorySize);
        }
    }
    return self;
}

- (instancetype)initWithIndex:(UInt256)index {
    return [self initWithIndexes:&index length:1];
}

- (instancetype)init {
    return [self initWithIndexes:NULL length:0];
}

- (instancetype)_initWithIndexesNoCopy:(UInt256 *)indexes length:(NSUInteger)length {
    self = [self init];
    if (self) {
        _indexes = indexes;
        _length = length;
    }
    return self;
}

- (void)dealloc {
    if (_indexes != NULL) {
        free(_indexes);
    }
}

- (DSUInt256IndexPath *)indexPathByAddingIndex:(UInt256)index {
    const size_t size = sizeof(UInt256);
    const size_t memorySize = (_length + 1) * size;
    UInt256 *indexes = calloc(memorySize, size);
    if (indexes == NULL) {
        @throw [NSException exceptionWithName:NSMallocException
                                       reason:@"DSUInt256IndexPath could not allocate memory"
                                     userInfo:nil];
    }

    if (_length > 0) {
        memcpy(indexes, _indexes, _length * size);
    }
    indexes[_length] = index;

    return [[DSUInt256IndexPath alloc] _initWithIndexesNoCopy:indexes length:_length + 1];
}

- (DSUInt256IndexPath *)indexPathByRemovingLastIndex {
    if (_length > 0) {
        return [[DSUInt256IndexPath alloc] initWithIndexes:_indexes length:_length - 1];
    }
    else {
        return [[DSUInt256IndexPath alloc] init];
    }
}

- (UInt256)indexAtPosition:(NSUInteger)position {
    if (position >= _length) {
        return UINT256_MAX;
    }
    return _indexes[position];
}

- (NSUInteger)length {
    return _length;
}

- (void)getIndexes:(UInt256 *)indexes range:(NSRange)positionRange {
    if (positionRange.location == NSNotFound || positionRange.location + positionRange.length >= _length) {
        NSString *reason = [NSString stringWithFormat:@"Range '%@' is out of indexes length '%ld'",
                                                      NSStringFromRange(positionRange), _length];
        @throw [NSException exceptionWithName:NSRangeException reason:reason userInfo:nil];
    }

    const size_t size = sizeof(UInt256);
    const size_t memorySize = positionRange.length * size;
    memcpy(indexes, &_indexes[positionRange.location], memorySize);
}

- (NSComparisonResult)compare:(DSUInt256IndexPath *)otherObject {
    const NSUInteger length1 = _length;
    const NSUInteger length2 = otherObject.length;
    for (NSUInteger pos = 0; pos < MIN(length1, length2); pos++) {
        const UInt256 idx1 = [self indexAtPosition:pos];
        const UInt256 idx2 = [otherObject indexAtPosition:pos];
        if (idx1.u64[0] < idx2.u64[0] ||
            idx1.u64[1] < idx2.u64[1] ||
            idx1.u64[2] < idx2.u64[2] ||
            idx1.u64[3] < idx2.u64[3]) {

            return NSOrderedAscending;
        }
        else if (idx1.u64[0] > idx2.u64[0] ||
                 idx1.u64[1] > idx2.u64[1] ||
                 idx1.u64[2] > idx2.u64[2] ||
                 idx1.u64[3] > idx2.u64[3]) {

            return NSOrderedDescending;
        }
    }

    if (length1 < length2) {
        return NSOrderedAscending;
    }
    else if (length1 > length2) {
        return NSOrderedDescending;
    }

    return NSOrderedSame;
}

#pragma mark - NSObject

// Preventing hash collisions:
// https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html
#define DSUINT_BIT (CHAR_BIT * sizeof(NSUInteger))
#define DSUINTROTATE(val, howmuch) ((((NSUInteger)val) << howmuch) | (((NSUInteger)val) >> (DSUINT_BIT - howmuch)))

- (NSUInteger)hash {
    if (_hash == 0) {
        const NSUInteger length = _length;
        NSUInteger hash = length;
        for (NSUInteger i = 0; i < length; i++) {
            UInt256 index = _indexes[i];
            hash += DSUINTROTATE(index.u64[0] ^ index.u64[1], DSUINT_BIT / 2) ^
                    DSUINTROTATE(index.u64[2] ^ index.u64[3], DSUINT_BIT / 2);
        }
        _hash = hash;
    }

    return _hash;
}

- (BOOL)isEqualToUInt256IndexPath:(DSUInt256IndexPath *)otherIndexPath {
    return ([self compare:otherIndexPath] == NSOrderedSame);
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[DSUInt256IndexPath class]]) {
        return NO;
    }

    return [self isEqualToUInt256IndexPath:(DSUInt256IndexPath *)object];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> {length = %ld}",
                                      NSStringFromClass([self class]), self, _length];
}

#pragma mark - NSCoding

#define DS_NSCODING_KEY @"indexes"

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];
    if (self) {
        NSUInteger memorySize;
        const size_t size = sizeof(UInt256);
        const uint8_t *bytes = [aDecoder decodeBytesForKey:DS_NSCODING_KEY returnedLength:&memorySize];
        if (bytes) {
            _length = memorySize / size;
            _indexes = calloc(memorySize, size);
            if (_indexes == NULL) {
                @throw [NSException exceptionWithName:NSMallocException
                                               reason:@"DSUInt256IndexPath could not allocate memory"
                                             userInfo:nil];
            }
            memcpy(_indexes, bytes, memorySize);
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (_indexes != NULL) {
        const NSUInteger memorySize = sizeof(UInt256) * _length;
        [aCoder encodeBytes:(void *)_indexes length:memorySize forKey:DS_NSCODING_KEY];
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    // According to documentation:
    // Implement NSCopying by retaining the original instead of creating a new copy when the class and its contents are immutable.
    return self;
}

@end

NS_ASSUME_NONNULL_END
