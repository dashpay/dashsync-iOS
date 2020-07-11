//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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
#import "DSChain+Protected.h"
#import "NSData+Dash.h"
#import "DSChainManager.h"
#import "DSFullBlock.h"

@interface DSMiningTests : XCTestCase

@property (nonatomic,strong) DSChain * chain;

@end

@implementation DSMiningTests

- (void)setUp {
    self.chain = [DSChain setUpDevnetWithIdentifier:@"miningTest" withCheckpoints:nil withDefaultPort:3000 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO isTransient:YES];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMiningTwice {
    [self.chain.chainManager mineBlockWithTransactions:[NSArray array] withTimeout:10000 completion:^(DSFullBlock * _Nonnull block0, NSUInteger attempts, NSTimeInterval timeUsed, NSError * _Nonnull error) {
        BOOL success0 = [self.chain addBlock:block0 fromPeer:nil];
        XCTAssertTrue(success0);
        [self.chain.chainManager mineBlockWithTransactions:[NSArray array] withTimeout:10000 completion:^(DSFullBlock * _Nonnull block1, NSUInteger attempts, NSTimeInterval timeUsed, NSError * _Nonnull error) {
            BOOL success1 = [self.chain addBlock:block1 fromPeer:nil];
            XCTAssertTrue(success1);
            XCTAssertTrue(self.chain.lastTerminalBlockHeight == 3);
        }];
    }];
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
