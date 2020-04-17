//
//  DSECDSAKey.m
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

#import "DSECDSAKey.h"
#import "NSString+Dash.h"
#import "NSData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSKey+Protected.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#import "secp256k1.h"
#import "secp256k1_recovery.h"
#import "secp256k1_ecdh.h"

#pragma clang diagnostic pop

#define ECDSA_EXTENDED_SECRET_KEY_SIZE 68

static secp256k1_context *_ctx = NULL;
static dispatch_once_t _ctx_once = 0;

// BIP32 is a scheme for deriving chains of addresses from a seed value
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki

// Private parent key -> private child key
//
// CKDpriv((kpar, cpar), i) -> (ki, ci) computes a child extended private key from the parent extended private key:
//
// - Check whether i >= 2^31 (whether the child is a hardened key).
//     - If so (hardened child): let I = HMAC-SHA512(Key = cpar, Data = 0x00 || ser256(kpar) || ser32(i)).
//       (Note: The 0x00 pads the private key to make it 33 bytes long.)
//     - If not (normal child): let I = HMAC-SHA512(Key = cpar, Data = serP(point(kpar)) || ser32(i)).
// - Split I into two 32-byte sequences, IL and IR.
// - The returned child key ki is parse256(IL) + kpar (mod n).
// - The returned chain code ci is IR.
// - In case parse256(IL) >= n or ki = 0, the resulting key is invalid, and one should proceed with the next value for i
//   (Note: this has probability lower than 1 in 2^127.)
//
void CKDpriv(UInt256 *k, UInt256 *c, uint32_t i)
{
    uint8_t buf[sizeof(DSECPoint) + sizeof(i)];
    UInt512 I;
    
    if (i & BIP32_HARD) {
        buf[0] = 0;
        *(UInt256 *)&buf[1] = *k;
    }
    else DSSecp256k1PointGen((DSECPoint *)buf, k);
    
    *(uint32_t *)&buf[sizeof(DSECPoint)] = CFSwapInt32HostToBig(i);
    NSLog(@"c is %@, buf is %@",uint256_hex(*c),[NSData dataWithBytes:buf length:sizeof(DSECPoint) + sizeof(i)].hexString);
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, k|P(k) || i)
    NSLog(@"c now is %@, I now is %@",uint256_hex(*c),uint512_hex(I));
    DSSecp256k1ModAdd(k, (UInt256 *)&I); // k = IL + k (mod n)
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

void CKDpriv256(UInt256 *k, UInt256 *c, UInt256 i, BOOL hardened)
{
    BOOL iIs31Bits = uint256_is_31_bits(i);
    uint32_t smallI;
    uint32_t length = sizeof(DSECPoint) + (iIs31Bits?sizeof(smallI):((sizeof(i) + sizeof(hardened))));
    uint8_t buf[length];
    UInt512 I;
    
    if (hardened) {
        buf[0] = 0;
        *(UInt256 *)&buf[1] = *k;
    }
    else DSSecp256k1PointGen((DSECPoint *)buf, k);

    if (iIs31Bits) {
        //we are deriving a 31 bit integer
        smallI = i.u32[0];
        if (hardened) smallI |= BIP32_HARD;
        smallI = CFSwapInt32HostToBig(smallI);
        *(uint32_t *)&buf[sizeof(DSECPoint)] = smallI;
    } else {
        *(BOOL *)&buf[sizeof(DSECPoint)] = hardened;
        *(UInt256 *)&buf[sizeof(DSECPoint) + sizeof(hardened)] = i;
    }
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, k|P(k) || i)
    DSSecp256k1ModAdd(k, (UInt256 *)&I); // k = IL + k (mod n)
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

