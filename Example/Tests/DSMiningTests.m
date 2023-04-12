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

#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSFullBlock.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"

@interface DSMiningTests : XCTestCase

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSWallet *wallet;

@end

@implementation DSMiningTests

- (void)setUp {
    self.chain = [DSChain setUpDevnetWithIdentifier:@"miningTest" version:1 protocolVersion:PROTOCOL_VERSION_DEVNET minProtocolVersion:DEFAULT_MIN_PROTOCOL_VERSION_DEVNET withCheckpoints:nil withMinimumDifficultyBlocks:0 withDefaultPort:3000 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO ISLockQuorumType:LLMQType_Llmqtype50_60 ISDLockQuorumType:LLMQType_Llmqtype60_75 chainLockQuorumType:LLMQType_Llmqtype50_60 platformQuorumType:LLMQType_Llmqtype100_67 masternodeSyncMode:DSMasternodeSyncMode_Mixed isTransient:YES];
    self.wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMiningTwice {
    DSAccount *account = [self.wallet accountWithNumber:0];
    [self.chain.chainManager mineBlockToPaymentAddress:account.receiveAddress
                                      withTransactions:[NSArray array]
                                           withTimeout:10000
                                            completion:^(DSFullBlock *_Nonnull block0, NSUInteger attempts, NSTimeInterval timeUsed, NSError *_Nonnull error) {
                                                BOOL success0 = [self.chain addBlock:block0 receivedAsHeader:NO fromPeer:nil];
                                                XCTAssertTrue(success0);
                                                [self.chain.chainManager mineBlockToPaymentAddress:account.receiveAddress
                                                                                  withTransactions:[NSArray array]
                                                                                       withTimeout:10000
                                                                                        completion:^(DSFullBlock *_Nonnull block1, NSUInteger attempts, NSTimeInterval timeUsed, NSError *_Nonnull error) {
                                                                                            BOOL success1 = [self.chain addBlock:block1 receivedAsHeader:NO fromPeer:nil];
                                                                                            XCTAssertTrue(success1);
                                                                                            XCTAssertTrue(self.chain.lastTerminalBlockHeight == 3);
                                                                                        }];
                                            }];
}


- (void)testMining30Blocks {
    DSAccount *account = [self.wallet accountWithNumber:0];
    [self.chain.chainManager mineEmptyBlocks:30
                            toPaymentAddress:account.receiveAddress
                                 withTimeout:100000
                                  completion:^(NSArray<DSFullBlock *> *_Nonnull blocks, NSArray<NSNumber *> *_Nonnull attempts, NSTimeInterval timeUsed, NSError *_Nullable error) {
                                      uint32_t initialHeight = self.chain.lastTerminalBlockHeight;
                                      for (DSBlock *block in blocks) {
                                          BOOL success = [self.chain addBlock:block receivedAsHeader:NO fromPeer:nil];
                                          XCTAssertTrue(success);
                                      }
                                      XCTAssertTrue(self.chain.lastTerminalBlockHeight - initialHeight == 30);
                                  }];
}


@end
