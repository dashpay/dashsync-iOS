//
//  DSGovernanceTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 27/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSString+Bitcoin.h"
#import "DSChain.h"
#import "DSGovernanceObject.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"

@interface DSGovernanceTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSChain *testnetChain;

@end

@implementation DSGovernanceTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
    self.testnetChain = [DSChain testnet];
}

- (void)testGovernanceHash {
    NSData *message = @"0000000000000000000000000000000000000000000000000000000000000000010000004326315c00000000f26c7917799283589175efa0d1ae622f9e5d92897bd04f0df5c25e2b7653ed42fd12015b5b2270726f706f73616c222c7b22656e645f65706f6368223a313536303530333936382c226e616d65223a22446173682d4d65726368616e742d56656e657a75656c612d353030302d4d65726368616e7473222c227061796d656e745f61646472657373223a22586f5934596b37413573316d7369437331474b4575457a413339647a58414c506e39222c227061796d656e745f616d6f756e74223a3239352c2273746172745f65706f6368223a313534373632363536382c2274797065223a312c2275726c223a2268747470733a2f2f7777772e6461736863656e7472616c2e6f72672f702f446173682d4d65726368616e742d56656e657a75656c612d353030302d4d65726368616e7473227d5d5d010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00".hexToData;
    
    DSGovernanceObject *govObject = [DSGovernanceObject governanceObjectFromMessage:message onChain:self.chain];
    UInt256 hash = *(UInt256 *)@"011af9eb16d5b0e05c89ed069ff88b755b2c412d4d35dbffd511cfa3a6579fdb".hexToData.bytes;
    
    XCTAssertTrue(uint256_eq(hash, govObject.governanceObjectHash),
                  @"DSGovernanceObject governanceObjectHash");
}

- (void)testGovernanceTestnetHash {
    NSData *message = @"00000000000000000000000000000000000000000000000000000000000000000100000066bf155b00000000d5226a58c7a6edc67d1a2e45ef3f322839de56c3fb1d48f54d57f24b4055cc10d15b5b2270726f706f73616c222c7b22656e645f65706f6368223a313539333638323334362c226e616d65223a22736f6d655f6e65775f70726f706f73616c222c227061796d656e745f61646472657373223a227954794274445a703136487453316a704e64317644313179364c5379766d31587a58222c227061796d656e745f616d6f756e74223a322c2273746172745f65706f6368223a313532383135313931302c2274797065223a312c2275726c223a22687474703a2f2f736f6d656e657770726f706f73616c2e636f6d227d5d5d010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00".hexToData;
    
    DSGovernanceObject *govObject = [DSGovernanceObject governanceObjectFromMessage:message onChain:self.testnetChain];
    UInt256 hash = *(UInt256 *)@"0fc23ad0a78b1bfd6776a3631395524719d4667d96d89cbb9fae7b42ac4d47d6".hexToData.bytes;
    
    XCTAssertTrue(uint256_eq(hash, govObject.governanceObjectHash),
                  @"DSGovernanceObject governanceObjectHash");
}

-(void)testThis {
    DSChain * mainnet = [DSChain mainnet];
    NSString * name = @"some_new_proposal";
    NSString * address = @"yTyBtDZp16HtS1jpNd1vD11y6LSyvm1XzX";
    NSUInteger amount = 200000000;
    NSString * url = @"http://somenewproposal.com";
    UInt256 collateralHash = ((UInt256) { .u64 = { 14334296564102210261u, 2896447807243033213u, 17674409704766758457u, 1210436134496261965u } });
    UInt256 governanceObjectHash = ((UInt256) { .u64 = { 18238324668836266511u, 5139334035291731559u, 13518918322319971353u, 15440395249708150431u } });
    DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithType:DSGovernanceObjectType_Proposal parentHash:UINT256_ZERO revision:1 timestamp:1528151910 signature:nil collateralHash:collateralHash governanceObjectHash:governanceObjectHash identifier:name amount:amount startEpoch:1528151910 endEpoch:1593682346 paymentAddress:address url:url onChain:mainnet];
    UInt256 checkHash = governanceObject.governanceObjectHash;
    NSData * hash = @"0fc23ad0a78b1bfd6776a3631395524719d4667d96d89cbb9fae7b42ac4d47d6".hexToData;
    XCTAssertEqualObjects(hash.hexString, [NSData dataWithUInt256:checkHash].hexString);
}

-(void)testFind {
    NSArray * names = @[@""];
    NSArray * addressArray = @[@""];
    
    UInt256 hash = *(UInt256 *)@"20499001e2b0c5dd34b9214a5475be07afad2f68f8d02e5f52be79280500f7d7ff".hexToData.bytes;
    UInt256 reversedHash = *(UInt256 *)@"20499001e2b0c5dd34b9214a5475be07afad2f68f8d02e5f52be79280500f7d7ff".hexToData.reverse.bytes;
    
    for (NSString * name in names) {
        for (NSString * address in addressArray) {
            NSString * url = [NSString stringWithFormat:@"https://www.dashcentral.org/p/%@",name];
            
            DSChain *chain = [DSChain mainnet];
            DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithType:DSGovernanceObjectType_Proposal parentHash:UINT256_ZERO revision:1 timestamp:0 signature:nil collateralHash:UINT256_ZERO governanceObjectHash:UINT256_ZERO identifier:name amount:7900000000 startEpoch:1539779982 endEpoch:1544930942 paymentAddress:address url:url onChain:chain];
            NSLog(@"%@",[NSData dataWithUInt256:[governanceObject.proposalInfo SHA256_2]]);
            UInt256 checkHash = [governanceObject.proposalInfo SHA256_2];
            if (uint256_eq(checkHash, hash))  {
                NSLog(@"We found it");
            } else if (uint256_eq(checkHash, reversedHash))  {
                NSLog(@"We found it");
            }
        }
    }
    

    
    
}

@end
