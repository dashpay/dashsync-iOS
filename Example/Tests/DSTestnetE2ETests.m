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
@property (strong, nonatomic) DSWallet *testWallet1;
@property (strong, nonatomic) DSWallet *testWallet2;
@property (strong, nonatomic) DSWallet *blockchainIdentityWallet;
@property (strong, nonatomic) DSAccount *fundingAccount1;
@property (strong, nonatomic) DSAccount *fundingAccount2;
@property (strong, nonatomic) id blocksObserver, txStatusObserver;
@end

@implementation DSTestnetE2ETests

#define TE2ERESETNETWORK 1

- (void)setUp {
    self.chain = [DSChain testnet];
    //this will only be run once before all tests
    uint8_t seed[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    NSData *seedData = [NSData dataWithBytes:seed length:12];
    self.sweepKey = [DSECDSAKey keyWithSeedData:seedData];
    self.transactionManager = self.chain.chainManager.transactionManager;
    self.identitiesManager = self.chain.chainManager.identitiesManager;

    static DSWallet *staticTestWallet1;
    static DSWallet *staticTestWallet2;
    static DSWallet *staticFaucetWallet;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self.chain unregisterAllWallets];

        staticFaucetWallet = [DSWallet standardWalletWithSeedPhrase:@"gather jeans tourist era ride enable cover disease between need nature blood" setCreationDate:1619235036 forChain:self.chain storeSeedPhrase:YES isTransient:NO];

        //this is run only the first time
        staticTestWallet1 = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:YES isTransient:NO];
        staticTestWallet2 = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:YES isTransient:NO];

        [self.chain useCheckpointBeforeOrOnHeightForSyncingChainBlocks:4800000];
        [self.chain useCheckpointBeforeOrOnHeightForTerminalBlocksSync:UINT32_MAX];
#if TE2ERESETNETWORK
        [[DashSync sharedSyncController] wipeBlockchainNonTerminalDataForChain:self.chain
                                                                     inContext:[NSManagedObjectContext chainContext]];
#endif
    });

    self.testWallet1 = staticTestWallet1;
    self.testWallet2 = staticTestWallet2;
    self.faucetWallet = staticFaucetWallet;
    self.fundingAccount1 = self.testWallet1.accounts[0];
    self.fundingAccount2 = self.testWallet2.accounts[0];

    if (![self.chain addWallet:self.faucetWallet]) {
        for (DSWallet *wallet in self.chain.wallets) {
            if ([wallet.uniqueIDString isEqualToString:self.faucetWallet.uniqueIDString]) {
                self.faucetWallet = wallet;
                break;
            }
        }
    }

    if (![self.chain addWallet:self.testWallet1]) {
        for (DSWallet *wallet in self.chain.wallets) {
            if ([wallet.uniqueIDString isEqualToString:self.testWallet1.uniqueIDString]) {
                self.testWallet1 = wallet;
                break;
            }
        }
    }

    if (![self.chain addWallet:self.testWallet2]) {
        for (DSWallet *wallet in self.chain.wallets) {
            if ([wallet.uniqueIDString isEqualToString:self.testWallet2.uniqueIDString]) {
                self.testWallet2 = wallet;
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

- (void)testBFundTestAccounts {
    DSAccount *faucetAccount = self.faucetWallet.accounts[0];

    DSTransaction *transaction1 = [faucetAccount transactionFor:1200000 to:self.fundingAccount1.receiveAddress withFee:YES];
    XCTestExpectation *transaction1FinishedExpectation = [[XCTestExpectation alloc] init];
    [faucetAccount signTransaction:transaction1
                        withPrompt:nil
                        completion:^(BOOL signedTransaction, BOOL cancelled) {
                            XCTAssert(signedTransaction, @"Transaction should be signed");
                            XCTAssert(transaction1.isSigned, @"Transaction should be signed");

                            __block BOOL sent = NO;

                            [self.transactionManager publishTransaction:transaction1
                                                             completion:^(NSError *error) {
                                                                 XCTAssertNil(error, @"There should not be an error");
                                                                 if (!sent) {
                                                                     sent = YES;
                                                                     [faucetAccount registerTransaction:transaction1 saveImmediately:YES];
                                                                     [transaction1FinishedExpectation fulfill];
                                                                 }
                                                             }];
                        }];
    [self waitForExpectations:@[transaction1FinishedExpectation] timeout:120];
    DSTransaction *transaction2 = [faucetAccount transactionFor:1100000 to:self.fundingAccount2.receiveAddress withFee:YES];
    XCTestExpectation *transaction2FinishedExpectation = [[XCTestExpectation alloc] init];
    [faucetAccount signTransaction:transaction2
                        withPrompt:nil
                        completion:^(BOOL signedTransaction, BOOL cancelled) {
                            XCTAssert(signedTransaction, @"Transaction should be signed");
                            XCTAssert(transaction2.isSigned, @"Transaction should be signed");

                            __block BOOL sent = NO;

                            [self.transactionManager publishTransaction:transaction2
                                                             completion:^(NSError *error) {
                                                                 XCTAssertNil(error, @"There should not be an error");
                                                                 if (!sent) {
                                                                     sent = YES;
                                                                     [faucetAccount registerTransaction:transaction2 saveImmediately:YES];
                                                                     [transaction2FinishedExpectation fulfill];
                                                                 }
                                                             }];
                        }];
    [self waitForExpectations:@[transaction2FinishedExpectation] timeout:120];
}

- (void)testCWalletHasFunds {
    XCTAssert(self.fundingAccount1.balance >= 1200000); //Wallet must have at least 0.12 Dash
    XCTAssert(self.fundingAccount2.balance >= 1100000); //Wallet must have at least 0.11 Dash
}

- (void)testDSendTransactionToKey {
    NSString *addressToSendTo = [self.sweepKey addressForChain:self.chain];

    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:addressToSendTo onChain:self.chain];
    paymentRequest.amount = 10000;
    DSPaymentProtocolRequest *protocolRequest = paymentRequest.protocolRequest;
    DSTransaction *transaction = [self.fundingAccount1 transactionForAmounts:protocolRequest.details.outputAmounts toOutputScripts:protocolRequest.details.outputScripts withFee:TRUE];
    XCTestExpectation *transactionFinishedExpectation = [[XCTestExpectation alloc] init];
    [self.fundingAccount1 signTransaction:transaction
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
                                                                            [self.fundingAccount1 registerTransaction:transaction saveImmediately:YES]; //not sure this is needed
                                                                            [transactionFinishedExpectation fulfill];
                                                                        }
                                                                    }];
                               }];
    [self waitForExpectations:@[transactionFinishedExpectation] timeout:60];
}

