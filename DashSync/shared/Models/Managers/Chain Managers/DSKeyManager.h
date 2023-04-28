//  
//  Created by Vladimir Pirogov
//  Copyright © 2023 Dash Core Group. All rights reserved.
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
#import "DSChain.h"
#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@class DSDerivationPath;

// This is temporary class provides rust FFI for keys and some other things
@interface DSKeyManager : NSObject

- (instancetype)initWithChain:(DSChain *)chain;

+ (BOOL)hasPrivateKey:(OpaqueKey *)key;
+ (NSString *)secretKeyHexString:(OpaqueKey *)key;
+ (OpaqueKey *_Nullable)keyWithPrivateKeyString:(NSString *)key ofKeyType:(KeyKind)keyType forChainType:(ChainType)chainType;
+ (OpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(KeyKind)keyType;
+ (OpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(KeyKind)keyType;
+ (OpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(KeyKind)keyType;
+ (BOOL)keysPublicKeyDataIsEqual:(OpaqueKey *)key1 key2:(OpaqueKey *)key2;
+ (NSData *)signMesasageDigest:(OpaqueKey *)key digest:(UInt256)digest;
+ (BOOL)verifyMessageDigest:(OpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature;

+ (OpaqueKey *_Nullable)privateKeyAtIndexPath:(KeyKind)keyType indexes:(UInt256 *)indexes hardened:(BOOL *)hardened length:(NSUInteger)length indexPath:(NSIndexPath *)indexPath fromSeed:(NSData *)seed;
+ (OpaqueKey *_Nullable)publicKeyAtIndexPath:(OpaqueKey *)key indexPath:(NSIndexPath *)indexPath;
+ (NSData *_Nullable)publicKeyDataAtIndexPath:(OpaqueKey *)key indexPath:(NSIndexPath *)indexPath;

+ (NSData *)privateKeyData:(OpaqueKey *)key;
+ (NSData *)publicKeyData:(OpaqueKey *)key;
+ (NSData *)extendedPrivateKeyData:(OpaqueKey *)key;
+ (NSData *)extendedPublicKeyData:(OpaqueKey *)key;

+ (OpaqueKey *_Nullable)deriveKeyFromExtenedPrivateKeyDataAtIndexPath:(NSData *_Nullable)data indexPath:(NSIndexPath *)indexPath forKeyType:(KeyKind)keyType;
+ (OpaqueKey *_Nullable)keyPublicDeriveTo256Bit:(DSDerivationPath *)parentPath childIndexes:(UInt256 *)childIndexes childHardened:(BOOL *)childHardened length:(NSUInteger)length;

+ (NSString *)serializedPrivateKey:(OpaqueKey *)key chainType:(ChainType)chainType;

+ (NSString *)addressForKey:(OpaqueKey *)key forChainType:(ChainType)chainType;
+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(nonnull DSChain *)chain;
+ (NSString *_Nullable)addressWithScriptPubKey:(NSData *)script forChain:(nonnull DSChain *)chain;
+ (NSString *_Nullable)addressWithScriptSig:(NSData *)script forChain:(nonnull DSChain *)chain;
+ (NSString *)addressFromHash160:(UInt160)hash forChain:(nonnull DSChain *)chain;
+ (BOOL)isValidDashAddress:(NSString *)address forChain:(nonnull DSChain *)chain;
+ (NSData *)scriptPubKeyForAddress:(NSString *)address forChain:(nonnull DSChain *)chain;

+ (UInt160)ecdsaKeyPublicKeyHashFromSecret:(NSString *)secret forChainType:(ChainType)chainType;

+ (NSString *_Nullable)ecdsaKeyAddressFromPublicKeyData:(NSData *)data forChainType:(ChainType)chainType;
- (NSString *)ecdsaKeyPublicKeyUniqueIDFromDerivedKeyData:(UInt256)secret forChainType:(ChainType)chainType;
- (NSString *)keyRecoveredFromCompactSig:(NSData *)signature andMessageDigest:(UInt256)md;
+ (NSData *_Nullable)compactSign:(DSDerivationPath *)derivationPath fromSeed:(NSData *)seed atIndexPath:(NSIndexPath *)indexPath digest:(UInt256)digest;
+ (ECDSAKey *)ecdsaKeyWithPrivateKey:(NSString *)key forChainType:(ChainType)chainType;
+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key passphrase:(NSString *)passphrase forChainType:(ChainType)chainType;
+ (BOOL)isValidDashBIP38Key:(NSString *)key;
+ (OpaqueKey *_Nullable)keyDeprecatedExtendedPublicKeyFromSeed:(NSData *)seed indexes:(UInt256 *)indexes hardened:(BOOL *)hardened length:(NSUInteger)length;

+ (NSString *)NSStringFrom:(char *)c_string;
+ (NSData *)NSDataFrom:(ByteArray)byte_array;
+ (NSString *)localizedKeyType:(OpaqueKey *)key;

+ (UInt256)x11:(NSData *)data;
+ (UInt256)blake3:(NSData *)data;

+ (NSData *)encryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey;
+ (NSData *)encryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey usingIV:(NSData *)iv;
+ (NSData *)decryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey;
+ (NSData *)decryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey usingIVSize:(NSUInteger)ivSize;

+ (NSData *)encryptData:(NSData *)data withDHKey:(OpaqueKey *)dhKey;
+ (NSData *)decryptData:(NSData *)data withDHKey:(OpaqueKey *)dhKey;

+ (NSString *)keyStoragePrefix:(KeyKind)keyType;

/// Transactions
+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature payload:(NSData *)payload ownerKeyHash:(UInt160)ownerKeyHash;
+ (NSData *)proRegTXPayloadCollateralDigest:(NSData *)payload
                               scriptPayout:(NSData *)scriptPayout
                                     reward:(uint16_t)reward
                               ownerKeyHash:(UInt160)ownerKeyHash
                               voterKeyHash:(UInt160)voterKeyHash
                                  chainType:(ChainType)chainType;

+ (NSString *_Nullable)devnetIdentifierFor:(ChainType)chainType;

@end

NS_ASSUME_NONNULL_END
