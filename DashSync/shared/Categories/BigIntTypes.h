//
//  BigIntTypes.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/16.
//  Copyright © 2019 Dash Core. All rights reserved.
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

#ifndef BigIntTypes_h
#define BigIntTypes_h

#if __has_feature(objc_arc)
#define NoTimeLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ##__VA_ARGS__]);
#else
#define NoTimeLog(format, ...) CFShow([NSString stringWithFormat:format, ##__VA_ARGS__]);
#endif


typedef union _UInt768 {
    uint8_t u8[768 / 8];
    uint16_t u16[768 / 16];
    uint32_t u32[768 / 32];
    uint64_t u64[768 / 64];
} UInt768;

typedef union _UInt512 {
    uint8_t u8[512 / 8];
    uint16_t u16[512 / 16];
    uint32_t u32[512 / 32];
    uint64_t u64[512 / 64];
} UInt512;

typedef union _UInt384 {
    uint8_t u8[384 / 8];
    uint16_t u16[384 / 16];
    uint32_t u32[384 / 32];
    uint64_t u64[384 / 64];
} UInt384;

typedef union _UInt256 {
    uint8_t u8[256 / 8];
    uint16_t u16[256 / 16];
    uint32_t u32[256 / 32];
    uint64_t u64[256 / 64];
} UInt256;

typedef union _UInt160 {
    uint8_t u8[160 / 8];
    uint16_t u16[160 / 16];
    uint32_t u32[160 / 32];
} UInt160;

typedef union _UInt128 {
    uint8_t u8[128 / 8];
    uint16_t u16[128 / 16];
    uint32_t u32[128 / 32];
    uint64_t u64[128 / 64];
} UInt128;

typedef struct _DSUTXO {
    UInt256 hash;
    unsigned long n; // use unsigned long instead of uint32_t to avoid trailing struct padding (for NSValue comparisons)
} DSUTXO;

typedef struct _DSLLMQ {
    uint8_t type;
    UInt256 hash;
} DSLLMQ;

typedef struct {
    uint8_t p[33];
} DSECPoint;

typedef uint32_t (^_Nullable BlockHeightFinder)(UInt256 blockHash);

#define uint768_random ((UInt768){.u32 = {arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random()}})

#define uint256_random ((UInt256){.u32 = {arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random(), arc4random()}})

#define uint256_random_data uint256_data(uint256_random)

#define uint160_random ((UInt160){.u32 = {arc4random(), arc4random(), arc4random(), arc4random(), arc4random()}})

#define uint512_concat(a, b) ((UInt512){.u64 = {a.u64[0], a.u64[1], a.u64[2], a.u64[3], b.u64[0], b.u64[1], b.u64[2], b.u64[3]}});

#define uint768_eq(a, b) \
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] && \
        (a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5] && (a).u64[6] == (b).u64[6] && (a).u64[7] == (b).u64[7] && \
        (a).u64[8] == (b).u64[8] && (a).u64[9] == (b).u64[9] && (a).u64[10] == (b).u64[10] && (a).u64[11] == (b).u64[11])
#define uint512_eq(a, b) \
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] && \
        (a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5] && (a).u64[6] == (b).u64[6] && (a).u64[7] == (b).u64[7])
#define uint384_eq(a, b) \
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] && \
        (a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5])
#define uint256_eq(a, b) \
    ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3])
#define uint160_eq(a, b) \
    ((a).u32[0] == (b).u32[0] && (a).u32[1] == (b).u32[1] && (a).u32[2] == (b).u32[2] && (a).u32[3] == (b).u32[3] && \
        (a).u32[4] == (b).u32[4])
#define uint128_eq(a, b) ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1])

#define uint256_supeq(a, b) ((a.u64[3] > b.u64[3]) || ((a.u64[3] == b.u64[3]) && ((a.u64[2] > b.u64[2]) || ((a.u64[2] == b.u64[2]) && ((a.u64[1] > b.u64[1]) || ((a.u64[1] == b.u64[1]) && (a.u64[0] >= b.u64[0])))))))

#define uint256_sup(a, b) ((a.u64[3] > b.u64[3]) || ((a.u64[3] == b.u64[3]) && ((a.u64[2] > b.u64[2]) || ((a.u64[2] == b.u64[2]) && ((a.u64[1] > b.u64[1]) || ((a.u64[1] == b.u64[1]) && (a.u64[0] > b.u64[0])))))))

#define uint256_compare(a, b) (uint256_eq(a, b) ? NSOrderedSame : (uint256_sup(a, b) ? NSOrderedDescending : NSOrderedAscending))

