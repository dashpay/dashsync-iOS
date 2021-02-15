//  
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "NSData+Bitcoin.h"
#import "NSData+Encryption.h"
#import "DSBLSKey+Private.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSMutableData+Dash.h"

@interface DSIESEncryptedDataTests : XCTestCase

@end

@implementation DSIESEncryptedDataTests

- (void)testBLSEncryptionAndDecryption {
    uint8_t aliceSeed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *aliceSeedData = [NSData dataWithBytes:aliceSeed length:10];
    DSBLSKey *aliceKeyPair = [DSBLSKey keyWithSeedData:aliceSeedData];
    XCTAssertEqualObjects(aliceKeyPair.publicKeyData.hexString, @"1790635de8740e9a6a6b15fb6b72f3a16afa0973d971979b6ba54761d6e2502c50db76f4d26143f05459a42cfd520d44", @"BLS publicKeyData is incorrect");
    XCTAssertEqualObjects(aliceKeyPair.publicKeyData.base64String, @"F5BjXeh0DppqaxX7a3LzoWr6CXPZcZeba6VHYdbiUCxQ23b00mFD8FRZpCz9Ug1E", @"BLS publicKeyData is incorrect");
    
    XCTAssertEqualObjects(aliceKeyPair.privateKeyData.hexString, @"46891c2cec49593c81921e473db7480029e0fc1eb933c6b93d81f5370eb19fbd", @"BLS privateKeyData is incorrect");
    XCTAssertEqualObjects(aliceKeyPair.privateKeyData.base64String, @"RokcLOxJWTyBkh5HPbdIACng/B65M8a5PYH1Nw6xn70=", @"BLS privateKeyData is incorrect");
    
    XCTAssertEqualObjects([aliceKeyPair addressForChain:[DSChain testnet]], @"yi4HkZyrJQTKRD6p6p6Akiq7d1j1uBMYFP", @"BLS addressForChain testnet is incorrect");
    
    uint8_t bobSeed[10] = {10, 9, 8, 7, 6, 6, 7, 8, 9, 10};
    NSData *bobSeedData = [NSData dataWithBytes:bobSeed length:10];
    DSBLSKey *bobKeyPair = [DSBLSKey keyWithSeedData:bobSeedData];
    
    XCTAssertEqualObjects(bobKeyPair.publicKeyData.hexString, @"0e2f9055c17eb13221d8b41833468ab49f7d4e874ddf4b217f5126392a608fd48ccab3510548f1da4f397c1ad4f8e01a", @"BLS publicKeyData is incorrect");
    XCTAssertEqualObjects(bobKeyPair.publicKeyData.base64String, @"Di+QVcF+sTIh2LQYM0aKtJ99TodN30shf1EmOSpgj9SMyrNRBUjx2k85fBrU+OAa", @"BLS publicKeyData is incorrect");
    XCTAssertEqualObjects(bobKeyPair.privateKeyData.hexString, @"2513a9d824e763f8b3ff4304c5d52d05154a82b4c975da965f124e5dcf915805", @"BLS privateKeyData is incorrect");
    XCTAssertEqualObjects(bobKeyPair.privateKeyData.base64String, @"JROp2CTnY/iz/0MExdUtBRVKgrTJddqWXxJOXc+RWAU=", @"BLS privateKeyData is incorrect");
    
    XCTAssertEqualObjects([bobKeyPair addressForChain:[DSChain testnet]], @"yMfTGcBjCLxyefxAdSSyFnSYgU6cJzmrs2", @"BLS addressForChain testnet is incorrect");
    

    NSString *secret = @"my little secret is a pony that never sleeps";
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    //Alice is sending to Bob
    NSData *encryptedData = [data encryptWithSecretKey:aliceKeyPair forPublicKey:bobKeyPair usingInitializationVector:@"eac5bcd6eb85074759e0261497428c9b".hexToData];
    XCTAssertNotNil(encryptedData);
    
    XCTAssertEqualObjects(encryptedData, @"eac5bcd6eb85074759e0261497428c9bd72bd418ce96e69cbb6766e59f8d1f8138afb0686018bb4d401369e77ba47367f93a49a528f4cc9e3f209a515e6dd8f2".hexToData, @"they should be the same data");
    
    //Bob is receiving from Alice
    NSData *decrypted = [encryptedData decryptWithSecretKey:bobKeyPair fromPublicKey:aliceKeyPair];
    XCTAssertNotNil(decrypted);
    NSString * decryptedSecret = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(secret,decryptedSecret,@"they should be the same string");
}

- (void)testECDSAEncryptionAndDecryption {
    UInt256 aliceSecret = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    
    DSECDSAKey * aliceKeyPair = [DSECDSAKey keyWithSecret:aliceSecret compressed:YES];
    
    UInt256 bobSecret = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    
    DSECDSAKey *bobKeyPair = [DSECDSAKey keyWithSecret:bobSecret compressed:YES];
    

    NSString *secret = @"my little secret is a pony that never sleeps";
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    
    DSECDSAKey * key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:bobKeyPair forPrivateKey:aliceKeyPair];
    XCTAssertEqualObjects(key.publicKeyData.hexString, @"fbd27dbb9e7f471bf3de3704a35e884e37d35c676dc2cc8c3cc574c3962376d2", @"they should be the same data");
    //Alice is sending to Bob
    NSData *encryptedData = [data encryptWithSecretKey:aliceKeyPair forPublicKey:bobKeyPair usingInitializationVector:@"eac5bcd6eb85074759e0261497428c9b".hexToData];
    XCTAssertNotNil(encryptedData);
    
    XCTAssertEqualObjects(encryptedData.hexString, @"eac5bcd6eb85074759e0261497428c9b3725d3b9ec4d739a842116277c6ace81549089be0d11a54ee09a99dcf7ac695a8ea56d41bf0b62def90b6f78f8b0aca9", @"they should be the same data");
    
    //Bob is receiving from Alice
    NSData *decrypted = [encryptedData decryptWithSecretKey:bobKeyPair fromPublicKey:aliceKeyPair];
    XCTAssertNotNil(decrypted);
    NSString * decryptedSecret = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(secret,decryptedSecret,@"they should be the same string");

}

@end
