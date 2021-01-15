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

#import "DSChain.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSMutableData+Dash.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "NSData+Encryption.h"

@interface DSChainedSigningTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSWallet *wallet;

@end

@implementation DSChainedSigningTests

- (void)setUp {
    self.chain = [DSChain mainnet];
    self.wallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.chain storeSeedPhrase:NO isTransient:YES];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:wallet];
    
    DSBLSKey * key0 = (DSBLSKey *)[derivationPath privateKeyAtIndex:0 fromSeed:seed];
    DSBLSKey * key1 = (DSBLSKey *)[derivationPath privateKeyAtIndex:1 fromSeed:seed];
    DSBLSKey * key2 = (DSBLSKey *)[derivationPath privateKeyAtIndex:2 fromSeed:seed];
    DSBLSKey * key3 = (DSBLSKey *)[derivationPath privateKeyAtIndex:3 fromSeed:seed];
    
    UInt256 randomInput0 = uint256_random;
    UInt256 randomInput1 = uint256_random;
    UInt256 randomInput2 = uint256_random;
    UInt256 randomInput3 = uint256_random;
    
    UInt256 randomOutput0 = uint256_random;
    UInt256 randomOutput1 = uint256_random;
    UInt256 randomOutput2 = uint256_random;
    UInt256 randomOutput3 = uint256_random;
    
    UInt512 concat0 = uint512_concat(randomInput0, randomOutput0);
    UInt512 concat1 = uint512_concat(randomInput1, randomOutput1);
    UInt512 concat2 = uint512_concat(randomInput2, randomOutput2);
    UInt512 concat3 = uint512_concat(randomInput3, randomOutput3);
    
    UInt256 hash0 = [[NSData dataWithUInt512:concat0] SHA256_2];
    UInt256 hash1 = [[NSData dataWithUInt512:concat1] SHA256_2];
    UInt256 hash2 = [[NSData dataWithUInt512:concat2] SHA256_2];
    UInt256 hash3 = [[NSData dataWithUInt512:concat3] SHA256_2];
    
    UInt768 signature0 = [key0 signDigest:hash0];
    UInt768 signature1 = [key1 signDigest:hash1];
    UInt768 signature2 = [key2 signDigest:hash2];
    UInt768 signature3 = [key3 signDigest:hash3];
    
    DSBLSKey * aggregateKey = [DSBLSKey keyByAggregatingPublicKeys:@[key0,key1,key2,key3]];
    
    UInt768 aggregateSignature = [DSBLSKey aggregateSignatures:@[uint768_data(signature0),uint768_data(signature1),uint768_data(signature2),uint768_data(signature3)] withPublicKeys:@[key0,key1,key2,key3] withMessages:@[uint256_data(hash0),uint256_data(hash1),uint256_data(hash2),uint256_data(hash3)]];
    
    BOOL verified = [DSBLSKey verifyAggregatedSignature:aggregateSignature withPublicKeys:@[key0,key1,key2,key3] withMessages:@[uint256_data(hash0),uint256_data(hash1),uint256_data(hash2),uint256_data(hash3)]];
    
    XCTAssert(verified,@"DSBLSKey verifyAggregatedSignature is working");
    
    NSArray <DSBLSKey *> * quorums = [derivationPath privateKeysForRange:NSMakeRange(1000, 8) fromSeed:seed]; //simulate 10 quorums
    
    UInt256 signingSession = uint256_random;
    
    NSData * signatureData0 = uint768_data(signature0);
    NSArray * keysForDH0 = [@[key0] arrayByAddingObjectsFromArray:quorums];
    NSData * encryptedSignatureData0 = [signatureData0 encapsulatedDHEncryptionWithKeys:keysForDH0 usingInitializationVector:[NSData data]];
    NSData * signatureDataRoundTrip0 = [encryptedSignatureData0 encapsulatedDHDecryptionWithKeys:[[keysForDH0 reverseObjectEnumerator] allObjects] usingIVSize:0];
    
    XCTAssertEqualObjects(signatureData0, signatureDataRoundTrip0,@"these should be equal");
    
    NSData * encryptedSignatureData1 = [signatureData0 encapsulatedDHEncryptionWithKeys:keysForDH0 usingInitializationVector:[NSData data]];
    
    //at node n, quorum checks that signature matches
}

@end
