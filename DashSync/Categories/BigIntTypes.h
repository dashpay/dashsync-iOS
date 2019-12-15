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

#ifndef BigIntTypes_h
#define BigIntTypes_h


typedef union _UInt768 {
    uint8_t u8[768/8];
    uint16_t u16[768/16];
    uint32_t u32[768/32];
    uint64_t u64[768/64];
} UInt768;

typedef union _UInt512 {
    uint8_t u8[512/8];
    uint16_t u16[512/16];
    uint32_t u32[512/32];
    uint64_t u64[512/64];
} UInt512;

typedef union _UInt384 {
    uint8_t u8[384/8];
    uint16_t u16[384/16];
    uint32_t u32[384/32];
    uint64_t u64[384/64];
} UInt384;

typedef union _UInt256 {
    uint8_t u8[256/8];
    uint16_t u16[256/16];
    uint32_t u32[256/32];
    uint64_t u64[256/64];
} UInt256;

typedef union _UInt160 {
    uint8_t u8[160/8];
    uint16_t u16[160/16];
    uint32_t u32[160/32];
} UInt160;

typedef union _UInt128 {
    uint8_t u8[128/8];
    uint16_t u16[128/16];
    uint32_t u32[128/32];
    uint64_t u64[128/64];
} UInt128;

typedef struct _DSUTXO {
    UInt256 hash;
    unsigned long n; // use unsigned long instead of uint32_t to avoid trailing struct padding (for NSValue comparisons)
} DSUTXO;

typedef struct _DSLLMQ {
    uint8_t type;
    UInt256 hash;
} DSLLMQ;

#define uint768_eq(a, b)\
((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] &&\
(a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5] && (a).u64[6] == (b).u64[6] && (a).u64[7] == (b).u64[7] &&\
(a).u64[8] == (b).u64[8] && (a).u64[9] == (b).u64[9] && (a).u64[10] == (b).u64[10] && (a).u64[11] == (b).u64[11])
#define uint512_eq(a, b)\
((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] &&\
(a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5] && (a).u64[6] == (b).u64[6] && (a).u64[7] == (b).u64[7])
#define uint384_eq(a, b)\
((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3] &&\
(a).u64[4] == (b).u64[4] && (a).u64[5] == (b).u64[5])
#define uint256_eq(a, b)\
((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1] && (a).u64[2] == (b).u64[2] && (a).u64[3] == (b).u64[3])
#define uint160_eq(a, b)\
((a).u32[0] == (b).u32[0] && (a).u32[1] == (b).u32[1] && (a).u32[2] == (b).u32[2] && (a).u32[3] == (b).u32[3] &&\
(a).u32[4] == (b).u32[4])
#define uint128_eq(a, b) ((a).u64[0] == (b).u64[0] && (a).u64[1] == (b).u64[1])

#define uint256_supeq(a, b) (a.u64[3] > b.u64[3]) || ((a.u64[3] == b.u64[3]) && ((a.u64[2] > b.u64[2]) || ((a.u64[2] == b.u64[2]) && ((a.u64[1] > b.u64[1]) || ((a.u64[1] == b.u64[1]) && (a.u64[0] >= b.u64[0]))))))

#define uint256_sup(a, b) (a.u64[3] > b.u64[3]) || ((a.u64[3] == b.u64[3]) && ((a.u64[2] > b.u64[2]) || ((a.u64[2] == b.u64[2]) && ((a.u64[1] > b.u64[1]) || ((a.u64[1] == b.u64[1]) && (a.u64[0] > b.u64[0]))))))

#define uint256_xor(a, b) ((UInt256) { .u64 = { a.u64[0] ^ b.u64[0], a.u64[1] ^ b.u64[1], a.u64[2] ^ b.u64[2], a.u64[3] ^ b.u64[3] } })//this needs to be tested

#define uint768_is_zero(u)\
(((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7] | (u).u64[8] | (u).u64[9] | (u).u64[10] | (u).u64[11]) == 0)
#define uint512_is_zero(u)\
(((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5] | (u).u64[6] | (u).u64[7]) == 0)
#define uint384_is_zero(u)\
(((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3] | (u).u64[4] | (u).u64[5]) == 0)

