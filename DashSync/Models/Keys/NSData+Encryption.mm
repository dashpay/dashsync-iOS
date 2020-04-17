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

#import "NSData+Encryption.h"
#import "DSBLSKey+Private.h"
#import "DSKey.h"
#import "DSECDSAKey.h"

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
    }
    else {
        free(buffer);
        
        return nil;
    }
}

@implementation NSData (Encryption)

- (nullable NSData *)encryptWithBLSSecretKey:(DSBLSKey*)secretKey forPeerWithPublicKey:(DSBLSKey*)peerPubKey {
    
    unsigned char iv[kCCBlockSizeAES128]; //16
    for (int i = 0; i < sizeof(iv); i++) {
        iv[i] = arc4random_uniform(UCHAR_MAX - 1);
    }
    
    bls::PublicKey pk = bls::BLS::DHKeyExchange(secretKey.blsPrivateKey, peerPubKey.blsPublicKey);
    
    std::vector<uint8_t> symKey = pk.Serialize();
    symKey.resize(32);
    
    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)symKey.data(), iv);
    
    NSMutableData * finalData = [NSMutableData dataWithBytes:iv length:16];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)encryptWithBLSSecretKey:(DSBLSKey*)secretKey forPeerWithPublicKey:(DSBLSKey*)peerPubKey useInitializationVectorForTesting:(NSData*)initializationVector {
    
    unsigned char * iv = (unsigned char *)initializationVector.bytes;
    
    bls::PublicKey pk = bls::BLS::DHKeyExchange(secretKey.blsPrivateKey, peerPubKey.blsPublicKey);
    
    std::vector<uint8_t> symKey = pk.Serialize();
    symKey.resize(32);
    
    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)symKey.data(), iv);
    
    NSMutableData * finalData = [NSMutableData dataWithBytes:iv length:16];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)decryptWithBLSSecretKey:(DSBLSKey*)secretKey fromPeerWithPublicKey:(DSBLSKey*)peerPubKey {
    if (self.length < kCCBlockSizeAES128) {
        return nil;
    }
    
    bls::PublicKey pk = bls::BLS::DHKeyExchange(secretKey.blsPrivateKey, peerPubKey.blsPublicKey);
    std::vector<uint8_t> symKey = pk.Serialize();
    symKey.resize(32);
    
    unsigned char iv[kCCBlockSizeAES128];
    
    [self getBytes:iv length:kCCBlockSizeAES128];
    
    NSData *encryptedData = [self subdataWithRange:NSMakeRange(kCCBlockSizeAES128, self.length - kCCBlockSizeAES128)];
    
    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, encryptedData, (uint8_t *)symKey.data(), iv);
    
    return resultData;
}

- (nullable NSData *)encryptWithECDSASecretKey:(DSECDSAKey*)secretKey forPeerWithPublicKey:(DSECDSAKey*)peerPubKey {
    
    unsigned char iv[kCCBlockSizeAES128]; //16
    for (int i = 0; i < sizeof(iv); i++) {
        iv[i] = arc4random_uniform(UCHAR_MAX - 1);
    }
    
    DSECDSAKey * key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];
    
    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)key.secretKey, iv);
    
    NSMutableData * finalData = [NSMutableData dataWithBytes:iv length:16];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)encryptWithECDSASecretKey:(DSECDSAKey*)secretKey forPeerWithPublicKey:(DSECDSAKey*)peerPubKey useInitializationVectorForTesting:(NSData*)initializationVector {
    
    unsigned char * iv = (unsigned char *)initializationVector.bytes;
    
    DSECDSAKey * key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];
    
    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, self, (uint8_t *)key.secretKey, iv);
    
    NSMutableData * finalData = [NSMutableData dataWithBytes:iv length:16];
    [finalData appendData:resultData];
    return finalData;
}

- (nullable NSData *)decryptWithECDSASecretKey:(DSECDSAKey*)secretKey fromPeerWithPublicKey:(DSECDSAKey*)peerPubKey {
    if (self.length < kCCBlockSizeAES128) {
        return nil;
    }
    
    DSECDSAKey * key = [DSECDSAKey keyWithDHKeyExchangeWithPublicKey:peerPubKey forPrivateKey:secretKey];
    
    unsigned char iv[kCCBlockSizeAES128];
    
    [self getBytes:iv length:kCCBlockSizeAES128];
    
    NSData *encryptedData = [self subdataWithRange:NSMakeRange(kCCBlockSizeAES128, self.length - kCCBlockSizeAES128)];
    
    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, encryptedData, (uint8_t *)key.secretKey, iv);
    
    return resultData;
}

- (nullable NSData *)encryptWithSecretKey:(DSKey*)secretKey forPeerWithPublicKey:(DSKey*)peerPubKey {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self encryptWithBLSSecretKey:(DSBLSKey*)secretKey forPeerWithPublicKey:(DSBLSKey*)peerPubKey];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self encryptWithECDSASecretKey:(DSECDSAKey*)secretKey forPeerWithPublicKey:(DSECDSAKey*)peerPubKey];
    } else {
        NSAssert(FALSE,@"Keys should be of same type");
    }
    return nil;
}

- (nullable NSData *)encryptWithSecretKey:(DSKey*)secretKey forPeerWithPublicKey:(DSKey*)peerPubKey useInitializationVectorForTesting:(NSData*)initializationVector {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self encryptWithBLSSecretKey:(DSBLSKey*)secretKey forPeerWithPublicKey:(DSBLSKey*)peerPubKey useInitializationVectorForTesting:initializationVector];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self encryptWithECDSASecretKey:(DSECDSAKey*)secretKey forPeerWithPublicKey:(DSECDSAKey*)peerPubKey useInitializationVectorForTesting:initializationVector];
    } else {
        NSAssert(FALSE,@"Keys should be of same type");
    }
    return nil;
}

- (nullable NSData *)decryptWithSecretKey:(DSKey*)secretKey fromPeerWithPublicKey:(DSKey*)peerPubKey {
    if ([secretKey isMemberOfClass:[DSBLSKey class]] && [peerPubKey isMemberOfClass:[DSBLSKey class]]) {
        return [self decryptWithBLSSecretKey:(DSBLSKey*)secretKey fromPeerWithPublicKey:(DSBLSKey*)peerPubKey];
    } else if ([secretKey isMemberOfClass:[DSECDSAKey class]] && [peerPubKey isMemberOfClass:[DSECDSAKey class]]) {
        return [self decryptWithECDSASecretKey:(DSECDSAKey*)secretKey fromPeerWithPublicKey:(DSECDSAKey*)peerPubKey];
    } else {
        NSAssert(FALSE,@"Keys should be of same type");
    }
    return nil;
}

@end

NS_ASSUME_NONNULL_END
