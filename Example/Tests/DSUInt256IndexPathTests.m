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

#import <XCTest/XCTest.h>

#import <DashSync/DSUInt256IndexPath.h>

@interface DSUInt256IndexPathTests : XCTestCase

@end

@implementation DSUInt256IndexPathTests

- (void)testEmptyIndexPath {
    DSUInt256IndexPath *indexPath = [[DSUInt256IndexPath alloc] init];
    XCTAssert(indexPath.length == 0);
    XCTAssert(indexPath.hash == 0);
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:indexPath];
    XCTAssertNotNil(data);
    
    DSUInt256IndexPath *indexPathDecoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    BOOL equals = [indexPath isEqual:indexPathDecoded];
    XCTAssert(equals);
    
    indexPath = [indexPath indexPathByRemovingLastIndex];
    XCTAssert(indexPath.length == 0);
    
    UInt256 index = [indexPath indexAtPosition:1];
    XCTAssert(uint256_eq(index, UINT256_MAX));
    
    indexPath = [indexPath indexPathByAddingIndex:((UInt256){.u64 = {1, 2, 3, 4}})];
    XCTAssert(indexPath.length == 1);
}

- (void)testManyElements {
    NSUInteger maxIndexesCount = 1000;
    for (NSUInteger length = 1; length < maxIndexesCount; length++) {
        @autoreleasepool {
            UInt256 *indexes = [self generateIndexesForLength:length];
            [self performTestsForIndexes:indexes length:length];
        }
    }
}

- (void)testCompareElements {
    UInt256 first[2] = {
        ((UInt256){.u64 = {1, 2, 3, 4}}),
        ((UInt256){.u64 = {2, 3, 4, 5}}),
    };
    UInt256 second[2] = {
        ((UInt256){.u64 = {5, 6, 7, 8}}),
        ((UInt256){.u64 = {6, 7, 8, 9}}),
    };
    
    DSUInt256IndexPath *firstIndexPath = [DSUInt256IndexPath indexPathWithIndexes:first length:2];
    DSUInt256IndexPath *secondIndexPath = [DSUInt256IndexPath indexPathWithIndexes:second length:2];
    
    NSComparisonResult result = [firstIndexPath compare:secondIndexPath];
    XCTAssert(result == NSOrderedAscending);
    
    result = [secondIndexPath compare:firstIndexPath];
    XCTAssert(result == NSOrderedDescending);
}

#pragma mark - Private

- (void)performTestsForIndexes:(UInt256 *)indexes length:(NSUInteger)length {
    DSUInt256IndexPath *indexPath = [DSUInt256IndexPath indexPathWithIndexes:indexes length:length];
    
    // Basic
    
    XCTAssert(indexPath.length == length, @"Failed for length %ld", length);
    XCTAssert(indexPath.hash != 0, @"Failed for length %ld", length);
    
    for (NSUInteger i = 0; i < length; i++) {
        UInt256 inIndex = indexes[i];
        UInt256 index = [indexPath indexAtPosition:i];
        XCTAssert(uint256_eq(inIndex, index), @"Failed for length %ld", length);
    }
    
    // NSCoding, isEqual
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:indexPath];
    XCTAssertNotNil(data, @"Failed for length %ld", length);
    
    DSUInt256IndexPath *indexPathDecoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    BOOL equals = [indexPath isEqual:indexPathDecoded];
    XCTAssert(equals, @"Failed for length %ld", length);
    
    // Methods
    
    UInt256 index = [self randomUInt256];
    DSUInt256IndexPath *newIndexPath = [indexPath indexPathByAddingIndex:index];
    UInt256 returnedIndex = [newIndexPath indexAtPosition:length];
    XCTAssert(uint256_eq(returnedIndex, index), @"Failed for length %ld", length);
    
    newIndexPath = [newIndexPath indexPathByRemovingLastIndex];
    XCTAssert(newIndexPath.hash == indexPath.hash, @"Failed for length %ld", length);
    
    if (length > 2) {
        NSUInteger sliceLength = length - 2;
        NSRange range = NSMakeRange(1, sliceLength);
        UInt256 outIndexes[sliceLength];
        [indexPath getIndexes:outIndexes range:range];
        
        newIndexPath = [DSUInt256IndexPath indexPathWithIndexes:outIndexes length:sliceLength];
        XCTAssert(newIndexPath.length == sliceLength, @"Failed for length %ld", length);
    }
}

- (UInt256 *)generateIndexesForLength:(NSUInteger)length {
    size_t size = sizeof(UInt256);
    size_t memorySize = length * size;
    UInt256 *indexes = calloc(memorySize, size); // creates array in heap
    
    for (NSUInteger i = 0; i < length; i++) {
        indexes[i] = [self randomUInt256];
    }
    
    return indexes;
}

- (UInt256)randomUInt256 {
    return ((UInt256){.u32 = {
        arc4random(),
        arc4random(),
        arc4random(),
        arc4random(),
        arc4random(),
        arc4random(),
        arc4random(),
        arc4random()
    }});
}

@end