// Public parent key -> public child key
//
// CKDpub((Kpar, cpar), i) -> (Ki, ci) computes a child extended public key from the parent extended public key.
// It is only defined for non-hardened child keys.
//
// - Check whether i >= 2^31 (whether the child is a hardened key).
//     - If so (hardened child): return failure
//     - If not (normal child): let I = HMAC-SHA512(Key = cpar, Data = serP(Kpar) || ser32(i)).
// - Split I into two 32-byte sequences, IL and IR.
// - The returned child key Ki is point(parse256(IL)) + Kpar.
// - The returned chain code ci is IR.
// - In case parse256(IL) >= n or Ki is the point at infinity, the resulting key is invalid, and one should proceed with
//   the next value for i.
//
void CKDpub(DSECPoint *K, UInt256 *c, uint32_t i)
{
    if (i & BIP32_HARD) return; // can't derive private child key from public parent key
    
    uint8_t buf[sizeof(*K) + sizeof(i)];
    UInt512 I;
    
    *(DSECPoint *)buf = *K;
    *(uint32_t *)&buf[sizeof(*K)] = CFSwapInt32HostToBig(i);
    
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, P(K) || i)
    
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    DSSecp256k1PointAdd(K, (UInt256 *)&I); // K = P(IL) + K
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

void CKDpub256(DSECPoint *K, UInt256 *c, UInt256 i, BOOL hardened)
{
    if (hardened) return; // can't derive private child key from public parent key
    BOOL iIs31Bits = uint256_is_31_bits(i);
    uint32_t smallI;
    uint32_t length = sizeof(*K) + (iIs31Bits?sizeof(smallI):(sizeof(i) + sizeof(hardened)));
    uint8_t buf[length];
    UInt512 I;
    
    *(DSECPoint *)buf = *K;
    
    if (iIs31Bits) {
        smallI = i.u32[0];
        smallI = CFSwapInt32HostToBig(smallI);
        
        *(uint32_t *)&buf[sizeof(*K)] = smallI;
    } else {
        *(BOOL *)&buf[sizeof(*K)] = hardened;
        *(UInt256 *)&buf[sizeof(*K) + sizeof(hardened)] = i;
    }
    
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, P(K) || i)
    
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    DSSecp256k1PointAdd(K, (UInt256 *)&I); // K = P(IL) + K
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

// adds 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int DSSecp256k1ModAdd(UInt256 *a, const UInt256 *b)
{
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    return secp256k1_ec_privkey_tweak_add(_ctx, (unsigned char *)a, (const unsigned char *)b);
}

// multiplies 256bit big endian ints a and b (mod secp256k1 order) and stores the result in a
// returns true on success
int DSSecp256k1ModMul(UInt256 *a, const UInt256 *b)
{
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    return secp256k1_ec_privkey_tweak_mul(_ctx, (unsigned char *)a, (const unsigned char *)b);
}

// multiplies secp256k1 generator by 256bit big endian int i and stores the result in p
// returns true on success
int DSSecp256k1PointGen(DSECPoint *p, const UInt256 *i)
{
    secp256k1_pubkey pubkey;
    size_t pLen = sizeof(*p);
    
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    return (secp256k1_ec_pubkey_create(_ctx, &pubkey, (const unsigned char *)i) &&
            secp256k1_ec_pubkey_serialize(_ctx, (unsigned char *)p, &pLen, &pubkey, SECP256K1_EC_COMPRESSED));
}

// multiplies secp256k1 generator by 256bit big endian int i and adds the result to ec-point p
// returns true on success
int DSSecp256k1PointAdd(DSECPoint *p, const UInt256 *i)
{
    secp256k1_pubkey pubkey;
    size_t pLen = sizeof(*p);
    
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    return (secp256k1_ec_pubkey_parse(_ctx, &pubkey, (const unsigned char *)p, sizeof(*p)) &&
            secp256k1_ec_pubkey_tweak_add(_ctx, &pubkey, (const unsigned char *)i) &&
            secp256k1_ec_pubkey_serialize(_ctx, (unsigned char *)p, &pLen, &pubkey, SECP256K1_EC_COMPRESSED));
}

