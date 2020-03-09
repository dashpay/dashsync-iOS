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
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"

@interface DSAttackTests : XCTestCase

@end

@implementation DSAttackTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGrindingAttack {
//    UInt256 randomNumber = uint256_RANDOM;
//    UInt256 seed = uint256_RANDOM;
//    NSUInteger maxDepth = 0;
//    NSTimeInterval timeToRun = 360;
//    NSDate * startTime = [NSDate date];
//    while ([startTime timeIntervalSinceNow] < timeToRun) {
//        UInt256 hash = [[NSData dataWithUInt256:seed] SHA256_2];
//        UInt256 xor = uint256_xor(randomNumber, hash);
//        uint16_t depth = uint256_firstbits(xor);
//        if (depth > maxDepth) {
//            NSLog(@"found a new max %d",depth);
//            maxDepth = depth;
//        }
//        seed = uInt256AddOne(seed);
//    }
}

@end
