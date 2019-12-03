//
//  DSChainLockTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 11/27/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSChainLock.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"

@interface DSChainLockTests : XCTestCase

@end

@implementation DSChainLockTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testChainLockDeserialization {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt32:1177907];
    [data appendUInt256:@"0000000000000027b4f24c02e3e81e41e2ec4db8f1c42ee1f3923340a22680ee".hexToData.UInt256];
    [data appendUInt768:@"8ee1ecc07ee989230b68ccabaa95ef4c6435e642a61114595eb208cb8bfad5c8731d008c96e62519cb60a642c4999c880c4b92a73a99f6ff667b0961eb4b74fc1881c517cf807c8c4aed2c6f3010bb33b255ae75b7593c625e958f34bf8c02be".hexToData.UInt768];
    DSChainLock *chainLock = [DSChainLock chainLockWithMessage:data onChain:[DSChain mainnet]];
    XCTAssertEqualObjects(uint256_hex(chainLock.requestID),@"f79d7cee1eea5839d91da7921920f19258e08b51c7cda01086e52d1b1d86510c");
    
}

@end
