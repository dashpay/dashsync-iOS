//  
//  Created by Sam Westrich
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
#import <DashSync/DashSync.h>

@interface DSBigNumberTests : XCTestCase

@end

@implementation DSBigNumberTests

- (void)testSuperiorAndEqualUInt256 {
    NSUInteger a = 7;
    NSUInteger b = 5;
    UInt256 bigA = uint256_from_long(a);
    UInt256 bigB = uint256_from_long(b);
    XCTAssert(uint256_sup(bigA, bigB),@"A in uint 256 needs to be bigger than B");
    
    UInt256 bigC = ((UInt256) { .u64 = { 0, 1, 0, 0 } });
    XCTAssert(uint256_sup(bigC, bigA),@"C in uint 256 needs to be bigger than A");
    
    uint64_t d = 1 << 30;
    UInt256 bigD = uint256_from_long(d);
    UInt256 bigDLeftShifted = uInt256ShiftLeftLE(bigD, 34);
    XCTAssert(uint256_eq(bigC, bigDLeftShifted),@"C and D should be equal");
    
    uint32_t e = 1 << 30;
    UInt256 bigE = uint256_from_int(e);
    UInt256 bigELeftShifted = uInt256ShiftLeftLE(bigE, 34);
    XCTAssert(uint256_eq(bigELeftShifted, bigDLeftShifted),@"D and E should be equal");
}

@end