// multiplies secp256k1 ec-point p by 256bit big endian int i and stores the result in p
// returns true on success
int DSSecp256k1PointMul(DSECPoint *p, const UInt256 *i)
{
    secp256k1_pubkey pubkey;
    size_t pLen = sizeof(*p);
    
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    return (secp256k1_ec_pubkey_parse(_ctx, &pubkey, (const unsigned char *)p, sizeof(*p)) &&
            secp256k1_ec_pubkey_tweak_mul(_ctx, &pubkey, (const unsigned char *)i) &&
            secp256k1_ec_pubkey_serialize(_ctx, (unsigned char *)p, &pLen, &pubkey, SECP256K1_EC_COMPRESSED));
}

@interface DSECDSAKey ()

@property (nonatomic, assign) UInt256 seckey;
@property (nonatomic, strong) NSData *pubkey;
@property (nonatomic, assign) BOOL compressed;
@property (nonatomic, assign) UInt256 chaincode;
@property (nonatomic, assign) uint32_t fingerprint;
@property (nonatomic, assign) BOOL isExtended;

@end

@implementation DSECDSAKey

+ (nullable instancetype)keyWithSeedData:(NSData *)data {
    return [[self alloc] initWithSeedData:data];
}

+ (instancetype)keyWithPrivateKey:(NSString *)privateKey onChain:(DSChain*)chain
{
    return [[self alloc] initWithPrivateKey:privateKey onChain:chain];
}

+ (instancetype)keyWithSecret:(UInt256)secret compressed:(BOOL)compressed
{
    return [[self alloc] initWithSecret:secret compressed:compressed];
}

+ (instancetype)keyWithExtendedPrivateKeyData:(NSData*)extendedPrivateKeyData
{
    return [[self alloc] initWithExtendedPrivateKeyData:extendedPrivateKeyData];
}

+ (instancetype)keyWithExtendedPublicKeyData:(NSData*)extendedPublicKeyData
{
    return [[self alloc] initWithExtendedPublicKeyData:extendedPublicKeyData];
}

+ (instancetype)keyWithPublicKeyData:(NSData *)publicKey
{
    return [[self alloc] initWithPublicKey:publicKey];
}

+ (instancetype)keyRecoveredFromCompactSig:(NSData *)compactSig andMessageDigest:(UInt256)md
{
    return [[self alloc] initWithCompactSig:compactSig andMessageDigest:md];
}

+(instancetype)keyWithDHKeyExchangeWithPublicKey:(DSECDSAKey *)publicKey forPrivateKey:(DSECDSAKey*)privateKey {
    return [[self alloc] initWithDHKeyExchangeWithPublicKey:publicKey forPrivateKey:privateKey];
}

- (instancetype)init
{
    dispatch_once(&_ctx_once, ^{ _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY); });
    if (! (self = [super init])) return nil;
    
    _fingerprint = 0;
    _chaincode = UINT256_ZERO;
    _isExtended = FALSE;
    
    return self;
}

- (instancetype)initWithSeedData:(NSData*)seedData
{
    if (! (self = [self init])) return nil;
    
    UInt512 I;
       
   HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seedData.bytes, seedData.length);
   
   UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];

    _seckey = secret;
    _compressed = YES;
    _chaincode = chain;
    
    return (secp256k1_ec_seckey_verify(_ctx, _seckey.u8)) ? self : nil;
}

- (instancetype)initWithSecret:(UInt256)secret compressed:(BOOL)compressed
{
    if (! (self = [self init])) return nil;

    _seckey = secret;
    _compressed = compressed;
    return (secp256k1_ec_seckey_verify(_ctx, _seckey.u8)) ? self : nil;
}

- (instancetype)initWithExtendedPrivateKeyData:(NSData*)extendedPrivateKeyData
{
    NSAssert(extendedPrivateKeyData.length == ECDSA_EXTENDED_SECRET_KEY_SIZE,@"Key size is incorrect");
    if (extendedPrivateKeyData.length < ECDSA_EXTENDED_SECRET_KEY_SIZE) return nil;
    
    if (!(self = [self initWithSecret:[extendedPrivateKeyData subdataWithRange:NSMakeRange(36, 32)].UInt256 compressed:YES])) return nil;
    
    self.fingerprint = [extendedPrivateKeyData UInt32AtOffset:0];
    self.chaincode = [extendedPrivateKeyData UInt256AtOffset:4];
    self.isExtended = TRUE;
    
    return self;
}

