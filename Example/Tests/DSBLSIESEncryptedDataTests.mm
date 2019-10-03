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

#import <DashSync/NSData+BLSEncryption.h>
#import "DSBLSKey+Private.h"
#import <DashSync/DSChain.h>

@interface DSBLSIESEncryptedDataTests : XCTestCase

@end

@implementation DSBLSIESEncryptedDataTests

- (void)testEncryptionAndDecryption {
    uint8_t aliceSeed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *aliceSeedData = [NSData dataWithBytes:aliceSeed length:10];
    DSBLSKey *aliceKeyPair = [DSBLSKey blsKeyWithPrivateKeyFromSeed:aliceSeedData onChain:[DSChain mainnet]];
    
    uint8_t bobSeed[10] = {10, 9, 8, 7, 6, 6, 7, 8, 9, 10};
    NSData *bobSeedData = [NSData dataWithBytes:bobSeed length:10];
    DSBLSKey *bobKeyPair = [DSBLSKey blsKeyWithPrivateKeyFromSeed:bobSeedData onChain:[DSChain mainnet]];
    

    NSString *secret = @"my little secret is a pony that never sleeps";
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    //Alice is sending to Bob
    NSData *encryptedData = [data encryptWithSecretKey:aliceKeyPair forPeerWithPublicKey:bobKeyPair];
    XCTAssertNotNil(encryptedData);
    
    //Bob is receiving from Alice
    NSData *decrypted = [encryptedData decryptWithSecretKey:bobKeyPair fromPeerWithPublicKey:aliceKeyPair];
    XCTAssertNotNil(decrypted);
    NSString * decryptedSecret = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(secret,decryptedSecret,@"they should be the same string");

}

@end
