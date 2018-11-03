//
//  DSBLSKey.h
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSDerivationPath;

@interface DSBLSKey : NSObject

@property (nonatomic,readonly) uint32_t publicKeyFingerprint;
@property (nonatomic,readonly) UInt256 chainCode;
@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSData * extendedPrivateKeyData;
@property (nonatomic,readonly) NSData * extendedPublicKeyData;
@property (nonatomic,readonly) UInt256 secretKey;
@property (nonatomic,readonly) UInt384 publicKey;

+ (nullable instancetype)blsKeyWithPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain;
- (nullable instancetype)initWithPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain;
+ (nullable instancetype)blsKeyWithExtendedPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain;
- (nullable instancetype)initWithExtendedPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain;

- (DSBLSKey* _Nullable)deriveToPath:(DSDerivationPath* _Nonnull)derivationPath;
- (DSBLSKey* _Nullable)publicDeriveToPath:(DSDerivationPath* _Nonnull)derivationPath;

- (UInt768)signDigest:(UInt256)md;
- (UInt768)signData:(NSData * _Nonnull)data;

+ (UInt768)aggregateSignatures:(NSArray*)signatures withPublicKeys:(NSArray*)publicKeys withMessages:(NSArray*)messages;

//@property (nullable, nonatomic, readonly) NSData *publicKey;
//@property (nonatomic, readonly) UInt160 hash160;
//@property (nonatomic, readonly) const UInt256 secretKey;
//@property (nonatomic, readonly) uint32_t publicKeyFingerprint;
//
//
//
//- (nullable NSData *)sign:(UInt256)md;
//- (BOOL)verify:(UInt256)md signature:(nonnull NSData *)sig;
//
//- (NSString *)privateKeyStringForChain:(DSChain*)chain;
//- (NSString *)addressForChain:(DSChain*)chain;
//// Pieter Wuille's compact signature encoding used for bitcoin message signing
//// to verify a compact signature, recover a public key from the signature and verify that it matches the signer's pubkey
//- (nullable NSData *)compactSign:(UInt256)md;

@end

NS_ASSUME_NONNULL_END
