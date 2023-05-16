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

#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSChain+Protected.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Encryption.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSTestnetMetricSyncTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSWallet *wallet;
@property (strong, nonatomic) id blocksObserver, txStatusObserver;

@end

@implementation DSTestnetMetricSyncTests

- (void)setUp {
    self.chain = [DSChain testnet];
    self.wallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:NO isTransient:YES];
    [self.chain unregisterAllWallets];
    [self.chain addWallet:self.wallet];
}

- (void)tearDown {
}

- (void)testTestnetQuickHeadersSyncMetric {
    if (@available(iOS 13.0, *)) {
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.iterationCount = 3;
        DSLogPrivate(@"Starting testInitialHeadersSync");

        [self measureWithMetrics:@[[[XCTCPUMetric alloc] init], [[XCTMemoryMetric alloc] init], [[XCTClockMetric alloc] init]]
                         options:options
                           block:^{
                               [[DashSync sharedSyncController] wipePeerDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeSporkDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
                               [[DashSync sharedSyncController] startSyncForChain:self.chain];
                               self.txStatusObserver =
                                   [[NSNotificationCenter defaultCenter] addObserverForName:DSChainInitialHeadersDidFinishSyncingNotification
                                                                                     object:nil
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                     DSLogPrivate(@"Finished sync");
                                                                                     [[DashSync sharedSyncController] stopSyncForChain:self.chain];
                                                                                     [headerFinishedExpectation fulfill];
                                                                                 }];
                               [self waitForExpectations:@[headerFinishedExpectation] timeout:360000];
                           }];
    } else {
        // Fallback on earlier versions
    }
}

- (void)testTestnetInitialHeadersSync2000Metric {
    if (@available(iOS 13.0, *)) {
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.iterationCount = 2;
        self.chain.headersMaxAmount = 2000;
        DSLogPrivate(@"Starting testInitialHeadersSync");

        [self measureWithMetrics:@[[[XCTCPUMetric alloc] init], [[XCTMemoryMetric alloc] init], [[XCTClockMetric alloc] init]]
                         options:options
                           block:^{
                               XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
                               [[DashSync sharedSyncController] wipePeerDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeSporkDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] startSyncForChain:self.chain];
                               self.txStatusObserver =
                                   [[NSNotificationCenter defaultCenter] addObserverForName:DSChainInitialHeadersDidFinishSyncingNotification
                                                                                     object:nil
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                     DSLogPrivate(@"Finished sync");
                                                                                     [[DashSync sharedSyncController] stopSyncForChain:self.chain];
                                                                                     [headerFinishedExpectation fulfill];
                                                                                 }];
                               [self waitForExpectations:@[headerFinishedExpectation] timeout:360000];
                           }];
    } else {
        // Fallback on earlier versions
    }
}

- (void)testTestnetFullSyncMetric {
    if (@available(iOS 13.0, *)) {
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.iterationCount = 2;
        [self measureWithMetrics:@[[[XCTCPUMetric alloc] init], [[XCTMemoryMetric alloc] init], [[XCTClockMetric alloc] init]]
                         options:options
                           block:^{
                               [self.chain useCheckpointBeforeOrOnHeightForSyncingChainBlocks:1];
                               [self.chain useCheckpointBeforeOrOnHeightForTerminalBlocksSync:UINT32_MAX];
                               [[DashSync sharedSyncController] wipePeerDataForChain:self.chain inContext:[NSManagedObjectContext peerContext]];
                               [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeSporkDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
                               XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
                               [[DashSync sharedSyncController] startSyncForChain:self.chain];
                               self.txStatusObserver =
                                   [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlocksDidFinishSyncingNotification
                                                                                     object:nil
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                     DSLogPrivate(@"Finished sync");
                                                                                     [[DashSync sharedSyncController] stopSyncForChain:self.chain];
                                                                                     [headerFinishedExpectation fulfill];
                                                                                 }];
                               [self waitForExpectations:@[headerFinishedExpectation] timeout:36000];
                           }];
    } else {
        // Fallback on earlier versions
    }
}

@end
