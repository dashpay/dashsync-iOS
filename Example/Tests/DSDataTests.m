//
//  DSDataTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 5/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "BigIntTypes.h"

@interface DSDataTests : XCTestCase

@end

@implementation DSDataTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBitsAreTrueOperations {
    UInt256 number1 = uInt256AddOne(UINT256_ZERO);
    UInt256 number10000 = uInt256MultiplyUInt32(number1, 10000); //5 bits set
    UInt256 test10000Shifted = uInt256ShiftLeft(number10000, 100); //5 bits set
    UInt256 testNumber = uInt256AddOne(test10000Shifted); //6 bits set
    NSData * data = [NSData dataWithUInt256:testNumber];
    NSAssert([data trueBitsCount] == 6, @"Must be 6 bits here");
}
@end
