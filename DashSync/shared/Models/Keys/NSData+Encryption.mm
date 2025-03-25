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

#import "DSKeyManager.h"
#import "NSData+Encryption.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSData (Encryption)

- (nullable NSData *)encryptWithSecretKey:(DOpaqueKey *)secretKey forPublicKey:(DOpaqueKey *)peerPubKey {
    return [DSKeyManager encryptData:self secretKey:secretKey publicKey:peerPubKey];
}

- (nullable NSData *)encryptWithSecretKey:(DOpaqueKey *)secretKey forPublicKey:(DOpaqueKey *)peerPubKey usingInitializationVector:(NSData *)initializationVector {
    return [DSKeyManager encryptData:self secretKey:secretKey publicKey:peerPubKey usingIV:initializationVector];
}

- (nullable NSData *)decryptWithSecretKey:(DOpaqueKey *)secretKey fromPublicKey:(DOpaqueKey *)peerPubKey {
    return [DSKeyManager decryptData:self secretKey:secretKey publicKey:peerPubKey];
}

- (nullable NSData *)decryptWithSecretKey:(DOpaqueKey *)secretKey fromPublicKey:(DOpaqueKey *)peerPubKey usingIVSize:(NSUInteger)ivSize {
    return [DSKeyManager decryptData:self secretKey:secretKey publicKey:peerPubKey usingIVSize:ivSize];
}

- (nullable NSData *)encryptWithDHKey:(DOpaqueKey *)dhKey {
    return [DSKeyManager encryptData:self withDHKey:dhKey];
}

- (nullable NSData *)decryptWithDHKey:(DOpaqueKey *)dhKey {
    return [DSKeyManager decryptData:self withDHKey:dhKey];
}

- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<NSValue *> *)keys usingIVSize:(NSUInteger)ivSize {
    NSAssert(keys.count > 1, @"There should be at least two key (first pair)");
    if ([keys count] < 2) return self;

    DMaybeOpaqueKey *firstKey = (DMaybeOpaqueKey *)[keys firstObject].pointerValue;
    DMaybeOpaqueKey *secondKey = (DMaybeOpaqueKey *)[keys objectAtIndex:1].pointerValue;
    NSAssert(firstKey->ok, @"First key should be ok");
    NSAssert(secondKey->ok, @"Second key should be ok");
    NSData *encryptedData = [self decryptWithSecretKey:secondKey->ok fromPublicKey:firstKey->ok usingIVSize:ivSize];
    if (keys.count == 2) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHDecryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)] usingIVSize:ivSize];
    }
}

- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<NSValue *> *)keys {
    NSAssert(keys.count > 0, @"There should be at least one key");
    if (![keys count]) return self;
    DMaybeOpaqueKey *firstKey = (DMaybeOpaqueKey *) [keys firstObject].pointerValue;
    NSAssert(firstKey->ok, @"First key should be ok");
    NSData *encryptedData = [self decryptWithDHKey:firstKey->ok];
    if (keys.count == 1) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHDecryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)]];
    }
}

- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<NSValue *> *)keys {
    NSAssert(keys.count > 0, @"There should be at least one key");
    if (![keys count]) return self;
    DMaybeOpaqueKey *firstKey = (DMaybeOpaqueKey *) [keys firstObject].pointerValue;
    NSAssert(firstKey->ok, @"First key should be ok");
    NSData *encryptedData = [self encryptWithDHKey:firstKey->ok];
    if (keys.count == 1) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHEncryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)]];
    }
}

- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<NSValue *> *)keys usingInitializationVector:(NSData *)initializationVector {
    NSAssert(keys.count > 1, @"There should be at least two key (first pair)");
    if ([keys count] < 2) return self;

    DMaybeOpaqueKey *firstKey = (DMaybeOpaqueKey *) [keys firstObject].pointerValue;
    DMaybeOpaqueKey *secondKey = (DMaybeOpaqueKey *) [keys objectAtIndex:1].pointerValue;
    NSAssert(firstKey->ok, @"First key should be ok");
    NSAssert(secondKey->ok, @"Second key should be ok");

    NSData *encryptedData = [self encryptWithSecretKey:firstKey->ok forPublicKey:secondKey->ok usingInitializationVector:initializationVector];
    if (keys.count == 2) { //not really necessary but easier to read
        return encryptedData;
    } else {
        return [encryptedData encapsulatedDHEncryptionWithKeys:[keys subarrayWithRange:NSMakeRange(1, keys.count - 1)] usingInitializationVector:initializationVector];
    }
}

@end

NS_ASSUME_NONNULL_END