#define uint256_xor(a, b) ((UInt256){.u64 = {a.u64[0] ^ b.u64[0], a.u64[1] ^ b.u64[1], a.u64[2] ^ b.u64[2], a.u64[3] ^ b.u64[3]}}) //this needs to be tested

#define uint256_inverse(a) uint256_xor(a, UINT256_MAX)

//#define uint1_firstbits(x) (x & 0x1? 1 : 0)
//#define uint2_firstbits(x) (x & 0x2? uint1_firstbits( x >> 1 ) : 1+uint1_firstbits( x ))
//#define uint4_firstbits(x) (x & 0xA? uint2_firstbits( x >> 2 ) : 2+uint2_firstbits( x ))
//#define uint8_firstbits(x) (x & 0xF0? uint4_firstbits( x >> 4 ) : 4+uint4_firstbits( x ))
//#define uint16_firstbits(x) (x & 0xFF00? uint8_firstbits( x >> 8 ) : 8+uint8_firstbits( x ))
//#define uint32_firstbits(x) (x & 0xFFFF0000? uint16_firstbits( x >> 16 ) : 16+uint16_firstbits( x ))
//#define uint64_firstbits(x) (x & 0xFFFFFFFF00000000? uint32_firstbits( x >> 32 ) : 32+uint32_firstbits( x ))
//#define uint128_firstbits(x) (x.u64[0] & 0xFFFFFFFFFFFFFFFF? uint64_firstbits( x ) : 64+uint64_firstbits( x.u64[1] ))
//#define uint256_firstbits(x) ((x.u64[0] & 0xFFFFFFFFFFFFFFFF)? uint64_firstbits( x.u64[0] ) : ((x.u64[1] & 0xFFFFFFFFFFFFFFFF)? (64+uint64_firstbits( x.u64[1] )):((x.u64[2] & 0xFFFFFFFFFFFFFFFF)? (128+uint64_firstbits( x.u64[2] )):(192+uint64_firstbits( x.u64[3] )))))

#define uint768_is_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7] | (u).u64[8] | (u).u64[9] | (u).u64[10] | (u).u64[11]) == 0)
#define uint512_is_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7]) == 0)
#define uint384_is_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5]) == 0)
#define uint256_is_zero(u) (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3]) == 0)
#define uint160_is_zero(u) (((u).u32[0] | (u).u32[1] | (u).u32[2] | (u).u32[3] | (u).u32[4]) == 0)
#define uint128_is_zero(u) (((u).u64[0] | (u).u64[1]) == 0)

#define uint768_is_not_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7] | (u).u64[8] | (u).u64[9] | (u).u64[10] | (u).u64[11]) != 0)
#define uint512_is_not_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7]) != 0)
#define uint384_is_not_zero(u) \
    (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5]) != 0)
#define uint256_is_not_zero(u) (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3]) != 0)
#define uint160_is_not_zero(u) (((u).u32[0] | (u).u32[1] | (u).u32[2] | (u).u32[3] | (u).u32[4]) != 0)
#define uint128_is_not_zero(u) (((u).u64[0] | (u).u64[1]) != 0)

#define uint256_is_31_bits(u) ((((u).u64[1] | (u).u64[2] | (u).u64[3]) == 0) && ((u).u32[1] == 0) && (((u).u32[0] & 0x80000000) == 0))

#define uint768_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt768)])
#define uint512_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt512)])
#define uint256_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt256)])
#define uint160_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt160)])
#define uint128_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt128)])

#define uint128_data(u) [NSData dataWithUInt128:u]
#define uint160_data(u) [NSData dataWithUInt160:u]
#define uint256_data(u) [NSData dataWithUInt256:u]
#define uint256_reverse_data(u) [NSData dataWithUInt256:u].reverse
#define uint384_data(u) [NSData dataWithUInt384:u]
#define uint512_data(u) [NSData dataWithUInt512:u]
#define uint768_data(u) [NSData dataWithUInt768:u]

#define uint160_data_from_obj(u) [NSData dataWithUInt160Value:u]
#define uint256_data_from_obj(u) [NSData dataWithUInt256Value:u]

