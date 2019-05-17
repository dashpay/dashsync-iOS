//
//  DSBLSKey.h
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSKey.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSDerivationPath;

@interface DSBLSKey : DSKey

@property (nonatomic,readonly) uint32_t publicKeyFingerprint;
@property (nonatomic,readonly) UInt256 chainCode;
@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSData * extendedPrivateKeyData;
@property (nonatomic,readonly) NSData * extendedPublicKeyData;
@property (nonatomic,readonly) UInt256 secretKey;
@property (nonatomic,readonly) UInt384 publicKey;

+ (nullable instancetype)blsKeyWithPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain;
- (nullable instancetype)initWithPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain;
+ (nullable instancetype)blsKeyWithExtendedPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain;
- (nullable instancetype)initWithExtendedPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain;
+ (nullable instancetype)blsKeyWithExtendedPublicKeyData:(NSData*)extendedPublicKey onChain:(DSChain*)chain;
- (nullable instancetype)initWithExtendedPublicKeyData:(NSData*)extendedPublicKey onChain:(DSChain*)chain;
+ (nullable instancetype)blsKeyWithPublicKey:(UInt384)publicKey onChain:(DSChain*)chain;
- (nullable instancetype)initWithPublicKey:(UInt384)publicKey onChain:(DSChain*)chain;
+ (nullable instancetype)blsKeyWithPrivateKey:(UInt256)secretKey onChain:(DSChain*)chain;
- (nullable instancetype)initWithPrivateKey:(UInt256)secretKey onChain:(DSChain*)chain;

- (DSBLSKey* _Nullable)deriveToPath:(NSIndexPath *)derivationPath;
- (DSBLSKey* _Nullable)publicDeriveToPath:(NSIndexPath *)derivationPath;

- (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature;

- (UInt768)signDigest:(UInt256)messageDigest;
- (UInt768)signData:(NSData *)data;
- (UInt768)signDataSingleSHA256:(NSData *)data;

- (NSData*)encryptData:(NSData*)data;

+ (UInt768)aggregateSignatures:(NSArray*)signatures withPublicKeys:(NSArray*)publicKeys withMessages:(NSArray*)messages;

@end

NS_ASSUME_NONNULL_END
