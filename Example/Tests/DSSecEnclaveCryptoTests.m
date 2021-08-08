//
//  Created by Andrew Podkovyrin
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

#import <DashSync/SecEnclaveCrypto.h>

@interface DSSecEnclaveCryptoTests : XCTestCase

@end

@implementation DSSecEnclaveCryptoTests

- (void)testAvailability {
    XCTAssert([SecEnclaveCrypto isAvailable], @"Should be available");
}

- (void)testFlow {
    NSString *str1 = @"hello world";
    NSData *plainData = [str1 dataUsingEncoding:NSUTF8StringEncoding];

    NSString *name = @"org.dash.pk-secencl.test1";
    SecEnclaveCrypto *crypto = [[SecEnclaveCrypto alloc] init];
    NSError *error = nil;
    NSData *encrypted = [crypto encrypt:plainData withPublicKeyName:name error:&error];
    XCTAssert(error == nil, @"Encryption failed");
    XCTAssertNotNil(encrypted);

    NSData *decrypted = [crypto decrypt:encrypted withPrivateKeyName:name error:&error];
    XCTAssert(error == nil, @"Decryption failed");
    XCTAssertNotNil(decrypted);

    NSString *str2 = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    XCTAssert([str1 isEqualToString:str2], @"Decryption failed");

    [crypto deletePrivateKeyWithName:name];
    BOOL hasKey = [crypto hasPrivateKeyName:name error:&error];
    XCTAssert(hasKey == NO, @"Failed to delete");
    XCTAssert(error == nil, @"Key check error");
}

- (void)testDecryptionWithoutKey {
    NSString *str1 = @"hello world";
    NSData *plainData = [str1 dataUsingEncoding:NSUTF8StringEncoding];

    NSString *name = @"org.dash.pk-secencl.test2";
    SecEnclaveCrypto *crypto = [[SecEnclaveCrypto alloc] init];

    // make sure there's no key
    [crypto deletePrivateKeyWithName:name];
    NSError *error = nil;
    BOOL hasKey = [crypto hasPrivateKeyName:name error:&error];
    XCTAssert(hasKey == NO, @"Failed to delete");
    XCTAssert(error == nil, @"Key check error");

    // doesn't matter what we're trying to decrypt
    NSData *decrypted = [crypto decrypt:plainData withPrivateKeyName:name error:&error];
    XCTAssert(error != nil, @"Decryption must fail");
    XCTAssertNil(decrypted);
}

- (void)testInvalidDecryption {
    NSString *str1 = @"hello world";
    NSData *plainData = [str1 dataUsingEncoding:NSUTF8StringEncoding];

    NSString *name = @"org.dash.pk-secencl.test3";
    SecEnclaveCrypto *crypto = [[SecEnclaveCrypto alloc] init];
    NSError *error = nil;
    [crypto encrypt:plainData withPublicKeyName:name error:&error];
    XCTAssert(error == nil, @"Encryption failed");

    // trying to decrypt **plain** data
    NSData *decrypted = [crypto decrypt:plainData withPrivateKeyName:name error:&error];
    XCTAssert(error != nil, @"Decryption must fail");
    XCTAssertNil(decrypted);

    [crypto deletePrivateKeyWithName:name];
}

@end
