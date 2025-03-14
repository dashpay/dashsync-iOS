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

#import <XCTest/XCTest.h>
#import "DSInstantSendTransactionLock.h"
#import "NSData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSInstantSendLockTests : XCTestCase

@end

@implementation DSInstantSendLockTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

//- (void)testInstantISDLock {
//    DSChain *chain = [DSChain testnet];
//    NSData *payload = @"010101102862a43d122e6675aba4b507ae307af8e1e17febc77907e08b3efa28f41b000000004b446de00a592c67402c0a65649f4ad69f29084b3e9054f5aa6b85a50b497fe136a56617591a6a89237bada6af1f9b46eba47b5d89a8c4e49ff2d0236182307c85e12d70ca7118c5034004f93e45384079f46c6c2928b45cfc5d3ad640e70dfd87a9a3069899adfb3b1622daeeead19809b74354272ccf95290678f55c13728e3c5ee8f8417fcce3dfdca2a7c9c33ec981abdff1ec35a2e4b558c3698f01c1b8".hexToData;
//    DSInstantSendTransactionLock *lock = [DSInstantSendTransactionLock instantSendTransactionLockWithDeterministicMessage:payload onChain:chain];
//    NSLog(@"version: %d", lock.version);
//    NSLog(@"cycleHash: %@", uint256_hex(lock.cycleHash));
//    NSLog(@"txHash: %@", uint256_hex(lock.transactionHash));
//    NSLog(@"signature: %@", uint768_hex(lock.signature));
//    XCTAssertEqual(lock.version, 1, @"Version");
//    XCTAssertTrue(uint256_eq(lock.cycleHash, @"36a56617591a6a89237bada6af1f9b46eba47b5d89a8c4e49ff2d0236182307c".hexToData.UInt256), @"cycleHash");
//    XCTAssertTrue(uint256_eq(lock.transactionHash, @"4b446de00a592c67402c0a65649f4ad69f29084b3e9054f5aa6b85a50b497fe1".hexToData.UInt256), @"txHash");
//    XCTAssertTrue(uint768_eq(lock.signature, @"85e12d70ca7118c5034004f93e45384079f46c6c2928b45cfc5d3ad640e70dfd87a9a3069899adfb3b1622daeeead19809b74354272ccf95290678f55c13728e3c5ee8f8417fcce3dfdca2a7c9c33ec981abdff1ec35a2e4b558c3698f01c1b8".hexToData.UInt768), @"TxHash");
//
//    XCTAssertTrue(uint256_eq(lock.requestID, @"495be44677e82895a9396fef02c6e9afc1f01d4aff70622b9f78e0e10d57064c".hexToData.reverse.UInt256), @"requestID invalid");
//
//}

@end
