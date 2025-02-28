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
#import "dash_shared_core.h"
#import "DSAccount.h"
#import "DSAssetLockTransaction.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSIdentity+Protected.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSChainsManager.h"
#import "DSDerivationPath.h"
#import "DSFundsDerivationPath.h"
#import "DSInstantSendTransactionLock.h"
#import "DSKeyManager.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSSporkManager.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionFactory.h"
#import "DSTransactionManager.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSTransitionTests : XCTestCase

@property (nonatomic, strong) DSIdentity *identity;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSWallet *testWallet;
@property (nonatomic, strong) DSAccount *testAccount;
@property (nonatomic, strong) NSData *seedData;

@end

@implementation DSTransitionTests

- (void)setUp {
    self.chain = [DSChain testnet];
    NSString *seedPhrase = @"birth kingdom trash renew flavor utility donkey gasp regular alert pave layer";
    self.testWallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    self.seedData = [[DSBIP39Mnemonic new] deriveKeyFromPhrase:seedPhrase withPassphrase:nil];

    NSData *transactionData = @"03000800018ff03cc8d42a5e27be416d38e1b02718a111f03e6d7bfd178bd6cda26f33d3be010000006a4730440220765c83e5e908448ab2117a4abb806d21a3786d9642fc1883405c34367c1e5f3702207a0d1eae897e842b45632e57d02647ae193e8c7a247674399bc24d2d80799a88012102e25c6bbcbb1aa0a0c42283ded2d44e5c75551318a3c01d65906ac97aae1603e8ffffffff0240420f0000000000026a00c90ced02000000001976a914e97fe30aafd3666e70493b99cc35c0371d26654088ac0000000024010140420f00000000001976a91467575fc9d201b5ff36b5d8405497f1d961a56dbf88ac".hexToData;
//    NSData *transactionData = @"0300000002b74030bbda6edd804d4bfb2bdbbb7c207a122f3af2f6283de17074a42c6a5417020000006b483045022100815b175ab1a8fde7d651d78541ba73d2e9b297e6190f5244e1957004aa89d3c902207e1b164499569c1f282fe5533154495186484f7db22dc3dc1ccbdc9b47d997250121027f69794d6c4c942392b1416566aef9eaade43fbf07b63323c721b4518127baadffffffffb74030bbda6edd804d4bfb2bdbbb7c207a122f3af2f6283de17074a42c6a5417010000006b483045022100a7c94fe1bb6ffb66d2bb90fd8786f5bd7a0177b0f3af20342523e64291f51b3e02201f0308f1034c0f6024e368ca18949be42a896dda434520fa95b5651dc5ad3072012102009e3f2eb633ee12c0143f009bf773155a6c1d0f14271d30809b1dc06766aff0ffffffff031027000000000000166a1414ec6c36e6c39a9181f3a261a08a5171425ac5e210270000000000001976a91414ec6c36e6c39a9181f3a261a08a5171425ac5e288acc443953b000000001976a9140d1775b9ed85abeb19fd4a7d8cc88b08a29fe6de88ac00000000".hexToData;
    DSAssetLockTransaction *fundingTransaction = [[DSAssetLockTransaction alloc] initWithMessage:transactionData onChain:self.chain];
    fundingTransaction.instantSendLockAwaitingProcessing = [[DSInstantSendTransactionLock alloc] initWithTransactionHash:fundingTransaction.txHash
                                                                                                      withInputOutpoints:@[]
                                                                                                               signature:UINT768_ONE
                                                                                                               cycleHash:UINT256_ZERO
                                                                                                       signatureVerified:YES
                                                                                                          quorumVerified:YES
                                                                                                                 onChain:self.chain];
    self.testAccount = [self.testWallet accountWithNumber:0];
    [self.testAccount registerTransaction:fundingTransaction saveImmediately:NO];
    self.identity = [[DSIdentity alloc] initAtIndex:0
                           withAssetLockTransaction:fundingTransaction
                             withUsernameDictionary:@{@"Bob": @{BLOCKCHAIN_USERNAME_STATUS: @(DSIdentityUsernameStatus_Initial)}}
                                           inWallet:self.testWallet];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIdentityCreationUsingInstantProof {
    BOOL keyCreated = [self.identity createFundingPrivateKeyWithSeed:self.seedData isForInvitation:NO];
    XCTAssertTrue(keyCreated, @"No error should be produced");
    uint32_t index = [self.identity firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.identity.wallet.isTransient];
    DMaybeOpaqueKey *publicKey = [self.identity keyAtIndex:index];
    NSData *publicKeyData = [DSKeyManager NSDataFrom:dash_spv_crypto_keys_key_OpaqueKey_public_key_data(publicKey->ok)];
    NSLog(@"publicKeyData: %@", publicKeyData.hexString);
    DIdentityPublicKey *public_key = dash_spv_platform_identity_manager_identity_registration_public_key(index, publicKey->ok);
    DMaybeOpaqueKey *private_key = self.identity.registrationFundingPrivateKey;
    DSAssetLockTransaction *transaction = self.identity.registrationAssetLockTransaction;
    DAssetLockProof *instant_proof = [self.identity createProof:transaction.instantSendLockAwaitingProcessing];
    DMaybeStateTransition *result = dash_spv_platform_PlatformSDK_identity_registration_signed_transition_with_public_key_at_index(self.chain.sharedPlatformObj, public_key, index, instant_proof, private_key->ok);
    #if (defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_state_transitions_identity_identity_create_transition_v0_IdentityCreateTransitionV0 *identity_create_v0 = result->ok->identity_create->v0;
    dpp_state_transition_state_transitions_identity_public_key_in_creation_v0_IdentityPublicKeyInCreationV0 *first_key_v0 = identity_create_v0->public_keys->values[0]->v0;
    DKeyType key_type = first_key_v0->key_type[0];
    NSData *keyData = NSDataFromPtr(first_key_v0->data->_0);
    NSData *identityIdData = NSDataFromPtr(identity_create_v0->identity_id->_0->_0);
    XCTAssertEqual(key_type, dpp_identity_identity_public_key_key_type_KeyType_ECDSA_SECP256K1);
    XCTAssertEqualObjects(keyData.hexString, @"026ce9a9392503a57a8b4a4a16886f3cf5f5eacadbf62ca610c9d0fccc9a13eb4b");
    XCTAssertEqualObjects(identityIdData.hexString, @"5a1f5c860287868d87ba1beec292591e4771700738aef857be6fb35171299363");
    #endif
}

- (void)testIdentityCreationUsingChainProof {
    BOOL keyCreated = [self.identity createFundingPrivateKeyWithSeed:self.seedData isForInvitation:NO];
    XCTAssertTrue(keyCreated, @"No error should be produced");
    uint32_t index = [self.identity firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.identity.wallet.isTransient];
    DMaybeOpaqueKey *publicKey = [self.identity keyAtIndex:index];
    NSData *publicKeyData = [DSKeyManager NSDataFrom:dash_spv_crypto_keys_key_OpaqueKey_public_key_data(publicKey->ok)];
    NSLog(@"publicKeyData: %@", publicKeyData.hexString);
    DIdentityPublicKey *public_key = dash_spv_platform_identity_manager_identity_registration_public_key(index, publicKey->ok);
    DMaybeOpaqueKey *private_key = self.identity.registrationFundingPrivateKey;
    DAssetLockProof *chain_proof = [self.identity createProof:nil];
    DMaybeStateTransition *result = dash_spv_platform_PlatformSDK_identity_registration_signed_transition_with_public_key_at_index(self.chain.sharedPlatformObj, public_key, index, chain_proof, private_key->ok);
    #if (defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_state_transitions_identity_identity_create_transition_v0_IdentityCreateTransitionV0 *identity_create_v0 = result->ok->identity_create->v0;
    dpp_state_transition_state_transitions_identity_public_key_in_creation_v0_IdentityPublicKeyInCreationV0 *first_key_v0 = identity_create_v0->public_keys->values[0]->v0;
    DKeyType key_type = first_key_v0->key_type[0];
    NSData *keyData = NSDataFromPtr(first_key_v0->data->_0);
    NSData *identityIdData = NSDataFromPtr(identity_create_v0->identity_id->_0->_0);
    XCTAssertEqual(key_type, dpp_identity_identity_public_key_key_type_KeyType_ECDSA_SECP256K1);
    XCTAssertEqualObjects(keyData.hexString, @"026ce9a9392503a57a8b4a4a16886f3cf5f5eacadbf62ca610c9d0fccc9a13eb4b");
    XCTAssertEqualObjects(identityIdData.hexString, @"5a1f5c860287868d87ba1beec292591e4771700738aef857be6fb35171299363");
    #endif
}

- (void)testIdentitySigning {
    UInt256 digest = uint256_random;
    XCTestExpectation *expectation = [self expectationWithDescription:@"signedAndVerifiedMessage"];
    DMaybeOpaqueKey *key = [self.identity privateKeyAtIndex:0 ofType:DKeyKindECDSA() forSeed:self.seedData];
    NSData *signature = [DSKeyManager signMesasageDigest:key->ok digest:digest];
    XCTAssertFalse([signature isZeroBytes], "The blockchain identity should be able to sign a message digest");
    BOOL verified = [self.identity verifySignature:signature forKeyIndex:0 ofType:DKeyKindECDSA() forMessageDigest:digest];
    XCTAssertTrue(verified, "The blockchain identity should be able to verify the message it just signed");
    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *_Nullable error) { XCTAssertNil(error); }];
}