- (instancetype)initWithExtendedPublicKeyData:(NSData*)extendedPublicKeyData
{
    if (!(self = [self initWithPublicKey:[extendedPublicKeyData subdataWithRange:NSMakeRange(36, extendedPublicKeyData.length - 36)]])) return nil;
    
    self.fingerprint = [extendedPublicKeyData UInt32AtOffset:0];
    self.chaincode = [extendedPublicKeyData UInt256AtOffset:4];
    self.isExtended = TRUE;
    
    return self;
}

- (instancetype)initWithPrivateKey:(NSString *)privateKey onChain:(DSChain*)chain
{
    NSParameterAssert(privateKey);
    NSParameterAssert(chain);
    
    if (privateKey.length == 0) return nil;
    if (! (self = [self init])) return nil;
    
    // mini private key format
    if ((privateKey.length == 30 || privateKey.length == 22) && [privateKey characterAtIndex:0] == 'L') {
        if (! [privateKey isValidDashPrivateKeyOnChain:chain]) return nil;
        
        _seckey = [CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), (CFStringRef)privateKey,
                                                                          kCFStringEncodingUTF8, 0)) SHA256];
        _compressed = NO;
        return self;
    }
    
    NSData *d = privateKey.base58checkToData;
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    if (! d || d.length == 28) d = privateKey.base58ToData;
    if (d.length < sizeof(UInt256) || d.length > sizeof(UInt256) + 2) d = privateKey.hexToData;
    
    if ((d.length == sizeof(UInt256) + 1 || d.length == sizeof(UInt256) + 2) && *(const uint8_t *)d.bytes == version) {
        _seckey = *(const UInt256 *)((const uint8_t *)d.bytes + 1);
        _compressed = (d.length == sizeof(UInt256) + 2) ? YES : NO;
    }
    else if (d.length == sizeof(UInt256)) _seckey = *(const UInt256 *)d.bytes;
    
    return (secp256k1_ec_seckey_verify(_ctx, _seckey.u8)) ? self : nil;
}

- (instancetype)initWithPublicKey:(NSData *)publicKey
{
    NSParameterAssert(publicKey);
    
    if (publicKey.length != 33 && publicKey.length != 65) return nil;
    if (! (self = [self init])) return nil;
    
    secp256k1_pubkey pk;
    
    self.pubkey = publicKey;
    self.compressed = (self.pubkey.length == 33) ? YES : NO;
    
    BOOL valid = (secp256k1_ec_pubkey_parse(_ctx, &pk, self.publicKeyData.bytes, self.publicKeyData.length));
    if (valid) {
        return self;
    } else {
        return nil;
    }
}

- (instancetype)initWithCompactSig:(NSData *)compactSig andMessageDigest:(UInt256)md
{
    NSParameterAssert(compactSig);
    
    if (compactSig.length != 65) return nil;
    if (! (self = [self init])) return nil;

    self.compressed = (((uint8_t *)compactSig.bytes)[0] - 27 >= 4) ? YES : NO;
    
    NSMutableData *pubkey = [NSMutableData dataWithLength:(self.compressed ? 33 : 65)];
    size_t len = pubkey.length;
    int recid = (((uint8_t *)compactSig.bytes)[0] - 27) % 4;
    secp256k1_ecdsa_recoverable_signature s;
    secp256k1_pubkey pk;

    if (secp256k1_ecdsa_recoverable_signature_parse_compact(_ctx, &s, (const uint8_t *)compactSig.bytes + 1, recid) &&
        secp256k1_ecdsa_recover(_ctx, &pk, &s, md.u8) &&
        secp256k1_ec_pubkey_serialize(_ctx, pubkey.mutableBytes, &len, &pk,
                                      (self.compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED))) {
        pubkey.length = len;
        _pubkey = pubkey;
        return self;
    }
    
    return nil;
}

