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
    UInt256 number50 = uInt256MultiplyUInt32(number1, 50); //3 bits set 0011 0010 (50)
    UInt256 number50Shifted = uInt256ShiftLeft(number50, 64); //3 bits set
    UInt256 testNumber50Shifted = ((UInt256) { .u64 = { 0, 50, 0, 0 } });
    XCTAssert(uint256_eq(number50Shifted,testNumber50Shifted),@"These numbers must be the same");
    UInt256 testNumber = uInt256AddOne(number50Shifted); //4 bits set
    NSData * data = [NSData dataWithUInt256:testNumber];
    XCTAssert([data trueBitsCount] == 4, @"Must be 6 bits here");
    XCTAssert([data bitIsTrueAtIndex:0], @"This must be true");
    XCTAssert(![data bitIsTrueAtIndex:1], @"This must be false");
    XCTAssert([data bitIsTrueAtIndex:65], @"This must be true");
    XCTAssert(![data bitIsTrueAtIndex:67], @"This must be false");
    XCTAssert([data bitIsTrueAtIndex:68], @"This must be true");
}
@end