- (void)testESweepKey {
    uint64_t originalBalance = self.fundingAccount1.balance;
    XCTestExpectation *transactionFinishedExpectation = [[XCTestExpectation alloc] init];
    //we need to wait a few seconds for the transaction to propagate on the network
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.fundingAccount1 sweepPrivateKey:[self.sweepKey serializedPrivateKeyForChain:self.chain]
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
                                                                                [self.fundingAccount1 registerTransaction:sweepTransaction saveImmediately:YES]; //not sure this is needed
                                                                                XCTAssert(self.fundingAccount1.balance > originalBalance, @"Balance should be increased");
                                                                                [transactionFinishedExpectation fulfill];
                                                                            }
                                                                        }];
                                   }];
    });
    [self waitForExpectations:@[transactionFinishedExpectation] timeout:120];
}

- (void)testFRegisterIdentities {
    NSString *username1a = [NSString stringWithFormat:@"CIIOSTestUser1a%llu", (uint64_t)[NSDate timeIntervalSince1970]];
    NSString *username1b = [NSString stringWithFormat:@"CIIOSTestUser1b%llu", (uint64_t)[NSDate timeIntervalSince1970]];
    NSString *username2a = [NSString stringWithFormat:@"CIIOSTestUser2a%llu", (uint64_t)[NSDate timeIntervalSince1970]];
    DSBlockchainIdentity *blockchainIdentity1a = [self.testWallet1 createBlockchainIdentityForUsername:username1a usingDerivationIndex:0];
    DSBlockchainIdentity *blockchainIdentity1b = [self.testWallet1 createBlockchainIdentityForUsername:username1b usingDerivationIndex:1];

    DSBlockchainIdentity *blockchainIdentity2a = [self.testWallet2 createBlockchainIdentityForUsername:username2a];

    DSBlockchainIdentityRegistrationStep steps = DSBlockchainIdentityRegistrationStep_RegistrationStepsWithUsername;
    XCTestExpectation *identityRegistrationFinishedExpectation1a = [[XCTestExpectation alloc] init];
    [blockchainIdentity1a generateBlockchainIdentityExtendedPublicKeysWithPrompt:@""
                                                                      completion:^(BOOL registered) {
                                                                          [blockchainIdentity1a createFundingPrivateKeyWithPrompt:@""
                                                                                                                       completion:^(BOOL success, BOOL cancelled) {
                                                                                                                           if (success && !cancelled) {
                                                                                                                               [blockchainIdentity1a registerOnNetwork:steps
                                                                                                                                   withFundingAccount:self.fundingAccount1
                                                                                                                                   forTopupAmount:10000
                                                                                                                                   stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {

                                                                                                                                   }
                                                                                                                                   completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
                                                                                                                                       XCTAssertNil(error, @"There should not be an error");
                                                                                                                                       XCTAssert(stepsCompleted = steps, @"We should have completed the same amount of steps that were requested");
                                                                                                                                       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                                                                           [identityRegistrationFinishedExpectation1a fulfill];
                                                                                                                                       });
                                                                                                                                   }];
                                                                                                                           }
                                                                                                                       }];
                                                                      }];
    [self waitForExpectations:@[identityRegistrationFinishedExpectation1a] timeout:600];
    XCTestExpectation *identityRegistrationFinishedExpectation1b = [[XCTestExpectation alloc] init];
    [blockchainIdentity1b generateBlockchainIdentityExtendedPublicKeysWithPrompt:@""
                                                                      completion:^(BOOL registered) {
                                                                          [blockchainIdentity1b createFundingPrivateKeyWithPrompt:@""
                                                                                                                       completion:^(BOOL success, BOOL cancelled) {
                                                                                                                           if (success && !cancelled) {
                                                                                                                               [blockchainIdentity1b registerOnNetwork:steps
                                                                                                                                   withFundingAccount:self.fundingAccount1
                                                                                                                                   forTopupAmount:10000
                                                                                                                                   stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {

                                                                                                                                   }
                                                                                                                                   completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
                                                                                                                                       XCTAssertNil(error, @"There should not be an error");
                                                                                                                                       XCTAssert(stepsCompleted = steps, @"We should have completed the same amount of steps that were requested");
                                                                                                                                       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                                                                           [identityRegistrationFinishedExpectation1b fulfill];
                                                                                                                                       });
                                                                                                                                   }];
                                                                                                                           }
                                                                                                                       }];
                                                                      }];
    [self waitForExpectations:@[identityRegistrationFinishedExpectation1b] timeout:600];
    XCTestExpectation *identityRegistrationFinishedExpectation2a = [[XCTestExpectation alloc] init];
    [blockchainIdentity2a generateBlockchainIdentityExtendedPublicKeysWithPrompt:@""
                                                                      completion:^(BOOL registered) {
                                                                          [blockchainIdentity2a createFundingPrivateKeyWithPrompt:@""
                                                                                                                       completion:^(BOOL success, BOOL cancelled) {
                                                                                                                           if (success && !cancelled) {
                                                                                                                               [blockchainIdentity2a registerOnNetwork:steps
                                                                                                                                   withFundingAccount:self.fundingAccount1
                                                                                                                                   forTopupAmount:10000
                                                                                                                                   stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {

                                                                                                                                   }
                                                                                                                                   completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
                                                                                                                                       XCTAssertNil(error, @"There should not be an error");
                                                                                                                                       XCTAssert(stepsCompleted = steps, @"We should have completed the same amount of steps that were requested");
                                                                                                                                       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                                                                           [identityRegistrationFinishedExpectation2a fulfill];
                                                                                                                                       });
                                                                                                                                   }];
                                                                                                                           }
                                                                                                                       }];
                                                                      }];
    [self waitForExpectations:@[identityRegistrationFinishedExpectation2a] timeout:600];
}

