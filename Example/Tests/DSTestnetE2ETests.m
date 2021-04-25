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
#import "DSBlockchainIdentity.h"
#import "DSChain+Protected.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSTransactionManager.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Encryption.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSTestnetE2ETests : XCTestCase
@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSECDSAKey *sweepKey;
@property (strong, nonatomic) DSTransactionManager *transactionManager;
@property (strong, nonatomic) DSIdentitiesManager *identitiesManager;
@property (strong, nonatomic) DSWallet *faucetWallet;
@property (strong, nonatomic) DSWallet *testWallet;
@property (strong, nonatomic) DSWallet *blockchainIdentityWallet;
@property (strong, nonatomic) DSAccount *fundingAccount;
@property (strong, nonatomic) id blocksObserver, txStatusObserver;
@end

@implementation DSTestnetE2ETests

#define TE2ERESETNETWORK 1

- (void)setUp {
    //this will be run before each test
    self.chain = [DSChain testnet];
    uint8_t seed[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    NSData *seedData = [NSData dataWithBytes:seed length:12];
    self.sweepKey = [DSECDSAKey keyWithSeedData:seedData];
    self.transactionManager = self.chain.chainManager.transactionManager;
    self.identitiesManager = self.chain.chainManager.identitiesManager;

    self.faucetWallet = [DSWallet standardWalletWithSeedPhrase:@"toilet frost repair cluster million atom budget system barrel knock put scare" setCreationDate:1611367099 forChain:self.chain storeSeedPhrase:YES isTransient:NO];
    if (![self.chain addWallet:self.faucetWallet]) {
        for (DSWallet *wallet in self.chain.wallets) {
            if ([wallet.uniqueIDString isEqualToString:self.faucetWallet.uniqueIDString]) {
                self.faucetWallet = wallet;
                break;
            }
        }
    }

    static DSWallet *staticTestWallet;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //this is run only the first time
        staticTestWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:YES isTransient:NO];

        [self.chain useCheckpointBeforeOrOnHeightForSyncingChainBlocks:414106];
        [self.chain useCheckpointBeforeOrOnHeightForTerminalBlocksSync:UINT32_MAX];
#if TE2ERESETNETWORK
        [[DashSync sharedSyncController] wipeBlockchainNonTerminalDataForChain:self.chain
                                                                     inContext:[NSManagedObjectContext chainContext]];
#endif
    });

    self.testWallet = staticTestWallet;
    self.fundingAccount = self.testWallet.accounts[0];

    if (![self.chain addWallet:self.testWallet]) {
        for (DSWallet *wallet in self.chain.wallets) {
            if ([wallet.uniqueIDString isEqualToString:self.testWallet.uniqueIDString]) {
                self.testWallet = wallet;
                break;
            }
        }
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testANetworkSetup {
    XCTestExpectation *headerFinishedExpectation = [[XCTestExpectation alloc] init];
    [[DashSync sharedSyncController] startSyncForChain:self.chain];
    self.txStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlocksDidFinishSyncingNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          DSLogPrivate(@"Finished sync");
                                                          //give things time to save
                                                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                              [headerFinishedExpectation fulfill];
                                                          });
                                                      }];
    [self waitForExpectations:@[headerFinishedExpectation] timeout:1800];
}

- (void)testAZFundTestAccount {
    DSAccount *faucetAccount = self.faucetWallet.accounts[0];

    DSTransaction *transaction = [faucetAccount transactionFor:10000000 to:self.fundingAccount.receiveAddress withFee:YES];
    XCTestExpectation *transactionFinishedExpectation = [[XCTestExpectation alloc] init];
    [faucetAccount signTransaction:transaction
                        withPrompt:nil
                        completion:^(BOOL signedTransaction, BOOL cancelled) {
                            XCTAssert(signedTransaction, @"Transaction should be signed");
                            XCTAssert(transaction.isSigned, @"Transaction should be signed");

                            __block BOOL sent = NO;

                            [self.transactionManager publishTransaction:transaction
                                                             completion:^(NSError *error) {
                                                                 XCTAssertNil(error, @"There should not be an error");
                                                                 if (!sent) {
                                                                     sent = YES;
                                                                     [faucetAccount registerTransaction:transaction saveImmediately:YES];
                                                                     [transactionFinishedExpectation fulfill];
                                                                 }
                                                             }];
                        }];
    [self waitForExpectations:@[transactionFinishedExpectation] timeout:120];
}

