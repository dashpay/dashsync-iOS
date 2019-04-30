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

#import <DashSync/DSBLSIESEncryptedData.h>
#import <DashSync/DSBLSKey.h>
#import <DashSync/DSChain.h>

@interface DSBLSIESEncryptedDataTests : XCTestCase

@end

@implementation DSBLSIESEncryptedDataTests

- (void)testEncryption {
    uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *seedData = [NSData dataWithBytes:seed length:10];
    DSBLSKey *keyPair = [DSBLSKey blsKeyWithPrivateKeyFromSeed:seedData onChain:[DSChain mainnet]];

    bls::PublicKey blsPublicKey = bls::PublicKey::FromBytes(keyPair.publicKey.u8);
    
    DSBLSIESEncryptedData *encryptedDate = [[DSBLSIESEncryptedData alloc] init];
    
    NSString *secret = @"my little secret";
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSData *result = [encryptedDate encryptWithPeerPublicKey:blsPublicKey
                                                        data:data];
    
    XCTAssertNotNil(result);
}

@end
