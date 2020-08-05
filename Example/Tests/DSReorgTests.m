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
#import "DSChain+Protected.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSChainManager.h"
#import "DSFullBlock.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"
#import "BigIntTypes.h"
#import "DashSync.h"
#import "DSMerkleBlock.h"

@interface DSReorgTests : XCTestCase

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) DSWallet * wallet;

@end

@implementation DSReorgTests

- (void)setUp {
    self.chain = [DSChain setUpDevnetWithIdentifier:@"devnet-mobile-2" withCheckpoints:nil withMinimumDifficultyBlocks:UINT32_MAX withDefaultPort:3000 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO isTransient:YES];
    self.wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testBEAdding {
    UInt256 chainWork1 =    @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 numberToAdd =   @"0000000000000000000000000000000000000000000000000000000000000111".hexToData.UInt256;
    UInt256 addition = uInt256AddBE(chainWork1, numberToAdd);
    XCTAssertEqualObjects(uint256_hex(addition),@"00000000000000000000000000000000000000000000336e9ee70cf4694c040a");
}

-(void)testBESubstraction1 {
    UInt256 chainWork1 =          @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 numberToSubstract =   @"0000000000000000000000000000000000000000000000000000000000000311".hexToData.UInt256;
    UInt256 substraction = uInt256SubtractBE(chainWork1, numberToSubstract);
    XCTAssertEqualObjects(uint256_hex(substraction),@"00000000000000000000000000000000000000000000336e9ee70cf4694bffe8");
}

-(void)testBESubstraction2 {
    UInt256 chainWork1 =          @"00000000000000000000000000000000000000000000336ea946ab063dcd3016".hexToData.UInt256;
    UInt256 numberToSubstract =   @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 substraction = uInt256SubtractBE(chainWork1, numberToSubstract);
    XCTAssertEqualObjects(uint256_hex(substraction),@"0000000000000000000000000000000000000000000000000a5f9e11d4812d1d");
}

- (void)testChainWork {
//    block 1283540
//    chainwork 00000000000000000000000000000000000000000000336e9ee70cf4694c02f9
//    target 19180f4a
//    block 1283541
//    chainwork 00000000000000000000000000000000000000000000336ea946ab063dcd3016
//    target 1918ada2
    UInt256 chainWork1 =    @"00000000000000000000000000000000000000000000336ea946ab063dcd3016".hexToData.UInt256;
    UInt256 chainWork2 =    @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 diffChainWork = @"0000000000000000000000000000000000000000000000000a5f9e11d4812d1d".hexToData.UInt256;
    UInt256 diffChainWorkToVerify = uInt256SubtractBE(chainWork1, chainWork2);
    XCTAssertEqualObjects(uint256_hex(diffChainWorkToVerify),uint256_hex(diffChainWork));
    UInt256 target = setCompactLE(0x1918ada2);
    UInt256 work = uInt256AddOneLE(uInt256DivideLE(uint256_inverse(target), uInt256AddOneLE(target)));
    XCTAssertEqualObjects(uint256_hex(target),@"00000000000000000000000000000000000000000000a2ad1800000000000000");
    XCTAssertEqualObjects(uint256_hex(work),@"1d2d81d4119e5f0a000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(uint256_reverse_hex(work),uint256_hex(diffChainWork));
    
}

- (void)testSimpleReorg {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray * directoryContents =
          [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
            includingPropertiesForKeys:@[]
                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                 error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@",@"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count,149);
    NSMutableArray * sortedBlocks105 = [NSMutableArray array];
    NSMutableArray * sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;
    
    while (i <= 150) {
        for (NSURL * url in blocks) {
            NSArray * components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }
    
    i = 105;
    
    for (NSURL * url in sortedBlocks105) {
        NSData * blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock * merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock fromPeer:nil];
    }
    
    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.aggregateWork),@"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight,105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight,1);
    
    DSAccount * account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY",@"Not matching receive address");
    
    NSData * headerData = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;
    
    NSData * blockData = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;
    
    DSMerkleBlock * merkleBlockFork = [DSMerkleBlock merkleBlockWithMessage:headerData onChain:self.chain];
    [self.chain addBlock:merkleBlockFork fromPeer:nil];
    
    
    XCTAssertEqual(self.chain.lastTerminalBlockHeight,106);
    XCTAssertEqual(self.chain.lastSyncBlockHeight,1);
    
    for (NSURL * url in sortedBlocks106to150) {
        NSData * blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock * merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock fromPeer:nil];
    }
    
    XCTAssertEqual(self.chain.lastTerminalBlockHeight,150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight,1);
    
}


@end
