//
//  DSECDSAKey.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 5/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSKey.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    uint8_t p[33];
} DSECPoint;

// adds 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int DSSecp256k1ModAdd(UInt256 * a, const UInt256 * b);

// multiplies 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int DSSecp256k1ModMul(UInt256 * a, const UInt256 * b);

// multiplies secp256k1 generator by 256bit big endian int i and stores the result in p
// returns true on success
int DSSecp256k1PointGen(DSECPoint * p, const UInt256 * i);

// multiplies secp256k1 generator by 256bit big endian int i and adds the result to ec-point p
// returns true on success
int DSSecp256k1PointAdd(DSECPoint * p, const UInt256 * i);

// multiplies secp256k1 ec-point p by 256bit big endian int i and stores the result in p
// returns true on success
int DSSecp256k1PointMul(DSECPoint * p, const UInt256 * i);

@class DSChain;

@interface DSECDSAKey : DSKey

@property (nonatomic, readonly, nullable) const UInt256 *secretKey;

+ (nullable instancetype)keyWithPrivateKey:(NSString *)privateKey onChain:(DSChain*)chain;
+ (nullable instancetype)keyWithSecret:(UInt256)secret compressed:(BOOL)compressed;
+ (nullable instancetype)keyWithPublicKey:(NSData *)publicKey;
+ (nullable instancetype)keyRecoveredFromCompactSig:(NSData *)compactSig andMessageDigest:(UInt256)md;

- (nullable instancetype)initWithPrivateKey:(NSString *)privateKey onChain:(DSChain*)chain;
- (nullable instancetype)initWithSecret:(UInt256)secret compressed:(BOOL)compressed;
- (nullable instancetype)initWithPublicKey:(NSData *)publicKey;
- (nullable instancetype)initWithCompactSig:(NSData *)compactSig andMessageDigest:(UInt256)md;

- (NSData * _Nullable)sign:(UInt256)md;

- (NSString * _Nullable)privateKeyStringForChain:(DSChain* _Nonnull)chain;
// Pieter Wuille's compact signature encoding used for bitcoin message signing
// to verify a compact signature, recover a public key from the signature and verify that it matches the signer's pubkey
- (NSData * _Nullable)compactSign:(UInt256)md;

- (BOOL)hasPrivateKey;

@end

NS_ASSUME_NONNULL_END
