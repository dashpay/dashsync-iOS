//
//  DSBLSSignatures.h
//  DashSync
//
//  Created by Andrew Podkovyrin on 02/11/2018.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSDerivationPath;

@interface DSBLSSignatures : NSObject

+(UInt256)privateKeyDerivedFromBytes:(uint8_t *)seed toPath:(DSDerivationPath*)derivationPath;
+(UInt256)privateKeyDerivedFromSeed:(uint8_t *)seed seedLength:(size_t)seedLength toPath:(DSDerivationPath*)derivationPath;

+(UInt256)chainCodeFromSeed:(uint8_t *)seed seedLength:(size_t)seedLength derivedToPath:(DSDerivationPath* _Nullable)derivationPath;

+(uint32_t)publicKeyFingerprintFromPrivateKey:(UInt256)privateKey;
+(uint32_t)publicKeyFingerprintFromPrivateKeyFromBytes:(uint8_t*)privateKeyBytes;
+(uint32_t)publicKeyFingerprintFromPrivateKeyFromSeed:(uint8_t*)seed seedLength:(size_t)seedLength;

+(uint32_t)publicKeyFingerprintFromExtendedPrivateKeyFromSeed:(uint8_t*)seed seedLength:(size_t)seedLength;

@end

NS_ASSUME_NONNULL_END