- (nullable instancetype)initWithDHKeyExchangeWithPublicKey:(DSECDSAKey *)publicKey forPrivateKey:(DSECDSAKey*)privateKey {
    NSParameterAssert(publicKey);
    NSParameterAssert(privateKey);
    if (! (self = [self init])) return nil;
    
    secp256k1_pubkey pk;
    if (secp256k1_ec_pubkey_parse(_ctx, &pk, publicKey.publicKeyData.bytes, publicKey.publicKeyData.length) != 1) {
        return nil;
    }
    
    //uint8_t * seckey = NULL;
    
    if (secp256k1_ecdh(_ctx, _seckey.u8, &pk, (const uint8_t *)privateKey.secretKey)!= 1) {
        return nil;
    }
    self.compressed = NO;
    return self;
}

// MARK: - Authentication Key Generation

+ (NSString *)serializedAuthPrivateKeyFromSeed:(NSData *)seed forChain:(DSChain*)chain
{
    if (! seed) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chainHash = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    // path m/1H/0 (same as copay uses for bitauth)
    CKDpriv(&secret, &chainHash, 1 | BIP32_HARD);
    CKDpriv(&secret, &chainHash, 0);
    
    NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
    
    [privKey appendBytes:&version length:1];
    [privKey appendBytes:&secret length:sizeof(secret)];
    [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
    return [NSString base58checkWithData:privKey];
}

// key used for BitID: https://github.com/bitid/bitid/blob/master/BIP_draft.md
+ (NSString *)serializedBitIdPrivateKey:(uint32_t)n forURI:(NSString *)uri fromSeed:(NSData *)seed forChain:(DSChain*)chain
{
    NSUInteger len = [uri lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *data = [NSMutableData dataWithCapacity:sizeof(n) + len];
    
    [data appendUInt32:n];
    [data appendBytes:uri.UTF8String length:len];
    
    UInt256 hash = data.SHA256;
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chainHash = *(UInt256 *)&I.u8[sizeof(UInt256)];
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    CKDpriv(&secret, &chainHash, 13 | BIP32_HARD); // m/13H
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[0]) | BIP32_HARD); // m/13H/aH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[1]) | BIP32_HARD); // m/13H/aH/bH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[2]) | BIP32_HARD); // m/13H/aH/bH/cH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[3]) | BIP32_HARD); // m/13H/aH/bH/cH/dH
    
    NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
    
    [privKey appendBytes:&version length:1];
    [privKey appendBytes:&secret length:sizeof(secret)];
    [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
    return [NSString base58checkWithData:privKey];
}

+ (NSString *)serializedPrivateMasterFromSeedData:(NSData *)seedData forChain:(DSChain*)chain
{
    if (! seedData) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seedData.bytes, seedData.length);
    
    UInt256 secret = *(UInt256 *)&I, lChain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    return serialize(0, 0, 0, lChain, [NSData dataWithBytes:&secret length:sizeof(secret)],[chain isMainnet]);
}

- (nullable NSString *)serializedPrivateKeyForChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (uint256_is_zero(_seckey)) return nil;

    NSMutableData *d = [NSMutableData secureDataWithCapacity:sizeof(UInt256) + 2];
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }

    [d appendBytes:&version length:1];
    [d appendBytes:&_seckey length:sizeof(_seckey)];
    if (self.compressed) [d appendBytes:"\x01" length:1];
    return [NSString base58checkWithData:d];
}

- (NSData *)publicKeyData
{
    if (self.pubkey.length == 0 && ! uint256_is_zero(_seckey)) {
        NSMutableData *d = [NSMutableData secureDataWithLength:self.compressed ? 33 : 65];
        size_t len = d.length;
        secp256k1_pubkey pk;

        if (secp256k1_ec_pubkey_create(_ctx, &pk, _seckey.u8)) {
            secp256k1_ec_pubkey_serialize(_ctx, d.mutableBytes, &len, &pk,
                                          (self.compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED));
            if (len == d.length) self.pubkey = d;
        }
        NSAssert(self.pubkey, @"Public key data should exist");
    }
    NSAssert(self.pubkey, @"Public key data should exist");
    return self.pubkey;
}