- (void)testGSendAndAcceptContactRequestSameWallet {
    NSArray *blockchainIdentities = [self.testWallet1.blockchainIdentities allValues];
    XCTAssert(blockchainIdentities.count > 1, @"There should be at least 2 identities");
    DSBlockchainIdentity *identityA = blockchainIdentities.firstObject;
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

- (void)testHSendAndAcceptContactRequestDifferentWallet {
    DSBlockchainIdentity *identityA = self.testWallet1.blockchainIdentities.allValues.firstObject;
    DSBlockchainIdentity *identityB = self.testWallet2.blockchainIdentities.allValues.firstObject;
    XCTAssert(identityA != nil, @"Identity A must exist");
    XCTAssert(identityB != nil, @"Identity B must exist");
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

- (void)testISendDashpayPaymentSameWallet {
    NSArray *blockchainIdentities = [self.testWallet1.blockchainIdentities allValues];
    XCTAssert(blockchainIdentities.count > 1, @"There should be at least 2 identities");
    DSBlockchainIdentity *identityA = blockchainIdentities.firstObject;
    DSBlockchainIdentity *identityB = blockchainIdentities.lastObject;

    XCTAssert(identityA != identityB, @"There should be at least 2 identities");

    DSDashpayUserEntity *dashpayUser = [identityA matchingDashpayUserInViewContext];
    XCTAssert(dashpayUser.friends.count > 0);
    XCTestExpectation *paymentFinishedExpectation = [[XCTestExpectation alloc] init];
    [dashpayUser sendAmount:10000
        fromAccount:self.fundingAccount1
        toFriendWithIdentityIdentifier:identityB.uniqueID
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

- (void)testJSendDashpayPaymentDifferentWallet {
    DSBlockchainIdentity *identityA = self.testWallet1.blockchainIdentities.allValues.firstObject;
    DSBlockchainIdentity *identityB = self.testWallet2.blockchainIdentities.allValues.firstObject;

    XCTAssert(identityA != nil, @"Identity A must exist");
    XCTAssert(identityB != nil, @"Identity B must exist");
    XCTAssert(identityA != identityB, @"There should be at least 2 identities");

    DSDashpayUserEntity *dashpayUser = [identityA matchingDashpayUserInViewContext];
    XCTAssert(dashpayUser.friends.count > 0);
    XCTestExpectation *paymentFinishedExpectation = [[XCTestExpectation alloc] init];
    [dashpayUser sendAmount:10000
        fromAccount:self.fundingAccount1
        toFriendWithIdentityIdentifier:identityB.uniqueID
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