- (void)testBWalletHasFunds {
    XCTAssert(self.fundingAccount.balance >= 10000000); //Wallet must have at least 1 Dash
}

- (void)testCSendTransactionToKey {
    NSString *addressToSendTo = [self.sweepKey addressForChain:self.chain];

    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:addressToSendTo onChain:self.chain];
    paymentRequest.amount = 10000;
    DSPaymentProtocolRequest *protocolRequest = paymentRequest.protocolRequest;
    DSTransaction *transaction = [self.fundingAccount transactionForAmounts:protocolRequest.details.outputAmounts toOutputScripts:protocolRequest.details.outputScripts withFee:TRUE];
    XCTestExpectation *transactionFinishedExpectation = [[XCTestExpectation alloc] init];
    [self.fundingAccount signTransaction:transaction
                              withPrompt:nil
                              completion:^(BOOL signedTransaction, BOOL cancelled) {
                                  XCTAssert(signedTransaction, @"Transaction should be signed");
                                  XCTAssert(transaction.isSigned, @"Transaction should be signed");

                                  __block BOOL sent = NO;

                                  [self.transactionManager publishTransaction:transaction
                                                                   completion:^(NSError *error) {
                                                                       XCTAssertNil(error, @"There should not be an error");
                                                                       if (!sent) {
                                                                           sent = YES;
                                                                           [self.fundingAccount registerTransaction:transaction saveImmediately:YES]; //not sure this is needed
                                                                           [transactionFinishedExpectation fulfill];
                                                                       }
                                                                   }];
                              }];
    [self waitForExpectations:@[transactionFinishedExpectation] timeout:60];
}

- (void)testDSweepKey {
    uint64_t originalBalance = self.fundingAccount.balance;
    XCTestExpectation *transactionFinishedExpectation = [[XCTestExpectation alloc] init];
    //we need to wait a few seconds for the transaction to propagate on the network
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.fundingAccount sweepPrivateKey:[self.sweepKey serializedPrivateKeyForChain:self.chain]
                                     withFee:YES
                                  completion:^(DSTransaction *_Nonnull sweepTransaction, uint64_t fee, NSError *_Null_unspecified error) {
                                      XCTAssert(error == nil, @"There should not be an error");
                                      __block BOOL sent = NO;
                                      XCTAssert(sweepTransaction != nil, @"sweep transaction must exist");
                                      [self.transactionManager publishTransaction:sweepTransaction
                                                                       completion:^(NSError *error) {
                                                                           XCTAssert(error == nil, @"There should not be an error");
                                                                           if (!sent) {
                                                                               sent = YES;
                                                                               [self.fundingAccount registerTransaction:sweepTransaction saveImmediately:YES]; //not sure this is needed
                                                                               XCTAssert(self.fundingAccount.balance > originalBalance, @"Balance should be increased");
                                                                               [transactionFinishedExpectation fulfill];
                                                                           }
                                                                       }];
                                  }];
    });
    [self waitForExpectations:@[transactionFinishedExpectation] timeout:120];
}

- (void)testERegisterIdentity {
    NSString *username = [NSString stringWithFormat:@"CIIOSTestUser%llu", (uint64_t)[NSDate timeIntervalSince1970]];
    DSBlockchainIdentity *blockchainIdentity = [self.testWallet createBlockchainIdentityForUsername:username];
    DSBlockchainIdentityRegistrationStep steps = DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsername;
    XCTestExpectation *identityRegistrationFinishedExpectation = [[XCTestExpectation alloc] init];
    [blockchainIdentity generateBlockchainIdentityExtendedPublicKeysWithPrompt:@""
                                                                    completion:^(BOOL registered) {
                                                                        [blockchainIdentity createFundingPrivateKeyWithPrompt:@""
                                                                                                                   completion:^(BOOL success, BOOL cancelled) {
                                                                                                                       if (success && !cancelled) {
                                                                                                                           [blockchainIdentity registerOnNetwork:steps
                                                                                                                               withFundingAccount:self.fundingAccount
                                                                                                                               forTopupAmount:10000
                                                                                                                               stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {

                                                                                                                               }
                                                                                                                               completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
                                                                                                                                   XCTAssertNil(error, @"There should not be an error");
                                                                                                                                   XCTAssert(stepsCompleted = steps, @"We should have completed the same amount of steps that were requested");
                                                                                                                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                                                                       [identityRegistrationFinishedExpectation fulfill];
                                                                                                                                   });
                                                                                                                               }];
                                                                                                                       }
                                                                                                                   }];
                                                                    }];
    [self waitForExpectations:@[identityRegistrationFinishedExpectation] timeout:600];
}