- (NSData *)extendedPublicKeyData
{
    if (!self.isExtended) return nil;
    NSMutableData * data = [NSMutableData data];
    [data appendUInt32:self.fingerprint];
    [data appendUInt256:self.chaincode];
    [data appendData:[self publicKeyData]];
    NSAssert(data.length >= 4 + sizeof(UInt256) + sizeof(DSECPoint), @"extended public key is wrong size");
    return [data copy];
}

-(NSData*)privateKeyData {
    if (uint256_is_zero(*self.secretKey)) return nil;
    return [NSData dataWithUInt256:*self.secretKey];
}

- (NSData *)extendedPrivateKeyData
{
    if (!self.isExtended) return nil;
    NSData * privateKeyData = [self privateKeyData];
    if (!privateKeyData) return nil;
    NSMutableData * data = [NSMutableData secureData];
    [data appendUInt32:self.fingerprint];
    [data appendUInt256:self.chaincode];
    [data appendData:privateKeyData];
    return [data copy];
}

- (const UInt256 *)secretKey
{
    return &_seckey;
}

-(BOOL)hasPrivateKey {
    return uint256_is_zero(*self.secretKey);
}

-(NSString*)secretKeyString {
    if (uint256_is_zero(*self.secretKey)) return @"";
    return [NSData dataWithUInt256:*self.secretKey].hexString;
}

- (NSData *)sign:(UInt256)md
{
    if (uint256_is_zero(_seckey)) {
        DSDLog(@"%s: can't sign with a public key", __func__);
        return nil;
    }

    NSMutableData *sig = [NSMutableData dataWithLength:72];
    size_t len = sig.length;
    secp256k1_ecdsa_signature s;
    
    if (secp256k1_ecdsa_sign(_ctx, &s, md.u8, _seckey.u8, secp256k1_nonce_function_rfc6979, NULL) &&
        secp256k1_ecdsa_signature_serialize_der(_ctx, sig.mutableBytes, &len, &s)) {
        sig.length = len;
    }
    else sig = nil;
    
    return sig;
}

- (BOOL)verify:(UInt256)md signatureData:(NSData *)sig
{
    NSParameterAssert(sig);
    
    if (sig.length > 65) {
            //not compact
        secp256k1_pubkey pk;
        secp256k1_ecdsa_signature s;
        BOOL r = NO;
        
        if (secp256k1_ec_pubkey_parse(_ctx, &pk, self.publicKeyData.bytes, self.publicKeyData.length) &&
            secp256k1_ecdsa_signature_parse_der(_ctx, &s, sig.bytes, sig.length) &&
            secp256k1_ecdsa_verify(_ctx, &s, md.u8, &pk) == 1) { // success is 1, all other values are fail
            r = YES;
        }
        
        return r;
    } else {
        //compact
        DSECDSAKey * key = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md];
        return [key.publicKeyData isEqualToData:self.publicKeyData];
    }
}

// Pieter Wuille's compact signature encoding used for bitcoin message signing
// to verify a compact signature, recover a public key from the signature and verify that it matches the signer's pubkey
- (NSData *)compactSign:(UInt256)md
{
    if (uint256_is_zero(_seckey)) {
        DSDLog(@"%s: can't sign with a public key", __func__);
        return nil;
    }
    
    NSMutableData *sig = [NSMutableData dataWithLength:65];
    secp256k1_ecdsa_recoverable_signature s;
    int recid = 0;
    
    if (secp256k1_ecdsa_sign_recoverable(_ctx, &s, md.u8, _seckey.u8, secp256k1_nonce_function_rfc6979, NULL) &&
        secp256k1_ecdsa_recoverable_signature_serialize_compact(_ctx, (uint8_t *)sig.mutableBytes + 1, &recid, &s)) {
        ((uint8_t *)sig.mutableBytes)[0] = 27 + recid + (self.compressed ? 4 : 0);
    }
    else sig = nil;
    
    return sig;
}

-(DSKeyType)keyType {
    return DSKeyType_ECDSA;
}

- (void)forgetPrivateKey {
    [self publicKeyData];
    _seckey = UINT256_ZERO;
}

