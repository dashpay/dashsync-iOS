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
#import "DSECDSAKey.h"
#import "DSChain+Protected.h"
#import "NSString+Bitcoin.h"
#import "DSTransaction.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSTransactionFactory.h"
#import "DSChainManager.h"
#import "NSData+Dash.h"
#import "DSTransactionManager.h"
#import "DSMasternodeManager.h"
#import "DSSporkManager.h"
#import "DSChainsManager.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSDerivationPath.h"
#import "DSFundsDerivationPath.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSTransition+Protected.h"
#import "DSCreditFundingTransaction.h"
#import "DSDocumentTransition.h"

@interface DSTransitionTests : XCTestCase

@property (nonatomic,strong) DSBlockchainIdentity * blockchainIdentity;
@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) DSWallet * testWallet;
@property (nonatomic,strong) DSAccount * testAccount;
@property (nonatomic,strong) NSData * seedData;

@end

@implementation DSTransitionTests

- (void)setUp {
    self.chain = [DSChain setUpDevnetWithIdentifier:@"0" withCheckpoints:nil withMinimumDifficultyBlocks:0 withDefaultPort:20001 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO isTransient:YES];
    NSString * seedPhrase = @"pigeon social employ east owner purpose buddy proof soul suit pumpkin punch";
    self.testWallet = [DSWallet standardWalletWithSeedPhrase:@"pigeon social employ east owner purpose buddy proof soul suit pumpkin punch" setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSBIP39Mnemonic * mnemonic = [DSBIP39Mnemonic new];
    self.seedData = [mnemonic deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    NSData * transactionData = @"0300000002b74030bbda6edd804d4bfb2bdbbb7c207a122f3af2f6283de17074a42c6a5417020000006b483045022100815b175ab1a8fde7d651d78541ba73d2e9b297e6190f5244e1957004aa89d3c902207e1b164499569c1f282fe5533154495186484f7db22dc3dc1ccbdc9b47d997250121027f69794d6c4c942392b1416566aef9eaade43fbf07b63323c721b4518127baadffffffffb74030bbda6edd804d4bfb2bdbbb7c207a122f3af2f6283de17074a42c6a5417010000006b483045022100a7c94fe1bb6ffb66d2bb90fd8786f5bd7a0177b0f3af20342523e64291f51b3e02201f0308f1034c0f6024e368ca18949be42a896dda434520fa95b5651dc5ad3072012102009e3f2eb633ee12c0143f009bf773155a6c1d0f14271d30809b1dc06766aff0ffffffff031027000000000000166a1414ec6c36e6c39a9181f3a261a08a5171425ac5e210270000000000001976a91414ec6c36e6c39a9181f3a261a08a5171425ac5e288acc443953b000000001976a9140d1775b9ed85abeb19fd4a7d8cc88b08a29fe6de88ac00000000".hexToData;
    DSCreditFundingTransaction * fundingTransaction = [[DSCreditFundingTransaction alloc] initWithMessage:transactionData onChain:self.chain];
    self.testAccount = [self.testWallet accountWithNumber:0];
    
    [self.testAccount registerTransaction:fundingTransaction saveImmediately:NO];
    
    NSMutableDictionary * usernameStatuses = [NSMutableDictionary dictionary];
    [usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(DSBlockchainIdentityUsernameStatus_Initial)} forKey:@"Bob"];
    
    self.blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:0 withFundingTransaction:fundingTransaction withUsernameDictionary:usernameStatuses inWallet:self.testWallet inContext:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testIdentityCreation {
    XCTestExpectation * expectation = [self expectationWithDescription:@"createFundingPrivateKeyWithSeed"];
    [self.blockchainIdentity createFundingPrivateKeyWithSeed:self.seedData completion:^(BOOL success) {
        XCTAssertTrue(success,@"No error should be produced");
        [self.blockchainIdentity registrationTransitionWithCompletion:^(DSBlockchainIdentityRegistrationTransition * _Nonnull blockchainIdentityRegistrationTransition, NSError * _Nonnull error) {
            XCTAssertNil(error,@"No error should be produced");
            DSKey * key = [blockchainIdentityRegistrationTransition.publicKeys allValues][0];
            XCTAssertEqualObjects(key.publicKeyData.hexString, @"031dd02c1fda3fa3f17b0e0b6ddd09c6dcf6a9e18ec5b15bd5705763425fba9a78");
            XCTAssertEqual(key.keyType, DSKeyType_ECDSA);
            XCTAssertEqualObjects(uint256_hex(blockchainIdentityRegistrationTransition.blockchainIdentityUniqueId), @"ae99d9433fc86f8974094c6a24fcc8cc68f87510c000d714c71ee5f64ceacf4b");
            XCTAssertEqual(blockchainIdentityRegistrationTransition.type, DSTransitionType_IdentityRegistration);
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testNameRegistration {
    //ToDo
}

- (void)testProfileCreation {
    //ToDo
}

-(void)testIdentityRegistrationData {
    NSData * identityRegistrationData =  @"a5647479706502697369676e61747572657858494653492f456e44427049443462324e36706b744c6f4a67437a6e56734c32336a594e6d5033414c5562514b4533424d356a696a56356f526f77445565496f455241573559464a5863705551742f64426f4f306e70774d3d6a7075626c69634b65797381a4626964016464617461782c4173507679796836706b7873732f46657370613748434a495938494136456c416636564b757156636e507a65647479706500696973456e61626c6564f56e6c6f636b65644f7574506f696e74783070527463783074453079646b474f446c424566574e49697644327736776876536b7659756e42352b68435541414141416f70726f746f636f6c56657273696f6e00".hexToData;
    DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = [[DSBlockchainIdentityRegistrationTransition alloc] initWithData:identityRegistrationData onChain:self.chain];
    DSKey * key = [blockchainIdentityRegistrationTransition.publicKeys allValues][0];
    XCTAssertEqualObjects(key.publicKeyData.hexString, @"02c3efcb287aa64c6cb3f15eb296bb1c224863c200e849407fa54abaa55c9cfcde");
    XCTAssertEqual(key.keyType, DSKeyType_ECDSA);
    XCTAssertEqualObjects(uint256_hex(blockchainIdentityRegistrationTransition.blockchainIdentityUniqueId), @"ae99d9433fc86f8974094c6a24fcc8cc68f87510c000d714c71ee5f64ceacf4b");
    XCTAssertEqual(blockchainIdentityRegistrationTransition.type, DSTransitionType_IdentityRegistration);
}

@end