- (void)testFSendAndAcceptContactRequest {
    NSArray *blockchainIdentities = [self.faucetWallet.blockchainIdentities allValues];
    XCTAssert(blockchainIdentities.count > 1, @"There should be at least 2 identities");
    uint32_t randomOldIdentityIndex = arc4random_uniform((uint32_t)blockchainIdentities.count - 2);
    DSBlockchainIdentity *identityA = blockchainIdentities[randomOldIdentityIndex];
    DSBlockchainIdentity *identityB = blockchainIdentities.lastObject;

    XCTAssert(identityA != identityB, @"There should be at least 2 identities");

    XCTestExpectation *friendshipFinishedExpectation = [[XCTestExpectation alloc] init];
    [identityA sendNewFriendRequestToBlockchainIdentity:identityB
                                             completion:^(BOOL success, NSArray<NSError *> *_Nullable errors) {
                                                 XCTAssert(success, @"This must succeed");
                                                 XCTAssertEqualObjects(errors, @[], @"There should be no errors");
                                                 [identityB sendNewFriendRequestToBlockchainIdentity:identityA
                                                                                          completion:^(BOOL success, NSArray<NSError *> *_Nullable errors) {
                                                                                              XCTAssert(success, @"This must succeed");
                                                                                              XCTAssertEqualObjects(errors, @[], @"There should be no errors");
                                                                                              [friendshipFinishedExpectation fulfill];
                                                                                          }];
                                             }];
    [self waitForExpectations:@[friendshipFinishedExpectation] timeout:600];
}

- (void)testGSendDashpayPayment {
    NSArray *blockchainIdentities = [self.faucetWallet.blockchainIdentities allValues];
    XCTAssert(blockchainIdentities.count > 1, @"There should be at least 2 identities");
    DSBlockchainIdentity *identity = blockchainIdentities.lastObject;
    DSDashpayUserEntity *dashpayUser = [identity matchingDashpayUserInViewContext];
    XCTAssert(dashpayUser.friends.count > 0);
    DSDashpayUserEntity *friend = [dashpayUser.friends anyObject];
    XCTestExpectation *paymentFinishedExpectation = [[XCTestExpectation alloc] init];
    [dashpayUser sendAmount:10000
        fromAccount:self.fundingAccount
        toFriend:friend
        requestingAdditionalInfo:^(DSRequestingAdditionalInfo additionalInfo) {

        }
        presentChallenge:^(NSString *_Nonnull challengeTitle, NSString *_Nonnull challengeMessage, NSString *_Nonnull actionTitle, void (^_Nonnull actionBlock)(void), void (^_Nonnull cancelBlock)(void)) {

        }
        transactionCreationCompletion:^BOOL(DSTransaction *_Nonnull tx, NSString *_Nonnull prompt, uint64_t amount, uint64_t proposedFee, NSArray<NSString *> *_Nonnull addresses, BOOL isSecure) {
            XCTAssertNotNil(tx, @"There should be a transaction");
            return TRUE;
        }
        signedCompletion:^BOOL(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL cancelled) {
            XCTAssertNotNil(tx, @"There should be a transaction");
            XCTAssertNil(error, @"There should be no error");
            return TRUE;
        }
        publishedCompletion:^(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL sent) {
            XCTAssertNotNil(tx, @"There should be a transaction");
            XCTAssertNil(error, @"There should be no error");
            XCTAssertTrue(send, @"Transaction should have been sent");
            [paymentFinishedExpectation fulfill];
        }
        errorNotificationBlock:^(NSError *_Nonnull error, NSString *_Nullable errorTitle, NSString *_Nullable errorMessage, BOOL shouldCancel) {
            XCTAssertNil(error, @"There should be no error");
        }];
    [self waitForExpectations:@[paymentFinishedExpectation] timeout:600];
}


@end
