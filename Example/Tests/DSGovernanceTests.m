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
    NSData *message = @"000000000000000000000000000000000000000000000000000000000000000001000000f2edf15a000000002f5d698d3ac2fc83c2364e440795d239b7a21d4bc8c805b18680c439fe94fd03fdcc0135623562323237303732366637303666373336313663323232633762323236353665363435663635373036663633363832323361333133353333333433343330333733333334333132633232366536313664363532323361323234313465353935303431353935663461353534653435356633323330333133383232326332323730363137393664363536653734356636313634363437323635373337333232336132323538373335373432373636383636353336353738333933323634366534383638373936383535353434383462373135393438353235383336373137353331353936663436323232633232373036313739366436353665373435663631366436663735366537343232336133323331333932633232373337343631373237343566363537303666363336383232336133313335333233363336333833303339333033313263323237343739373036353232336133313263323237353732366332323361323236383734373437303733336132663266373737373737326536343631373336383633363536653734373236313663326536663732363732663730326634313465353935303431353935663461353534653435356633323330333133383232376435643564010000000000000000000000000000000000000000000000000000000000000000000000ffffffff00ffffffff00".hexToData;
    
    DSGovernanceObject *govObject = [DSGovernanceObject governanceObjectFromMessage:message onChain:self.chain];
    UInt256 hash = *(UInt256 *)@"dbab10675ea9052dae06422e7752924a80083f006de09570a1c9ac2b92d283ff".hexToData.bytes;
    
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
    //[["proposal",{"end_epoch":1544752686,"name":"b2b-b2c-dash-payment-system","payment_address":"XkjzBbMdNttG8X1bBYiZQeuW86418KJ6aK","payment_amount":288,"start_epoch":1529299806,"type":1,"url":"https://www.dashcentral.org/p/b2b-b2c-dash-payment-system"}]]
    NSString * name = @"b2b-b2c-dash-payment-system";
    NSString * address = @"XkjzBbMdNttG8X1bBYiZQeuW86418KJ6aK";
    NSUInteger amount = 28800000000;
    NSString * url = @"https://www.dashcentral.org/p/b2b-b2c-dash-payment-system";
    DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithType:DSGovernanceObjectType_Proposal parentHash:UINT256_ZERO revision:1 timestamp:1528441570 signature:nil collateralHash:UINT256_ZERO governanceObjectHash:UINT256_ZERO identifier:name amount:amount startEpoch:1529299806 endEpoch:1544752686 paymentAddress:address url:url onChain:mainnet];
    UInt256 checkHash = governanceObject.governanceObjectHash;
    NSData * hash = @"efcc74ab35b11bf6585fbdd457a246dce6b6aa3b8fd1c9200115e8540ec70f72".hexToData;
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
            
            DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithType:DSGovernanceObjectType_Proposal parentHash:UINT256_ZERO revision:1 timestamp:0 signature:nil collateralHash:UINT256_ZERO governanceObjectHash:UINT256_ZERO identifier:name amount:7900000000 startEpoch:1539779982 endEpoch:1544930942 paymentAddress:address url:url onChain:nil];
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
