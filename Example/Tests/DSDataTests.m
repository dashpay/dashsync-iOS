//
//  DSDataTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 5/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BigIntTypes.h"
#import "NSData+Dash.h"
#import "NSData+DSHash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

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
    UInt256 number1 = uInt256AddOneLE(UINT256_ZERO);
    UInt256 number50 = uInt256MultiplyUInt32LE(number1, 50);    //3 bits set 0011 0010 (50)
    UInt256 number50Shifted = uInt256ShiftLeftLE(number50, 64); //3 bits set
    UInt256 testNumber50Shifted = ((UInt256){.u64 = {0, 50, 0, 0}});
    XCTAssert(uint256_eq(number50Shifted, testNumber50Shifted), @"These numbers must be the same");
    UInt256 testNumber = uInt256AddOneLE(number50Shifted); //4 bits set
    NSData *data = [NSData dataWithUInt256:testNumber];
    XCTAssert([data trueBitsCount] == 4, @"Must be 6 bits here");
    XCTAssert([data bitIsTrueAtLEIndex:0], @"This must be true");
    XCTAssert(![data bitIsTrueAtLEIndex:1], @"This must be false");
    XCTAssert([data bitIsTrueAtLEIndex:65], @"This must be true");
    XCTAssert(![data bitIsTrueAtLEIndex:67], @"This must be false");
    XCTAssert([data bitIsTrueAtLEIndex:68], @"This must be true");
}

- (void)testDiv {
    UInt256 a = @"a0fcffffffffffffffffffffffffffffffffffffffffffffffffffffff4ffbff".hexToData.UInt256;
    UInt256 b = @"100e000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    int16_t num_bits = compactBitsLE(a);
    int16_t div_bits = compactBitsLE(b);
    XCTAssert(num_bits == 256);
    XCTAssert(div_bits == 12);
    UInt256 c = uInt256DivideLE(a, b);
    XCTAssertEqualObjects(uint256_hex(c), @"bc9a78563412f0cdab8967452301dfbc9a78563412f0cdab8967452301341200", @"This should be the result value");
}

@end