- (void)testNameRegistration {
    // ToDo
}

- (void)testProfileCreation {
    // ToDo
}

- (void)testIdentityRegistrationData {
    // ToDo again
    //     NSData * identityRegistrationData =  @"a5647479706502697369676e61747572657858494653492f456e44427049443462324e36706b744c6f4a67437a6e56734c32336a594e6d5033414c5562514b4533424d356a696a56356f526f77445565496f455241573559464a5863705551742f64426f4f306e70774d3d6a7075626c69634b65797381a4626964016464617461782c4173507679796836706b7873732f46657370613748434a495938494136456c416636564b757156636e507a65647479706500696973456e61626c6564f56e6c6f636b65644f7574506f696e74783070527463783074453079646b474f446c424566574e49697644327736776876536b7659756e42352b68435541414141416f70726f746f636f6c56657273696f6e00".hexToData;
    //     DSIdentityRegistrationTransition * identityRegistrationTransition = [[DSIdentityRegistrationTransition alloc] initWithData:identityRegistrationData onChain:self.chain];
    //     DSKey * key = [identityRegistrationTransition.publicKeys allValues][0];
    //     XCTAssertEqualObjects(key.publicKeyData.hexString, @"02c3efcb287aa64c6cb3f15eb296bb1c224863c200e849407fa54abaa55c9cfcde");
    //     XCTAssertEqual(key.keyType, KeyKind_ECDSA);
    //     XCTAssertEqualObjects(uint256_hex(identityRegistrationTransition.blockchainIdentityUniqueId), @"ae99d9433fc86f8974094c6a24fcc8cc68f87510c000d714c71ee5f64ceacf4b");
    //     XCTAssertEqual(identityRegistrationTransition.type, DSTransitionType_IdentityRegistration);
}

@end
