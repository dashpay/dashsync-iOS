//
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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
#import "DSBLSKey.h"
#import "DSChain+Protected.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Encryption.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSNetworkTests : XCTestCase

@property (strong, nonatomic) DSChain *mainnetChain;
@property (strong, nonatomic) DSWallet *mainnetWallet;
@property (strong, nonatomic) DSChain *testnetChain;
@property (strong, nonatomic) DSWallet *testnetWallet;
@property (strong, nonatomic) id mnListMainnetStatusObserver, mnListTestnetStatusObserver;

@end

@implementation DSNetworkTests

- (void)setUp {
    self.mainnetChain = [DSChain testnet];
    self.mainnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.mainnetChain storeSeedPhrase:NO isTransient:YES];
    [self.mainnetChain unregisterAllWallets];
    [self.mainnetChain addWallet:self.mainnetWallet];

    self.testnetChain = [DSChain testnet];
    self.testnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.testnetChain storeSeedPhrase:NO isTransient:YES];
    [self.testnetChain unregisterAllWallets];
    [self.testnetChain addWallet:self.testnetWallet];
}

- (void)testTestnetQuickHeadersSync {
    [[DashSync sharedSyncController] wipePeerDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeSporkDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    XCTestExpectation *pingFinishedExpectation = [[XCTestExpectation alloc] init];

    void (^currentMasternodeListDidChangeBlock)(NSNotification *note) = ^(NSNotification *note) {
        id masternodeList = [note userInfo][DSMasternodeManagerNotificationMasternodeListKey];
        if ([masternodeList isEqual:[NSNull null]]) {
            DSLogPrivate(@"Finished sync");
            [[DashSync sharedSyncController] stopSyncForChain:self.testnetChain];
            [self.testnetChain.chainManager.masternodeManager checkPingTimesForCurrentMasternodeListInContext:[NSManagedObjectContext viewContext]
                                                                                               withCompletion:^(NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
                                                                                                   DSLogPrivate(@"Finished ping times");
                                                                                                   [pingFinishedExpectation fulfill];
                                                                                               }];
        }
    };

    [[DashSync sharedSyncController] startSyncForChain:self.testnetChain];
    self.mnListTestnetStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSCurrentMasternodeListDidChangeNotification
                                                                                         object:nil
                                                                                          queue:nil
                                                                                     usingBlock:currentMasternodeListDidChangeBlock];
    [self waitForExpectations:@[pingFinishedExpectation] timeout:300];
}
@end
