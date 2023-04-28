//
//  DSDataTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 5/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BigIntTypes.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
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
    UInt256 number50 = uInt256MultiplyUInt32LE(number1, 50);    // 3 bits set 0011 0010 (50)
    UInt256 number50Shifted = uInt256ShiftLeftLE(number50, 64); // 3 bits set
    UInt256 testNumber50Shifted = ((UInt256){.u64 = {0, 50, 0, 0}});
    XCTAssert(uint256_eq(number50Shifted, testNumber50Shifted), @"These numbers must be the same");
    UInt256 testNumber = uInt256AddOneLE(number50Shifted); // 4 bits set
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

- (void)testAllTheMath {
    UInt256 n_1 = uInt256AddOneLE(UINT256_ZERO);
    UInt256 n_max = uInt256AddOneLE(UINT256_MAX);
    UInt256 n_50 = uInt256MultiplyUInt32LE(n_1, 50);    // 3 bits set 0011 0010 (50)
    UInt256 aa = @"a0fcffffffffffffffffffffffffffffffffffffffffffffffffffffff4ffbff".hexToData.UInt256;
    UInt256 bb = @"100e000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    UInt256 cc = @"bc9a78563412f0cdab8967452301dfbc9a78563412f0cdab8967452301341200".hexToData.UInt256;
    //    UInt256 c = uInt256DivideLE(a, b);
    
    //    XCTAssertEqualObjects(uint256_hex(c), @"bc9a78563412f0cdab8967452301dfbc9a78563412f0cdab8967452301341200", @"This should be the result value");
    //    NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    //    NoTimeLog(@"val | hex                                                              | neg                                                              | div                                                              | shift_le                                                         | cmpct | ");
    //    NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    //    NoTimeLog(@"1   | %@ | %@ | %@ | %@ | %u     | ", uint256_hex(n_1), uint256_hex(uInt256NegLE(n_1)), uint256_hex(uInt256DivideLE(n_1, n_50)), uint256_hex(uInt256ShiftLeftLE(n_1, 250)), compactBitsLE(n_1));
    //    NoTimeLog(@"max | %@ | %@ | %@ | %@ | %u     | ", uint256_hex(n_max), uint256_hex(uInt256NegLE(n_max)), uint256_hex(uInt256DivideLE(n_max, n_50)), uint256_hex(uInt256ShiftLeftLE(n_max, 250)), compactBitsLE(n_max));
    //    NoTimeLog(@"50  | %@ | %@ | %@ | %@ | %u     | ", uint256_hex(n_50), uint256_hex(uInt256NegLE(n_50)), uint256_hex(uInt256DivideLE(n_50, n_50)), uint256_hex(uInt256ShiftLeftLE(n_50, 250)), compactBitsLE(n_50));
    //    NoTimeLog(@"aa  | %@ | %@ | %@ | %@ | %u   | ", uint256_hex(aa), uint256_hex(uInt256NegLE(aa)), uint256_hex(uInt256DivideLE(aa, n_50)), uint256_hex(uInt256ShiftLeftLE(aa, 250)), compactBitsLE(aa));
    //    NoTimeLog(@"bb  | %@ | %@ | %@ | %@ | %u    | ", uint256_hex(bb), uint256_hex(uInt256NegLE(bb)), uint256_hex(uInt256DivideLE(bb, n_50)), uint256_hex(uInt256ShiftLeftLE(bb, 250)), compactBitsLE(bb));
    //    NoTimeLog(@"cc  | %@ | %@ | %@ | %@ | %u   | ", uint256_hex(cc), uint256_hex(uInt256NegLE(cc)), uint256_hex(uInt256DivideLE(cc, n_50)), uint256_hex(uInt256ShiftLeftLE(cc, 250)), compactBitsLE(cc));
    //    NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    //
    //        NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    //        NoTimeLog(@"val | hex                                                              | - LE                                                              | / LE                                                        | cmpct | ");
    //        NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    //        NoTimeLog(@"1   | %@ | %@ | %@ | %u     | ", uint256_hex(n_1),      uint256_hex(uInt256SubtractLE(n_1, n_50)),      /*uint256_hex(uInt256ShiftLeftLE(n_1, 250)),*/      uint256_hex(uInt256DivideLE(n_1, n_50)),    compactBitsLE(n_1));
    //        NoTimeLog(@"max | %@ | %@ | %@ | %u     | ", uint256_hex(n_max),    uint256_hex(uInt256SubtractLE(n_max, n_50)),    /*uint256_hex(uInt256ShiftLeftLE(n_max, 250)),*/    uint256_hex(uInt256DivideLE(n_max, n_50)),  compactBitsLE(n_max));
    //        NoTimeLog(@"50  | %@ | %@ | %@ | %u     | ", uint256_hex(n_50),     uint256_hex(uInt256SubtractLE(n_50, n_50)),     /*uint256_hex(uInt256ShiftLeftLE(n_50, 250)),*/     uint256_hex(uInt256DivideLE(n_50, n_50)),   compactBitsLE(n_50));
    //        NoTimeLog(@"aa  | %@ | %@ | %@ | %u   | ",   uint256_hex(aa),       uint256_hex(uInt256SubtractLE(aa, n_50)),       /*uint256_hex(uInt256ShiftLeftLE(aa, 250)),*/       uint256_hex(uInt256DivideLE(aa, n_50)),     compactBitsLE(aa));
    //        NoTimeLog(@"bb  | %@ | %@ | %@ | %u    | ",  uint256_hex(bb),       uint256_hex(uInt256SubtractLE(bb, n_50)),       /*uint256_hex(uInt256ShiftLeftLE(bb, 250)),*/       uint256_hex(uInt256DivideLE(bb, n_50)),     compactBitsLE(bb));
    //        NoTimeLog(@"cc  | %@ | %@ | %@ | %u   | ",   uint256_hex(cc),       uint256_hex(uInt256SubtractLE(cc, n_50)),       /*uint256_hex(uInt256ShiftLeftLE(cc, 250)),*/       uint256_hex(uInt256DivideLE(cc, n_50)),     compactBitsLE(cc));
    //        NoTimeLog(@"--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    
        NoTimeLog(@"------------------------------------------------------------------------------------------------------------------------------------------------------------------");
        NoTimeLog(@"val | hex                                                              | supeq                                                          | / LE                    ");
        NoTimeLog(@"------------------------------------------------------------------------------------------------------------------------------------------------------------------");
        NoTimeLog(@"1   | %@ | %@ | ",  uint256_hex(n_1),      uint256_hex(uint256_xor(n_1, n_50)));
        NoTimeLog(@"max | %@ | %@ | ",  uint256_hex(n_max),    uint256_hex(uint256_xor(n_max, n_50)));
        NoTimeLog(@"50  | %@ | %@ | ",  uint256_hex(n_50),     uint256_hex(uint256_xor(n_50, n_50)));
        NoTimeLog(@"aa  | %@ | %@ | ",  uint256_hex(aa),     uint256_hex(uint256_xor(aa, n_50)));
        NoTimeLog(@"bb  | %@ | %@ | ",  uint256_hex(bb),      uint256_hex(uint256_xor(bb, n_50)));
        NoTimeLog(@"cc  | %@ | %@ | ",  uint256_hex(cc),     uint256_hex(uint256_xor(cc, n_50)));
        NoTimeLog(@"------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    
    
}

@end
