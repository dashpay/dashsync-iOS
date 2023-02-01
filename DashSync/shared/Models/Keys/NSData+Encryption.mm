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

#import "DSBLSKey+Private.h"
#import "DSECDSAKey.h"
#import "DSKey.h"
#import "NSData+Encryption.h"

#import <CommonCrypto/CommonCryptor.h>

NS_ASSUME_NONNULL_BEGIN

static NSData *_Nullable AES256EncryptDecrypt(CCOperation operation,
    NSData *data,
    const void *key,
    const void *iv) {
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    size_t encryptedSize = 0;
    CCCryptorStatus cryptStatus = CCCrypt(operation,
        kCCAlgorithmAES,
        kCCOptionPKCS7Padding,
        key,
        kCCKeySizeAES256,
        iv,
        data.bytes,
        data.length,
        buffer,
        bufferSize,
        &encryptedSize);

    if (cryptStatus == kCCSuccess) {
        NSData *result = [NSData dataWithBytes:buffer length:encryptedSize];
        free(buffer);

        return result;
    } else {
        free(buffer);

        return nil;
    }
}

@implementation NSData (Encryption)

+ (NSData *)randomInitializationVectorOfSize:(NSUInteger)size {
    unsigned char iv[size]; //16
    for (int i = 0; i < sizeof(iv); i++) {
        iv[i] = arc4random_uniform(UCHAR_MAX - 1);
    }
    return [NSData dataWithBytes:&iv length:size];
}

- (nullable NSData *)encryptWithBLSSecretKey:(DSBLSKey *)secretKey forPublicKey:(DSBLSKey *)publicKey {
    NSData *ivData = [NSData randomInitializationVectorOfSize:kCCBlockSizeAES128];

    return [self encryptWithBLSSecretKey:secretKey forPublicKey:publicKey usingInitializationVector:ivData];
}

- (nullable NSData *)encryptWithBLSSecretKey:(DSBLSKey *)secretKey forPublicKey:(DSBLSKey *)peerPubKey usingInitializationVector:(NSData *)ivData {
    if (secretKey.useLegacy != peerPubKey.useLegacy) {
        NSLog(@"encryptWithBLSSecretKey: BLS keys are from different mode %u != %u", secretKey.useLegacy, peerPubKey.useLegacy);
        return NULL;
    }
    bls::G1Element pk = secretKey.blsPrivateKey * peerPubKey.blsPublicKey;

    std::vector<uint8_t> symKey = pk.Serialize(secretKey.useLegacy);
    symKey.resize(32);

    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)symKey.data(), ivData.bytes);

    NSMutableData *finalData = [ivData mutableCopy];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)encryptWithDHBLSKey:(DSBLSKey *)dhKey {
    NSData *ivData = [NSData randomInitializationVectorOfSize:kCCBlockSizeAES128];

    return [self encryptWithDHBLSKey:dhKey usingInitializationVector:ivData];
}

- (nullable NSData *)encryptWithDHBLSKey:(DSBLSKey *)dhKey usingInitializationVector:(NSData *)initializationVector {
    unsigned char *iv = (unsigned char *)initializationVector.bytes;

    std::vector<uint8_t> symKey = dhKey.blsPublicKey.Serialize(dhKey.useLegacy);
    symKey.resize(32);

    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)symKey.data(), initializationVector.length ? iv : 0);

    NSMutableData *finalData = [initializationVector mutableCopy];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)decryptWithBLSSecretKey:(DSBLSKey *)secretKey fromPublicKey:(DSBLSKey *)peerPubKey usingIVSize:(NSUInteger)ivSize {
    if (self.length < ivSize) {
        return nil;
    }

    bls::G1Element pk = secretKey.blsPrivateKey * peerPubKey.blsPublicKey;
    std::vector<uint8_t> symKey = pk.Serialize(peerPubKey.useLegacy);
    symKey.resize(32);

    unsigned char iv[ivSize];

    [self getBytes:iv length:ivSize];

    NSData *encryptedData = [self subdataWithRange:NSMakeRange(ivSize, self.length - ivSize)];

    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, encryptedData, (uint8_t *)symKey.data(), ivSize ? iv : 0);

    return resultData;
}

- (nullable NSData *)decryptWithDHBLSKey:(DSBLSKey *)key {
    return [self decryptWithDHBLSKey:key usingIVSize:kCCBlockSizeAES128];
}

