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

#import "DSBLSIESEncryptedData.h"

#import <CommonCrypto/CommonCryptor.h>

NS_ASSUME_NONNULL_BEGIN

static NSData *_Nullable AES256EncryptDecrypt(CCOperation operation,
                                       NSData *data,
                                       const void *key,
                                       size_t keyLength,
                                       const void *iv) {
    
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t encryptedSize = 0;
    CCCryptorStatus cryptStatus = CCCrypt(operation,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          key,
                                          keyLength,
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

@interface DSBLSIESEncryptedData () {
    unsigned char _iv[16];
    bls::PublicKey *ephemeralPubKey;
}

@end

@implementation DSBLSIESEncryptedData

- (nullable NSData *)encryptWithPeerPublicKey:(bls::PublicKey)peerPubKey data:(NSData *)data {
    if (data == nil) {
        return data;
    }
    
    unsigned char randomBuffer[32];
    for (int i = 0; i < sizeof(randomBuffer); i++) {
        randomBuffer[i] = arc4random_uniform(UCHAR_MAX - 1);
    }
    
    bls::PrivateKey secretKey = bls::PrivateKey::FromSeed(randomBuffer, sizeof(randomBuffer));
    bls::PublicKey publicKey = secretKey.GetPublicKey();
    ephemeralPubKey = &publicKey;
    [self generateIV];
    
    bls::PublicKey pk = bls::BLS::DHKeyExchange(secretKey, peerPubKey);
    
    std::vector<uint8_t> symKey = pk.Serialize();
    symKey.resize(32);
    
    NSData *resultData = AES256EncryptDecrypt(kCCEncrypt, data, (uint8_t *)symKey.data(), 32, _iv);
    
    return resultData;
}

- (nullable NSData *)decryptData:(NSData *)data secretKey:(bls::PrivateKey&)secretKey {
    if (!data) {
        return nil;
    }
    
    bls::PublicKey pk = bls::BLS::DHKeyExchange(secretKey, *ephemeralPubKey);
    std::vector<uint8_t> symKey = pk.Serialize();
    symKey.resize(32);
    
    NSData *resultData = AES256EncryptDecrypt(kCCDecrypt, data, (uint8_t *)symKey.data(), 32, _iv);
    
    return resultData;
}

#pragma mark - Private

- (void)generateIV {
    for (int i = 0; i < sizeof(_iv); i++) {
        _iv[i] = arc4random_uniform(UCHAR_MAX - 1);
    }
}

@end

NS_ASSUME_NONNULL_END