#define uint256_is_31_bits(u) ((((u).u64[1] | (u).u64[2] | (u).u64[3]) == 0) && ((u).u32[1] == 0) && (((u).u32[0] & 0x80000000) == 0))
#define uint256_is_zero(u) (((u).u64[0] | (u).u64[1] | (u).u64[2] | (u).u64[3]) == 0)
#define uint160_is_zero(u) (((u).u32[0] | (u).u32[1] | (u).u32[2] | (u).u32[3] | (u).u32[4]) == 0)
#define uint128_is_zero(u) (((u).u64[0] | (u).u64[1]) == 0)

#define uint768_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt768)])
#define uint512_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt512)])
#define uint256_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt256)])
#define uint160_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt160)])
#define uint128_obj(u) ([NSValue value:(u).u8 withObjCType:@encode(UInt128)])

#define uint128_data(u) [NSData dataWithUInt128:u]
#define uint160_data(u) [NSData dataWithUInt160:u]
#define uint256_data(u) [NSData dataWithUInt256:u]
#define uint384_data(u) [NSData dataWithUInt384:u]

#define uint160_data_from_obj(u) [NSData dataWithUInt160Value:u]
#define uint256_data_from_obj(u) [NSData dataWithUInt256Value:u]

#define uint160_hex(u) [NSData dataWithUInt160:u].hexString
#define uint160_reverse_hex(u) [NSData dataWithUInt160:u].reverse.hexString
#define uint256_hex(u) [NSData dataWithUInt256:u].hexString
#define uint256_reverse_hex(u) [NSData dataWithUInt256:u].reverse.hexString
#define uint384_hex(u) [NSData dataWithUInt384:u].hexString
#define uint384_reverse_hex(u) [NSData dataWithUInt384:u].reverse.hexString
#define uint512_hex(u) [NSData dataWithUInt512:u].hexString
#define uint512_reverse_hex(u) [NSData dataWithUInt512:u].reverse.hexString
#define uint768_hex(u) [NSData dataWithUInt768:u].hexString
#define uint768_reverse_hex(u) [NSData dataWithUInt768:u].reverse.hexString

#define uint256_reverse(u)  [NSData dataWithUInt256:u].reverse.UInt256

#define uint256_from_int(u) ((UInt256) { .u32 = { u, 0, 0, 0, 0, 0 ,0 ,0 } })
#define uint256_from_long(u) ((UInt256) { .u64 = { u, 0, 0, 0 } })

#define UINT768_ZERO ((UInt768) { .u64 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } })
#define UINT512_ZERO ((UInt512) { .u64 = { 0, 0, 0, 0, 0, 0, 0, 0 } })
#define UINT384_ZERO ((UInt384) { .u64 = { 0, 0, 0, 0, 0, 0 } })
#define UINT256_ZERO ((UInt256) { .u64 = { 0, 0, 0, 0 } })
#define UINT256_MAX ((UInt256) { .u64 = { 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF } })
#define UINT160_ZERO ((UInt160) { .u32 = { 0, 0, 0, 0, 0 } })
#define UINT128_ZERO ((UInt128) { .u64 = { 0, 0 } })
#define DSUTXO_ZERO ((DSUTXO) { .hash = UINT256_ZERO , .n = 0 })
#define DSLLMQ_ZERO ((DSLLMQ) { .type = 0, .hash = UINT256_ZERO })

#define dsutxo_eq(a,b) (uint256_eq(a.hash,b.hash) && (a.n == b.n))
#define dsutxo_is_zero(a) (uint256_is_zero(a.hash) && (a.n == 0))

#define dsutxo_obj(o) [NSValue value:&(o) withObjCType:@encode(DSUTXO)]
#define dsutxo_data(o) [NSData dataWithBytes:&((struct { uint32_t u[256/32 + 1]; }) {\
o.hash.u32[0], o.hash.u32[1], o.hash.u32[2], o.hash.u32[3],\
o.hash.u32[4], o.hash.u32[5], o.hash.u32[6], o.hash.u32[7],\
CFSwapInt32HostToLittle((uint32_t)o.n) }) length:sizeof(UInt256) + sizeof(uint32_t)]


#endif /* BigIntTypes_h */
