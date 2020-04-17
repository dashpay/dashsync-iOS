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
    DSBLSKey *aliceKeyPair = [DSBLSKey keyWithPrivateKeyFromSeed:aliceSeedData];
    
    uint8_t bobSeed[10] = {10, 9, 8, 7, 6, 6, 7, 8, 9, 10};
    NSData *bobSeedData = [NSData dataWithBytes:bobSeed length:10];
    DSBLSKey *bobKeyPair = [DSBLSKey keyWithPrivateKeyFromSeed:bobSeedData];
    

    NSString *secret = @"my little secret is a pony that never sleeps";
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    //Alice is sending to Bob
    NSData *encryptedData = [data encryptWithSecretKey:aliceKeyPair forPeerWithPublicKey:bobKeyPair useInitializationVectorForTesting:@"eac5bcd6eb85074759e0261497428c9b".hexToData];
    XCTAssertNotNil(encryptedData);
    
    XCTAssertEqualObjects(encryptedData, @"eac5bcd6eb85074759e0261497428c9bd72bd418ce96e69cbb6766e59f8d1f8138afb0686018bb4d401369e77ba47367f93a49a528f4cc9e3f209a515e6dd8f2".hexToData, @"they should be the same data");
    
    //Bob is receiving from Alice
    NSData *decrypted = [encryptedData decryptWithSecretKey:bobKeyPair fromPeerWithPublicKey:aliceKeyPair];
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
    //Alice is sending to Bob
    NSData *encryptedData = [data encryptWithSecretKey:aliceKeyPair forPeerWithPublicKey:bobKeyPair useInitializationVectorForTesting:@"eac5bcd6eb85074759e0261497428c9b".hexToData];
    XCTAssertNotNil(encryptedData);
    
    XCTAssertEqualObjects(encryptedData, @"eac5bcd6eb85074759e0261497428c9b3725d3b9ec4d739a842116277c6ace81549089be0d11a54ee09a99dcf7ac695a8ea56d41bf0b62def90b6f78f8b0aca9".hexToData, @"they should be the same data");
    
    //Bob is receiving from Alice
    NSData *decrypted = [encryptedData decryptWithSecretKey:bobKeyPair fromPeerWithPublicKey:aliceKeyPair];
    XCTAssertNotNil(decrypted);
    NSString * decryptedSecret = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(secret,decryptedSecret,@"they should be the same string");

}

@end
