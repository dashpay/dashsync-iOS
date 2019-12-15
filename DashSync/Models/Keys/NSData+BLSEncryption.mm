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

#import "NSData+BLSEncryption.h"
#import "DSBLSKey+Private.h"

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

@implementation NSData (BLSEncryption)

- (nullable NSData *)encryptWithSecretKey:(DSBLSKey*)secretKey forPeerWithPublicKey:(DSBLSKey*)peerPubKey {
    
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

- (nullable NSData *)decryptWithSecretKey:(DSBLSKey*)secretKey fromPeerWithPublicKey:(DSBLSKey*)peerPubKey {
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

@end

NS_ASSUME_NONNULL_END
