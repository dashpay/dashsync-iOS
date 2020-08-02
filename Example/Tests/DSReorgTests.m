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
    self.chain = [DSChain setUpDevnetWithIdentifier:@"devnet-mobile-2" withCheckpoints:nil withMinimumDifficultyBlocks:0 withDefaultPort:3000 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO isTransient:YES];
    self.wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    NSMutableArray * sortedForkBlocks106to150 = [NSMutableArray array];
    int i = 2;
    
    while (i <= 150) {
        for (NSURL * url in blocks) {
            NSArray * components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i && ![components[4] isEqualToString:@"fork"]) {
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
    
    while (i <= 110) {
        for (NSURL * url in blocks) {
            NSArray * components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i && [components[4] isEqualToString:@"fork"]) {
                [sortedForkBlocks106to150 addObject:url];
                i++;
                break;
            }
        }
    }
    
    for (NSURL * url in sortedBlocks105) {
        NSData * blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock * merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock fromPeer:nil];
    }
    
    XCTAssertEqual(self.chain.lastTerminalBlockHeight,105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight,1);
    
    DSAccount * account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY",@"Not matching receive address");
    
    for (NSURL * url in sortedBlocks106to150) {
        NSData * blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock * merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock fromPeer:nil];
    }
    
    XCTAssertEqual(self.chain.lastTerminalBlockHeight,150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight,1);
    
}


@end
