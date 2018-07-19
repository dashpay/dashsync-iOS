//
//  DSDeterministicMasternodeListTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 7/18/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import "NSString+Bitcoin.h"
#import "DSChain.h"
#import "DSMasternodeManager.h"
#import "NSData+Bitcoin.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChainPeerManager.h"


@interface DSDeterministicMasternodeListTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSChain *testnetChain;

@end

@implementation DSDeterministicMasternodeListTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
    self.testnetChain = [DSChain testnet];
}

- (void)testDSMasternodeBroadcastHash {
    
    NSMutableArray<DSSimplifiedMasternodeEntry*>* entries = [NSMutableArray array];
    for (unsigned int i = 0; i < 16; i++) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[[NSString stringWithFormat:@"%032x",i].hexToData UInt256AtOffset:0] address:UINT128_ZERO port:i keyIDOperator:[[NSString stringWithFormat:@"%020x",i].hexToData UInt160AtOffset:0] keyIDVoting:[[NSString stringWithFormat:@"%020x",i].hexToData UInt160AtOffset:0] isValid:TRUE];
        [entries addObject:simplifiedMasternodeEntry];
    }
    
    NSMutableArray * simplifiedMasternodeEntryHashes = [NSMutableArray array];
    
    for (DSSimplifiedMasternodeEntry * entry in entries) {
        [simplifiedMasternodeEntryHashes addObject:[NSData dataWithUInt256:entry.simplifiedMasternodeEntryHash]];
    }
    
    NSArray * stringHashes = @[@"6c06974f8f6d88bf30f21854836c994452e784c4f9aa2ea5c8ca6fcf10181f8b", @"90f788b6b946cced7ed765efeb9123c08bef8e025428a02ab7eedcc65c6a6cb0", @"45c2e12db6e85d0e30a460f69159a37f8a9d81e8b4949c640a64c9119dbe3f45", @"a56add792486a8c5067866609484e6d36f650da7cd4db5ca4111ecd579334a6c", @"09a0be55cebd876c1f97857c0950739dfc6e84ab62e1bb99918042d3eafb1be3", @"adb23c6a1308da95d777f88bede5576c54f52651979a3ca5e16d8a20001a7265", @"df45a56be881ab0d7812f8c43d6bb164d5abb42b37baaf3e01b82d6331a75d9b", @"5712e7a512f307aa652f15f494df1d47a082fb54a9557d54cb8fcc779bd65b48", @"58ab53be8cd4e97a48395ac8d812e684f3ab2d6be071f58055e7f6856076f1d4", @"4652b7caad564d56e106d025705ad3ee6f66e56bb8ce6ce86ac396f06f6eb75e", @"7480510e4dc4468bb23d9f3cb9fb10a170080afe270d5ba58948ebc746e24205", @"68f9e1572c626f1d946031c16c7020d8cbc565de8021869803f058308242266e", @"ca8895e0bea291d1d0e1bd8716de1369f217e7fcd0ee7969672434d71329b3cd", @"9db68eccc2dc8c80919e7507d28e38a1cd7381d2828cbe8ad19331ed94b1b550", @"42660058e883c3ea8157e36005e6941a1d1bea4ea1e9a03897c9682aa834e09f", @"55d90588e07417e7144a69fee1baea16dc647b497ee1affc2c3d91b09ad23c9c"];
    
    NSMutableArray * verifyHashes = [NSMutableArray array];
    
    for (NSString * stringHash in stringHashes) {
        [verifyHashes addObject:stringHash.hexToData];
    }
    
    XCTAssertTrue([simplifiedMasternodeEntryHashes isEqualToArray:verifyHashes],@"Checking hashes");
    
    NSString * root = @"ddfd8bcde9a5a58ce2a043864d8aae4998996b58f5221d4df0fd29d478807d54";
    
    UInt256 merkleRoot = [self.chain.peerManagerDelegate.masternodeManager merkleRootFromHashes:simplifiedMasternodeEntryHashes];
    
    XCTAssertTrue([root.hexToData isEqualToData:[NSData dataWithUInt256:merkleRoot]],
                  @"MerkleRootEqual");
}

@end

