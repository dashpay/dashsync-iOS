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
#import "DSChain+Checkpoint.h"
#import "DSChain+Protected.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Encryption.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSMainnetSyncTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSWallet *wallet;
@property (strong, nonatomic) id blocksObserver, txStatusObserver;

@end

@implementation DSMainnetSyncTests

- (void)setUp {
    self.chain = [DSChain mainnet];
    self.wallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:NO isTransient:YES];
    [self.chain unregisterAllWallets];
    [self.chain addWallet:self.wallet];
}

- (void)tearDown {
}

- (void)testMainnetQuickHeadersSync {
    // give time for saving of other tests to complete
    XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    });
    [self waitForExpectations:@[headerFinishedExpectation] timeout:120];
    [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}

- (void)testMainnetFullHeadersSync {
    // give time for saving of other tests to complete
    XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.chain useCheckpointBeforeOrOnHeightForTerminalBlocksSync:300000]; // not genesis, but good enough

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
    });
    [self waitForExpectations:@[headerFinishedExpectation] timeout:600];
    [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}

- (void)testMainnetLongSync {
    // give time for saving of other tests to complete
    XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.chain useCheckpointBeforeOrOnHeightForSyncingChainBlocks:1000000]; // not full sync, but much faster
        [self.chain useCheckpointBeforeOrOnHeightForTerminalBlocksSync:UINT32_MAX];
        [[DashSync sharedSyncController] wipePeerDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeSporkDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
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
    });
    [self waitForExpectations:@[headerFinishedExpectation] timeout:4800];
    [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}


@end
