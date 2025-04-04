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
    DCoinJoinClientOptions *options = DCoinJoinClientOptionsCtor(YES, DUFFS_OBJC / 4, 1, 1, COINJOIN_RANDOM_ROUNDS, DEFAULT_COINJOIN_DENOMS_GOAL, DEFAULT_COINJOIN_DENOMS_HARDCAP, NO, DChainTypeMainnet(), NO);
    DCoinJoinClientOptionsDtor(options);
}

@end