- (nullable NSData *)decryptWithDHBLSKey:(DSBLSKey *)key usingIVSize:(NSUInteger)ivSize {
    if (self.length < ivSize) {
        return nil;
    }

    bls::G1Element pk = key.blsPublicKey;
    std::vector<uint8_t> symKey = pk.Serialize(key.useLegacy);
    symKey.resize(32);

    unsigned char iv[ivSize];

    [self getBytes:iv length:ivSize];

    NSData *encryptedData = [self subdataWithRange:NSMakeRange(ivSize, self.length - ivSize)];

    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, encryptedData, (uint8_t *)symKey.data(), ivSize ? iv : 0);

    return resultData;
}

- (nullable NSData *)encryptWithECDSASecretKey:(DSECDSAKey *)secretKey forPublicKey:(DSECDSAKey *)peerPubKey {
    DSECDSAKey *key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];

    return [self encryptWithECDSAKey:key];
}

- (nullable NSData *)encryptWithECDSASecretKey:(DSECDSAKey *)secretKey forPublicKey:(DSECDSAKey *)peerPubKey useInitializationVectorForTesting:(NSData *)initializationVector {
    DSECDSAKey *key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];

    return [self encryptWithDHECDSAKey:key usingInitializationVector:initializationVector];
}

- (nullable NSData *)encryptWithECDSAKey:(DSECDSAKey *)dhKey {
    NSData *ivData = [NSData randomInitializationVectorOfSize:kCCBlockSizeAES128];

    return [self encryptWithDHECDSAKey:dhKey usingInitializationVector:ivData];
}

- (nullable NSData *)encryptWithDHECDSAKey:(DSECDSAKey *)dhKey usingInitializationVector:(NSData *)initializationVector {
    unsigned char *iv = (unsigned char *)initializationVector.bytes;

    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)dhKey.publicKeyData.bytes, initializationVector.length ? iv : 0);

    NSMutableData *finalData = [initializationVector mutableCopy];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)decryptWithECDSASecretKey:(DSECDSAKey *)secretKey fromPublicKey:(DSECDSAKey *)peerPubKey usingIVSize:(NSUInteger)ivSize {
    if (self.length < ivSize) {
        return nil;
    }

    DSECDSAKey *key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];

    return [self decryptWithDHECDSAKey:key usingIVSize:ivSize];
}

- (nullable NSData *)decryptWithDHECDSAKey:(DSECDSAKey *)key {
    return [self decryptWithDHECDSAKey:key usingIVSize:kCCBlockSizeAES128];
}

- (nullable NSData *)decryptWithDHECDSAKey:(DSECDSAKey *)key usingIVSize:(NSUInteger)ivSize {
    if (self.length < ivSize) {
        return nil;
    }

    unsigned char iv[ivSize];

    [self getBytes:iv length:ivSize];

    NSData *encryptedData = [self subdataWithRange:NSMakeRange(ivSize, self.length - ivSize)];

    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, encryptedData, (uint8_t *)key.publicKeyData.bytes, ivSize ? iv : 0);

    return resultData;
}

- (nullable NSData *)encryptWithSecretKey:(DSKey *)secretKey forPublicKey:(DSKey *)peerPubKey {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self encryptWithBLSSecretKey:(DSBLSKey *)secretKey forPublicKey:(DSBLSKey *)peerPubKey];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self encryptWithECDSASecretKey:(DSECDSAKey *)secretKey forPublicKey:(DSECDSAKey *)peerPubKey];
    } else {
        NSAssert(FALSE, @"Keys should be of same type");
    }
    return nil;
}

- (nullable NSData *)encryptWithSecretKey:(DSKey *)secretKey forPublicKey:(DSKey *)peerPubKey usingInitializationVector:(NSData *)initializationVector {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self encryptWithBLSSecretKey:(DSBLSKey *)secretKey forPublicKey:(DSBLSKey *)peerPubKey usingInitializationVector:initializationVector];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self encryptWithECDSASecretKey:(DSECDSAKey *)secretKey forPublicKey:(DSECDSAKey *)peerPubKey useInitializationVectorForTesting:initializationVector];
    } else {
        NSAssert(FALSE, @"Keys should be of same type");
    }
    return nil;
}