#define uint160_hex(u) [NSData dataWithUInt160:u].hexString
#define uint160_reverse_hex(u) [NSData dataWithUInt160:u].reverse.hexString
#define uint160_base58(u) [NSData dataWithUInt160:u].base58String
#define uint256_hex(u) [NSData dataWithUInt256:u].hexString
#define uint256_bin(u) [NSData dataWithUInt256:u].binaryString
#define uint256_positionOfFirstSetBit(u) [NSData dataWithUInt256:u].positionOfFirstSetBit
#define uint256_base64(u) [NSData dataWithUInt256:u].base64String
#define uint256_base58(u) [NSData dataWithUInt256:u].base58String
#define uint256_reverse_hex(u) [NSData dataWithUInt256:u].reverse.hexString
#define uint256_reverse_base58(u) [NSData dataWithUInt256:u].reverse.base58String
#define uint384_hex(u) [NSData dataWithUInt384:u].hexString
#define uint384_reverse_hex(u) [NSData dataWithUInt384:u].reverse.hexString
#define uint512_hex(u) [NSData dataWithUInt512:u].hexString
#define uint512_reverse_hex(u) [NSData dataWithUInt512:u].reverse.hexString
#define uint768_hex(u) [NSData dataWithUInt768:u].hexString
#define uint768_reverse_hex(u) [NSData dataWithUInt768:u].reverse.hexString

#define uint256_reverse(u) [NSData dataWithUInt256:u].reverse.UInt256

#define uint256_from_int(u) ((UInt256){.u32 = {u, 0, 0, 0, 0, 0, 0, 0}})
#define uint256_from_long(u) ((UInt256){.u64 = {u, 0, 0, 0}})

#define UINT768_ZERO ((UInt768){.u64 = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}})
#define UINT768_ONE ((UInt768){.u64 = {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}})
#define UINT512_ZERO ((UInt512){.u64 = {0, 0, 0, 0, 0, 0, 0, 0}})
#define UINT384_ZERO ((UInt384){.u64 = {0, 0, 0, 0, 0, 0}})
#define UINT256_ZERO ((UInt256){.u64 = {0, 0, 0, 0}})
#define UINT256_ONE ((UInt256){.u64 = {1, 0, 0, 0}})
#define UINT256_TWO ((UInt256){.u64 = {2, 0, 0, 0}})
#define UINT256_MAX ((UInt256){.u64 = {0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF}})
#define UINT160_ZERO ((UInt160){.u32 = {0, 0, 0, 0, 0}})
#define UINT128_ZERO ((UInt128){.u64 = {0, 0}})
#define DSUTXO_ZERO ((DSUTXO){.hash = UINT256_ZERO, .n = 0})
#define DSLLMQ_ZERO ((DSLLMQ){.type = 0, .hash = UINT256_ZERO})
#define DSECPOINT_ZERO ((DSECPoint){.p = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}})

#define dsutxo_eq(a, b) (uint256_eq(a.hash, b.hash) && (a.n == b.n))
#define dsutxo_is_zero(a) (uint256_is_zero(a.hash) && (a.n == 0))
#define dsutxo_hash_is_not_zero(a) (uint256_is_not_zero(a.hash))

#define dsutxo_obj(o) [NSValue value:&(o) withObjCType:@encode(DSUTXO)]
#define dsutxo_data(o) [NSData dataWithBytes:&((struct { uint32_t u[256 / 32 + 1]; }){ \
                                                 o.hash.u32[0], o.hash.u32[1], o.hash.u32[2], o.hash.u32[3], \
                                                 o.hash.u32[4], o.hash.u32[5], o.hash.u32[6], o.hash.u32[7], \
                                                 CFSwapInt32HostToLittle((uint32_t)o.n)}) \
                                      length:sizeof(UInt256) + sizeof(uint32_t)]

#define data_malloc(u) (^{ \
    NSUInteger l = u.length; \
    uint8_t *h = malloc(l); \
    memcpy(h, u.bytes, l); \
    return h; \
}())
#define uint128_malloc(u) (^{ \
    uint8_t (*h)[16] = malloc(sizeof(UInt128)); \
    memcpy(h, u.u8, sizeof(UInt128)); \
    return h; \
}())
#define uint160_malloc(u) (^{ \
    uint8_t (*h)[20] = malloc(sizeof(UInt160)); \
    memcpy(h, u.u8, sizeof(UInt160)); \
    return h; \
}())
#define uint256_malloc(u) (^{ \
    uint8_t (*h)[32] = malloc(sizeof(UInt256)); \
    memcpy(h, u.u8, sizeof(UInt256)); \
    return h; \
}())
#define uint384_malloc(u) (^{ \
    uint8_t (*h)[48] = malloc(sizeof(UInt384)); \
    memcpy(h, u.u8, sizeof(UInt384)); \
    return h; \
}())
#define uint512_malloc(u) (^{ \
    uint8_t (*h)[64] = malloc(sizeof(UInt512)); \
    memcpy(h, u.u8, sizeof(UInt512)); \
    return h; \
}())
#define uint768_malloc(u) (^{ \
    uint8_t (*h)[96] = malloc(sizeof(UInt768)); \
    memcpy(h, u.u8, sizeof(UInt768)); \
    return h; \
}())
#endif /* BigIntTypes_h */