// MARK: - Derivation

-(DSECDSAKey*)privateDeriveToPath:(NSIndexPath*)indexPath {
    
    UInt256 chain = self.chaincode;
    UInt256 secret = self.seckey;
    for (NSInteger i = 0;i<[indexPath length] - 1;i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    uint32_t fingerprint = [DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32[0];
    
    CKDpriv(&secret, &chain, (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1]);
    
    DSECDSAKey * childKey = [DSECDSAKey keyWithSecret:secret compressed:YES];
    childKey.chaincode = chain;
    childKey.fingerprint = fingerprint;
    childKey.isExtended = TRUE;
    NSAssert(childKey, @"Child key should be created");
    return childKey;
}

-(DSECDSAKey*)publicDeriveToPath:(NSIndexPath*)indexPath {
    UInt256 chain = self.chaincode;
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)self.publicKeyData.bytes);
    for (NSInteger i = 0;i<[indexPath length] - 1;i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpub(&pubKey, &chain, derivation);
    }
    NSData * publicKeyData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    uint32_t fingerprint = publicKeyData.hash160.u32[0];
    
    CKDpub(&pubKey, &chain, (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1]);
    
    publicKeyData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    DSECDSAKey * childKey = [DSECDSAKey keyWithPublicKeyData:publicKeyData];
    childKey.chaincode = chain;
    childKey.fingerprint = fingerprint;
    childKey.isExtended = TRUE;
    
    NSAssert(childKey, @"Public key should be created");
    return childKey;
}

- (instancetype)privateDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath {
    UInt256 chain = self.chaincode;
    UInt256 secret = self.seckey;
    for (NSInteger i = 0;i<[derivationPath length] - 1;i++) {
        UInt256 derivation = [derivationPath indexAtPosition:i];
        BOOL isHardenedAtPosition = [derivationPath isHardenedAtPosition:i];
        CKDpriv256(&secret, &chain, derivation,isHardenedAtPosition);
    }
    uint32_t fingerprint = [DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32[0];
    CKDpriv256(&secret, &chain, [derivationPath indexAtPosition:[derivationPath length] - 1],[derivationPath isHardenedAtPosition:[derivationPath length] - 1]);
    DSECDSAKey * childKey = [DSECDSAKey keyWithSecret:secret compressed:YES];
    childKey.chaincode = chain;
    childKey.fingerprint = fingerprint;
    childKey.isExtended = TRUE;
    NSAssert(childKey, @"Child key should be created");
    return childKey;
}

- (instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath {
    return [self publicDeriveTo256BitDerivationPath:derivationPath derivationPathOffset:0];
}

- (instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath derivationPathOffset:(NSUInteger)derivationPathOffset {
    NSAssert(derivationPath.length > derivationPathOffset, @"derivationPathOffset must be smaller that the derivation path length");
    UInt256 chain = self.chaincode;
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)self.publicKeyData.bytes);
    for (NSInteger i = derivationPathOffset;i<[derivationPath length] - 1;i++) {
        UInt256 derivation = [derivationPath indexAtPosition:i];
        BOOL isHardenedAtPosition = [derivationPath isHardenedAtPosition:i];
        CKDpub256(&pubKey, &chain, derivation,isHardenedAtPosition);
    }
    NSData * publicKeyData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    uint32_t fingerprint = publicKeyData.hash160.u32[0];
    
    UInt256 derivation = [derivationPath indexAtPosition:[derivationPath length] - 1];
    BOOL isHardenedAtPosition = [derivationPath isHardenedAtPosition:[derivationPath length] - 1];
    
    CKDpub256(&pubKey, &chain, derivation,isHardenedAtPosition);
    
    publicKeyData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    DSECDSAKey * childKey = [DSECDSAKey keyWithPublicKeyData:publicKeyData];
    childKey.chaincode = chain;
    childKey.fingerprint = fingerprint;
    childKey.isExtended = TRUE;
    
    NSAssert(childKey, @"Public key should be created");
    return childKey;
}


@end