- (nullable NSData *)decryptWithSecretKey:(DSKey *)secretKey fromPublicKey:(DSKey *)peerPubKey {
    return [self decryptWithSecretKey:secretKey fromPublicKey:peerPubKey usingIVSize:kCCBlockSizeAES128];
}

- (nullable NSData *)decryptWithSecretKey:(DSKey *)secretKey fromPublicKey:(DSKey *)peerPubKey usingIVSize:(NSUInteger)ivSize {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self decryptWithBLSSecretKey:(DSBLSKey *)secretKey fromPublicKey:(DSBLSKey *)peerPubKey usingIVSize:ivSize];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self decryptWithECDSASecretKey:(DSECDSAKey *)secretKey fromPublicKey:(DSECDSAKey *)peerPubKey usingIVSize:ivSize];
    } else {
        NSAssert(FALSE, @"Keys should be of same type");
    }
    return nil;
}

- (nullable NSData *)encryptWithDHKey:(DSKey *)dhKey {
    if ([dhKey isMemberOfClass:[DSBLSKey class]]) {
        return [self encryptWithDHBLSKey:(DSBLSKey *)dhKey];
    } else if ([dhKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self encryptWithECDSAKey:(DSECDSAKey *)dhKey];
    } else {
        NSAssert(FALSE, @"Keys should be of a known type");
    }
    return nil;
}

- (nullable NSData *)decryptWithDHKey:(DSKey *)dhKey {
    if ([dhKey isMemberOfClass:[DSBLSKey class]]) {
        return [self decryptWithDHBLSKey:(DSBLSKey *)dhKey];
    } else if ([dhKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self decryptWithDHECDSAKey:(DSECDSAKey *)dhKey];
    } else {
        NSAssert(FALSE, @"Keys should be of a known type");
    }
    return nil;
}

- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<DSKey *> *)keys usingIVSize:(NSUInteger)ivSize {
    NSAssert(keys.count > 1, @"There should be at least two key (first pair)");
    if ([keys count] < 2) return self;

    DSKey *firstKey = [keys firstObject];
    DSKey *secondKey = [keys objectAtIndex:1];
    NSData *encryptedData = [self decryptWithSecretKey:secondKey fromPublicKey:firstKey usingIVSize:ivSize];
    if (keys.count == 2) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHDecryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)] usingIVSize:ivSize];
    }
}

- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<DSKey *> *)keys {
    NSAssert(keys.count > 0, @"There should be at least one key");
    if (![keys count]) return self;
    NSData *encryptedData = nil;
    DSKey *firstKey = [keys firstObject];
    if ([firstKey isMemberOfClass:[DSBLSKey class]]) {
        encryptedData = [self decryptWithDHBLSKey:(DSBLSKey *)firstKey];
    } else if ([firstKey isMemberOfClass:[DSECDSAKey class]]) {
        encryptedData = [self decryptWithDHECDSAKey:(DSECDSAKey *)firstKey];
    } else {
        NSAssert(FALSE, @"Keys should be of a known type");
    }
    if (keys.count == 1) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHDecryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)]];
    }
}

- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<DSKey *> *)keys {
    NSAssert(keys.count > 0, @"There should be at least one key");
    if (![keys count]) return self;
    NSData *encryptedData = nil;
    DSKey *firstKey = [keys firstObject];
    if ([firstKey isMemberOfClass:[DSBLSKey class]]) {
        encryptedData = [self encryptWithDHBLSKey:(DSBLSKey *)firstKey];
    } else if ([firstKey isMemberOfClass:[DSECDSAKey class]]) {
        encryptedData = [self encryptWithECDSAKey:(DSECDSAKey *)firstKey];
    } else {
        NSAssert(FALSE, @"Keys should be of a known type");
    }
    if (keys.count == 1) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHEncryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)]];
    }
}

- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<DSKey *> *)keys usingInitializationVector:(NSData *)initializationVector {
    NSAssert(keys.count > 1, @"There should be at least two key (first pair)");
    if ([keys count] < 2) return self;

    DSKey *firstKey = [keys firstObject];
    DSKey *secondKey = [keys objectAtIndex:1];
    NSData *encryptedData = [self encryptWithSecretKey:firstKey forPublicKey:secondKey usingInitializationVector:initializationVector];
    if (keys.count == 2) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHEncryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)] usingInitializationVector:initializationVector];
    }
}

@end

NS_ASSUME_NONNULL_END
