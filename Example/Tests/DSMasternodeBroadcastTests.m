//
//  DSMasternodeBroadcastTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 27/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSString+Bitcoin.h"
#import "DSChain.h"
#import "DSMasternodeBroadcast.h"
#import "NSData+Bitcoin.h"


@interface DSMasternodeBroadcastTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSChain *testnetChain;

@end

@implementation DSMasternodeBroadcastTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
    self.testnetChain = [DSChain testnet];
}

- (void)testDSMasternodeBroadcastHash {
    NSData *message = @"fca529cc8119621fef09b4e88180384b92ec911424f4432cd57c8fe851f364890100000000ffffffff00000000000000000000ffff8b3b993f270f2103d133fcac9fc2f3288c7219aebf73a40e39938d529a86d1c8115ff09db26b43944104d8ede0e4510dceabdd26ca58ebdb9e9637c080e4055c0ef292a54201f9a244dc2ea591dfed51e1050235dd8c9027b2602f56620493e999684cb6a2401b0113f8411ff19b06e7c745ac6288ea5fbe426abef9974d51530fd0478dcf43db515e8f58823ecaa5e1dedd27f420ada4a2e0b8969bf082486cb9fdad0299fad80cb054f1e11731425a0000000040120100fca529cc8119621fef09b4e88180384b92ec911424f4432cd57c8fe851f364890100000000ffffffffa779315d9b782f9d0f480c20074858eac9d1ac4bf5b40990250000000000000012c47b5a00000000411cbf83c9aacc754533b6a4664de309bd1d788a9b5ec961cd605bf92d9ad533737459d20ec571a71721808b8cfdac5f9de2bdb96788e7e2d2661262690a20df8d260100010100".hexToData;
    
    DSMasternodeBroadcast *mnb = [DSMasternodeBroadcast masternodeBroadcastFromMessage:message onChain:self.chain];
    UInt256 hash = *(UInt256 *)@"5a2a2340056e461fb0a639e7197323671b06f301877775fb8fb967567053f5f1".hexToData.bytes;
    
    XCTAssertTrue(uint256_eq(hash, mnb.masternodeBroadcastHash),
                  @"DSMasternodeBroadcast masternodeBroadcastHash");
}

- (void)testDSMasternodeBroadcastTestnetHash {
    NSData *message = @"6b0af22b2670894c8c47ab426b27f906c8b1ddfa6625b6dfb33f5bd167887ac70000000000000000000000000000ffff22d5300c4a9121024844d13d64dd612147474caeb3ae9eff50daffec4cea17312ce3a8191573af514104c40aeb50bac5b7aea7ba7d0c2426b172b53a51a1ae787078e03107c996d188a691e3f514e02ff9ba10e764488d78c931f54db1ea9ac3a70ea3d34772c1ab1a07411f7ec17ba8faff0b5440846ee8dace184340f3b38484a0f94dace3191bbcbe8e03749b64553f1e7505093dc9d70cc5ea709555f9080058280c9a960807af56a00bae532b5b00000000421201006b0af22b2670894c8c47ab426b27f906c8b1ddfa6625b6dfb33f5bd167887ac700000000911b6a96d5e7ae38975c0320f309e4447345af542f3ebd83e624150a000000006270335b00000000411c69b5d6ca74eb716614dcf87897c02f8f2d495bbb20ad749297cbb72f3d22674a54bba83d6f180848d1a67a5b6e43509451eb772a92f5973606520ccecd4652c30100020100ecd50100".hexToData;
    
    DSMasternodeBroadcast *mnb = [DSMasternodeBroadcast masternodeBroadcastFromMessage:message onChain:self.testnetChain];
    UInt256 hash = *(UInt256 *)@"c54bbf5a536049f8dd079c338ec3023133754fc19fe0518af00b99970118a5ff".hexToData.bytes;
    
    XCTAssertTrue(uint256_eq(hash, mnb.masternodeBroadcastHash),
                  @"DSMasternodeBroadcast masternodeBroadcastHash");
}

@end
