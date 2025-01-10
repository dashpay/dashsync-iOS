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

#import <Foundation/Foundation.h>
#import "dash_shared_core.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Encryption)

- (nullable NSData *)encryptWithSecretKey:(DOpaqueKey *)secretKey forPublicKey:(DOpaqueKey *)peerPubKey;
- (nullable NSData *)encryptWithSecretKey:(DOpaqueKey *)secretKey forPublicKey:(DOpaqueKey *)peerPubKey usingInitializationVector:(NSData *)initializationVector;
- (nullable NSData *)decryptWithSecretKey:(DOpaqueKey *)secretKey fromPublicKey:(DOpaqueKey *)peerPubKey;
- (nullable NSData *)encryptWithDHKey:(DOpaqueKey *)dhKey;
- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<NSValue *> *)keys;
- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<NSValue *> *)keys;
- (nullable NSData *)encapsulatedDHEncryptionWithKeys:(NSArray<NSValue *> *)keys usingInitializationVector:(NSData *)initializationVector;
- (nullable NSData *)encapsulatedDHDecryptionWithKeys:(NSArray<NSValue *> *)keys usingIVSize:(NSUInteger)ivSize;

@end

NS_ASSUME_NONNULL_END
