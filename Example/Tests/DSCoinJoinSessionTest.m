//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

@interface DSCoinJoinSessionTest : XCTestCase

@end

@implementation DSCoinJoinSessionTest

- (void)sessionTest {
    CoinJoinClientOptions *options = malloc(sizeof(CoinJoinClientOptions));
    options->enable_coinjoin = YES;
    options->coinjoin_rounds = 1;
    options->coinjoin_sessions = 1;
    options->coinjoin_amount = DUFFS / 4; // 0.25 DASH
    options->coinjoin_random_rounds = COINJOIN_RANDOM_ROUNDS;
    options->coinjoin_denoms_goal = DEFAULT_COINJOIN_DENOMS_GOAL;
    options->coinjoin_denoms_hardcap = DEFAULT_COINJOIN_DENOMS_HARDCAP;
    options->coinjoin_multi_session = NO;

    
    
    
    NSUInteger a = 7;
    NSUInteger b = 5;
    UInt256 bigA = uint256_from_long(a);
    UInt256 bigB = uint256_from_long(b);
    XCTAssert(uint256_sup(bigA, bigB), @"A in uint 256 needs to be bigger than B");

    UInt256 bigC = ((UInt256){.u64 = {0, 1, 0, 0}});
    XCTAssert(uint256_sup(bigC, bigA), @"C in uint 256 needs to be bigger than A");

    uint64_t d = 1 << 30;
    UInt256 bigD = uint256_from_long(d);
    UInt256 bigDLeftShifted = uInt256ShiftLeftLE(bigD, 34);
    XCTAssert(uint256_eq(bigC, bigDLeftShifted), @"C and D should be equal");

    uint32_t e = 1 << 30;
    UInt256 bigE = uint256_from_int(e);
    UInt256 bigELeftShifted = uInt256ShiftLeftLE(bigE, 34);
    XCTAssert(uint256_eq(bigELeftShifted, bigDLeftShifted), @"D and E should be equal");
    
    
    free(options);
}

@end
