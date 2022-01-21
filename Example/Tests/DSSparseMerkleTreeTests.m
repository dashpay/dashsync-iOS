//
//  DSSparseMerkleTreeTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 11/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSDAPIGRPCResponseHandler.h"
#import "DSMerkleTree.h"
#import "DSPlatformRootMerkleTree.h"
#import "DSQuorumEntry.h"
#import "DSSparseMerkleTree.h"
#import "NSData+DSCborDecoding.h"
#import "NSData+DSHash.h"
#import "NSData+DSMerkAVLTree.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"
#import <DAPI-GRPC/Core.pbobjc.h>
#import <DAPI-GRPC/Core.pbrpc.h>
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>

@interface DSSparseMerkleTreeTests : XCTestCase

@end

@implementation DSSparseMerkleTreeTests

- (void)testInclusion {
    /*  1. inclusion proof for key: 505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67:

    hashes: [adb4e8a521216f1eb1c6f6663c4c04dcee910109c7c4657bb542d80fe1fde0a3, 00, ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9, 00, 5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f
    error: <nil> */

    {
        NSData *valueData = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData;
        UInt256 key = @"505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"adb4e8a521216f1eb1c6f6663c4c04dcee910109c7c4657bb542d80fe1fde0a3".hexToData, [defaultNodeData copy], @"ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }

    /* 2. inclusion proof for key 5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d:

    hashes: [3648f97f06e804f77cd36e4de4eee313b149f9357acf9377efa4cc4f6e128e13, 00, ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9, 00, 5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0
    error: <nil> */

    {
        NSData *valueData = @"3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0".hexToData;
        UInt256 key = @"5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"3648f97f06e804f77cd36e4de4eee313b149f9357acf9377efa4cc4f6e128e13".hexToData, [defaultNodeData copy], @"ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }

    /* 3. inclusion proof for key 5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d:

    hashes: [e9455cb528388fc14678a440582dfee3fd267f28c50163928e5d4285e3e25c04, 00, 5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 69ee174fca84f3a77aae498ef75db4ae80811d57969301e08f4ad736bb9fa231
    error: <nil> */

    {
        NSData *valueData = @"69ee174fca84f3a77aae498ef75db4ae80811d57969301e08f4ad736bb9fa231".hexToData;
        UInt256 key = @"5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"e9455cb528388fc14678a440582dfee3fd267f28c50163928e5d4285e3e25c04".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }

    /* 4. inclusion proof for key 63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce:

    hashes: [35c119a1313c9f503b1700ef7a9d85e1bf833d967d8a479c51d42dec38d04ae4, 66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 7b029896bb622ca5e21916c9b3c5a2e8b60e44b9da5442af1c8fc178922d70fe
    error: <nil> */

    {
        NSData *valueData = @"7b029896bb622ca5e21916c9b3c5a2e8b60e44b9da5442af1c8fc178922d70fe".hexToData;
        UInt256 key = @"63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"35c119a1313c9f503b1700ef7a9d85e1bf833d967d8a479c51d42dec38d04ae4".hexToData,
            @"66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }

    /* 5. inclusion proof for key 6b2635e55813363bb79c180332489ab19a8b1e8d71bc4ded9e9564b101485538:

    hashes: [1bcbff246376885b33b3bf49d73f96ae270d038583c74408e75fd11a559c788e, 66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: a77c88bfb32b7bfa3c0ae8bae5a483db161ed58df5baf4c13aadaa67ecc5b76a
    error: <nil> */

    {
        NSData *valueData = @"a77c88bfb32b7bfa3c0ae8bae5a483db161ed58df5baf4c13aadaa67ecc5b76a".hexToData;
        UInt256 key = @"6b2635e55813363bb79c180332489ab19a8b1e8d71bc4ded9e9564b101485538".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"1bcbff246376885b33b3bf49d73f96ae270d038583c74408e75fd11a559c788e".hexToData,
            @"66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }

    /* 6. inclusion proof for key 7de7689b7743b75b7f3682d77ae8cc88fb599f82cf376a0afbb9bec757b53dea:

    hashes: [be35b14d1fde819744c1408dd382320eeecba25ec77a3d2492ddb2cbd751f8dc, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    proof value: e14839a44f4fa7d399ed3f1cbc7d02fb81dcfb60be698902ac3c792a4f46064e
    error: <nil> */

    {
        NSData *valueData = @"e14839a44f4fa7d399ed3f1cbc7d02fb81dcfb60be698902ac3c792a4f46064e".hexToData;
        UInt256 key = @"7de7689b7743b75b7f3682d77ae8cc88fb599f82cf376a0afbb9bec757b53dea".hexToData.UInt256;
        UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

        uint8_t zero = 0;
        NSData *defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];

        NSArray *hashes = @[@"be35b14d1fde819744c1408dd382320eeecba25ec77a3d2492ddb2cbd751f8dc".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];

        [DSSparseMerkleTree verifyInclusionWithRoot:root
                                             forKey:key
                                      withValueData:valueData
                                 againstProofHashes:hashes
                                         completion:^(BOOL verified, NSError *_Nullable error) {
                                             XCTAssert(verified, @"This should be verified");
                                         }];
    }
}

- (void)testNonInclusion {
    /*
     non-inclusion proof for example for key c76a71d3e9833e4dcba11162f3f567c8c7cf8b206a55c65b8c0bc408084e9747:
      
     hashes: [cff42290786a4cda6ac477a433ac17e0a8bdfcb51de80a6034e054aaaf691634, b282d08971cd786752ce7a9047da6ed9016124f2a071e095c0e55cf5b02a3136, 3216e3f35f32a28cef785491ad3989f463431ed0f25d6910e0d3fd9ee9c531b4]
     included: false
     proof value: []
     error: <nil>
     */

    UInt256 key = @"c76a71d3e9833e4dcba11162f3f567c8c7cf8b206a55c65b8c0bc408084e9747".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;

    NSArray *hashes = @[@"cff42290786a4cda6ac477a433ac17e0a8bdfcb51de80a6034e054aaaf691634".hexToData, @"b282d08971cd786752ce7a9047da6ed9016124f2a071e095c0e55cf5b02a3136".hexToData, @"3216e3f35f32a28cef785491ad3989f463431ed0f25d6910e0d3fd9ee9c531b4".hexToData];

    [DSSparseMerkleTree verifyNonInclusionWithRoot:root
                                            forKey:key
                                  withProofKeyData:[NSData data]
                                withProofValueData:[NSData data]
                                againstProofHashes:hashes
                                        completion:^(BOOL verified, NSError *_Nullable error) {
                                            XCTAssert(verified, @"This should be verified");
                                        }];
}

- (void)testCompressedInclusion {
    //Tree root is eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659

    /*  1. compressed inclusion proof for key 1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f:

    bitmap: [e0]
    hashes: [bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa, 464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 3
    included: true
    proof value: 0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5
    error: <nil> */

    {
        NSData *valueData = @"0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5".hexToData;
        UInt256 key = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"e0".hexToData;

        NSArray *hashes = @[@"bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:3
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }

    /*  2. compressed inclusion proof for key 3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0:
    bitmap: [e0]
    hashes: [bf6fee408e5469396eab0ff814773129a83bf90d1b8e44883902c73f2bfaf034, 464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 3
    included: true
    proof value: 21c817b446dace1b294ce407e6190f04ad9c92fe48a9264b11f733bcd5c6fb12
    error: <nil> */

    {
        NSData *valueData = @"21c817b446dace1b294ce407e6190f04ad9c92fe48a9264b11f733bcd5c6fb12".hexToData;
        UInt256 key = @"3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"e0".hexToData;

        NSArray *hashes = @[@"bf6fee408e5469396eab0ff814773129a83bf90d1b8e44883902c73f2bfaf034".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:3
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }

    /*  3. compressed inclusion proof for key 505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67:
    bitmap: [ae]
    hashes: [4b5e4d3fad51630d2fae01e617074e1b1c97b68467493b5e5bbf3648b7c1a905, cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 7
    included: true
    proof value: 2b63dadf2107b10b52b6374c05fd7152062bd0c67bd3796e3aa70bb68c2d6005
    error: <nil> */

    {
        NSData *valueData = @"2b63dadf2107b10b52b6374c05fd7152062bd0c67bd3796e3aa70bb68c2d6005".hexToData;
        UInt256 key = @"505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"ae".hexToData;

        NSArray *hashes = @[@"4b5e4d3fad51630d2fae01e617074e1b1c97b68467493b5e5bbf3648b7c1a905".hexToData, @"cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
            @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
            @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:7
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }

    /*  4. compressed inclusion proof for key 5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d:
    bitmap: [ae]
    hashes: [744aca6fb75026664bd26c3759bec7606a7837db11be4329ee30c928334e0657, cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    lenght: 7
    included: true
    proof value: 3662035a8e2a7f40130baaa4178564f75a020f7f869b36e701efff4ae146aaf5
    error: <nil> */

    {
        NSData *valueData = @"3662035a8e2a7f40130baaa4178564f75a020f7f869b36e701efff4ae146aaf5".hexToData;
        UInt256 key = @"5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"ae".hexToData;

        NSArray *hashes = @[@"744aca6fb75026664bd26c3759bec7606a7837db11be4329ee30c928334e0657".hexToData, @"cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
            @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
            @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:7
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }

    /*  5. compressed inclusion proof for key 5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d:
    bitmap: [b8]
    hashes:  [088e8d435a628a6c6966e7fca6225779dde08a6405cede722e9cf76d70886a89, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    lenght: 5
    included: true
    proof value: 40d4fd1568130be6926f2a6023b4b83c4197a1fe309b2dc762d46fc015c5182a
    error: <nil> */

    {
        NSData *valueData = @"40d4fd1568130be6926f2a6023b4b83c4197a1fe309b2dc762d46fc015c5182a".hexToData;
        UInt256 key = @"5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"b8".hexToData;

        NSArray *hashes = @[@"088e8d435a628a6c6966e7fca6225779dde08a6405cede722e9cf76d70886a89".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
            @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
            @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:5
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }

    /*  6. compressed inclusion proof for key 63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce:
    bitmap: [f8]
    hashes: [88fbab40d43219bb5dfa20ea713724da7c8e4403249fef4996cf7ecbdd62d5c2, b79593e6d96ac011687a1c4db8efdd3a8c97e02f5614b5f0c13f40ee806f7940, b01249919fd8940f972aaade5bc4034fe1556ffe47243ab0fa40094a898f4070, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 5
    included: true
    proof value: 4352b80b63fbb5b86a21a3c8fc8a4d96e0b4c855d94c10af4d407f26b73ee170
    error: <nil> */

    {
        NSData *valueData = @"4352b80b63fbb5b86a21a3c8fc8a4d96e0b4c855d94c10af4d407f26b73ee170".hexToData;
        UInt256 key = @"63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce".hexToData.UInt256;
        UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData *bitmap = @"f8".hexToData;

        NSArray *hashes = @[@"88fbab40d43219bb5dfa20ea713724da7c8e4403249fef4996cf7ecbdd62d5c2".hexToData, @"b79593e6d96ac011687a1c4db8efdd3a8c97e02f5614b5f0c13f40ee806f7940".hexToData,
            @"b01249919fd8940f972aaade5bc4034fe1556ffe47243ab0fa40094a898f4070".hexToData,
            @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
            @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];

        [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root
                                                       forKey:key
                                                withValueData:valueData
                                           againstProofHashes:hashes
                                              compressionData:bitmap
                                                       length:5
                                                   completion:^(BOOL verified, NSError *_Nullable error) {
                                                       XCTAssert(verified, @"This should be verified");
                                                   }];
    }
}

- (void)testCompressedNonInclusion {
    /*
     non-inclusion proof with hex values for example for key 067cf8268954dcb5efc65561e5b8e8b1c9ca636f85697eddc89ceee6de899070
     for a tree with root
     eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659
     the proof key here is the key of the leaf node which is on the path to the requested non-included key
     
     bitmap: [e0]
     hashes: [bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa, 464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
     length: 3
     included: false
     proof key: 1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f
     proof value: 0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5
     error: <nil>
     */

    UInt256 key = @"067cf8268954dcb5efc65561e5b8e8b1c9ca636f85697eddc89ceee6de899070".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;

    NSData *proofKeyData = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData;
    NSData *proofValueData = @"0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5".hexToData;

    NSArray *hashes = @[@"bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
    NSData *bitmap = @"e0".hexToData;

    [DSSparseMerkleTree verifyCompressedNonInclusionWithRoot:root
                                                      forKey:key
                                            withProofKeyData:proofKeyData
                                          withProofValueData:proofValueData
                                          againstProofHashes:hashes
                                             compressionData:bitmap
                                                      length:3
                                                  completion:^(BOOL verified, NSError *_Nullable error) {
                                                      XCTAssert(verified, @"This should be verified");
                                                  }];
}

- (void)testMerkAVLTreeProof {
    NSData *proofData = @"014fc2c3d1930a2b5517c4d067ad709750df79a5d4b8999e01c0cc08876f2dbe4a02229ae7d97d361daa2e70c3d682f290bbceb5493d88a2a2f9ce560d20e1992fbd10013167d6ec26570bddc238e48494c404ebe2ae869d17652a9566bf6109e4de55d302e25e4ea30c17a86514960601b92227339ce88d057a12d76561b41d676457061210011a6849de9e9f8c663d06f7dc4c86bf66ccee22c4ad4ff8ea1f4125414956c3ad022cb8354f326e19583b2579ef99a598d63e5a2baa836eb2f2e13055c848208318100320e3105acf7fe6b61e6a3b9bf8054f59fb9264170945c4b40fb25d58b2ac2a1d47008da56269645820e3105acf7fe6b61e6a3b9bf8054f59fb9264170945c4b40fb25d58b2ac2a1d476762616c616e63651a3b9ac7e6687265766973696f6e006a7075626c69634b65797381a36269640064646174615821032fc3bdf73d86c40bd27fbd62a793356cd625508b2306231167ce4e61af66e55f6474797065006f70726f746f636f6c56657273696f6e0002a5fee690784b06f4765fec55ddbde482b40a7b4bb9ce8ed01440b59aa2f78f881001226345b996d3e565bd98de759767b7daddf2d452e428e542e1872622a1ef2b9511111111".hexToData;
    NSDictionary *elementDictionary = nil;
    NSError *error;
    NSData *rootHash = [proofData executeProofReturnElementDictionary:&elementDictionary query:nil decode:TRUE usesVersion:TRUE error:&error];
    XCTAssertNil(error);
    NSString *expectedRootHashString = @"6ef4c210cb5e919d9dcd894bc841506f93ef3f8638eab452502050b04ee079fb";
    NSDictionary *identityDictionary = elementDictionary.allValues[0];
    XCTAssertEqualObjects(rootHash.hexString, expectedRootHashString);
}

- (void)testMerkleTreeEvenElements {
    NSArray *elements = @[@"a", @"b", @"c", @"d", @"e", @"f"];
    NSMutableArray *leaves = [NSMutableArray array];
    for (NSString *element in elements) {
        NSData *elementData = [element dataUsingEncoding:NSUTF8StringEncoding];
        [leaves addObject:uint256_data(elementData.blake3)];
    }

    NSArray *expectedHashes = @[@"17762fddd969a453925d65717ac3eea21320b66b54342fde15128d6caf21215f".hexToData,
        @"10e5cf3d3c8a4f9f3468c8cc58eea84892a22fdadbc1acb22410190044c1d553".hexToData,
        @"ea7aa1fc9efdbe106dbb70369a75e9671fa29d52bd55536711bf197477b8f021".hexToData,
        @"d5ede538f628f687e5e0422c7755b503653de2dcd7053ca8791afa5d4787d843".hexToData,
        @"27bb492e108bf5e9c724176d7ae75d4cedc422fe4065020bd6140c3fcad3a9e7".hexToData,
        @"9ab388bedc43eaf44150107d17ad090f6b1c34610f5740778ddb95d9f06576ee".hexToData];
    XCTAssertEqualObjects([leaves copy], expectedHashes);

    NSMutableArray *secondRow = [NSMutableArray array];
    NSMutableData *secondRowFirstConcatData = [[leaves objectAtIndex:0] mutableCopy];
    [secondRowFirstConcatData appendData:[leaves objectAtIndex:1]];
    [secondRow addObject:uint256_data([secondRowFirstConcatData blake3])];

    NSMutableData *secondRowSecondConcatData = [[leaves objectAtIndex:2] mutableCopy];
    [secondRowSecondConcatData appendData:[leaves objectAtIndex:3]];
    [secondRow addObject:uint256_data([secondRowSecondConcatData blake3])];

    NSMutableData *secondRowThirdConcatData = [[leaves objectAtIndex:4] mutableCopy];
    [secondRowThirdConcatData appendData:[leaves objectAtIndex:5]];
    [secondRow addObject:uint256_data([secondRowThirdConcatData blake3])];

    NSArray *expected2ndRowHashes = @[@"8912f1e49d6c94830787bc8765e92f409d6db9041739884a42e59f16388756b1".hexToData,
        @"a77a720d29e9dfa24461260e8ceb053ebf346dca2d81aa2b4182cb491fd43219".hexToData,
        @"d6e299f15660574f2c30adf712fd38c03dbce8447bc79d9bb559e825ffd52a62".hexToData];

    XCTAssertEqualObjects([secondRow copy], expected2ndRowHashes);

    NSMutableArray *thirdRow = [NSMutableArray array];
    NSMutableData *thirdRowFirstConcatData = [[secondRow objectAtIndex:0] mutableCopy];
    [thirdRowFirstConcatData appendData:[secondRow objectAtIndex:1]];
    [thirdRow addObject:uint256_data([thirdRowFirstConcatData blake3])];

    [thirdRow addObject:[secondRow objectAtIndex:2]];

    NSArray *expected3rdRowHashes = @[@"15b05807bd481249f1ad113b96863e0bd70b8ef2d807400d8997c7b8fc0f82b1".hexToData,
        @"d6e299f15660574f2c30adf712fd38c03dbce8447bc79d9bb559e825ffd52a62".hexToData];

    XCTAssertEqualObjects([thirdRow copy], expected3rdRowHashes);

    NSMutableData *rootRowFirstConcatData = [[thirdRow objectAtIndex:0] mutableCopy];
    [rootRowFirstConcatData appendData:[thirdRow objectAtIndex:1]];

    NSData *rootHash = uint256_data([rootRowFirstConcatData blake3]);

    XCTAssertEqualObjects(rootHash.hexString, @"f0bba0f0472fad1a198e52266b726fa6eac3da0dd28eb1a2f1bc08d09e7f0c30");

    NSDictionary *elementsToProve = @{@(3): @"d5ede538f628f687e5e0422c7755b503653de2dcd7053ca8791afa5d4787d843".hexToData, @(4): @"27bb492e108bf5e9c724176d7ae75d4cedc422fe4065020bd6140c3fcad3a9e7".hexToData};

    NSData *merkleTreeProofData = @"ea7aa1fc9efdbe106dbb70369a75e9671fa29d52bd55536711bf197477b8f0219ab388bedc43eaf44150107d17ad090f6b1c34610f5740778ddb95d9f06576ee8912f1e49d6c94830787bc8765e92f409d6db9041739884a42e59f16388756b1".hexToData;
    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementsToProve:elementsToProve proofData:merkleTreeProofData hashFunction:DSMerkleTreeHashFunction_BLAKE3 fixedElementCount:6];
    UInt256 appHash = [merkleTree merkleRoot];
    XCTAssertEqualObjects(uint256_hex(appHash), @"f0bba0f0472fad1a198e52266b726fa6eac3da0dd28eb1a2f1bc08d09e7f0c30");
}


- (void)testMerklePos4Element {
    NSDictionary *elementsToProve = @{@(4): @"d78960dd1c7c038073d797f38ba662062639d52259db3ad8ce1c9f92e589e00a".hexToData};
    NSData *merkleTreeProofData = @"242cc2765a7e87669c33c2578b368b3087c0b53f3b7ba4a619602a11221b2ea978f9ce6e53dcfa18e32460be3a7f750e25bfffaab43c7c5d49aaffe53e2314af".hexToData;
    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementsToProve:elementsToProve proofData:merkleTreeProofData hashFunction:DSMerkleTreeHashFunction_BLAKE3 fixedElementCount:6];
    UInt256 appHash = [merkleTree merkleRoot];
    XCTAssertEqualObjects(uint256_hex(appHash), @"b11dcc99b72c60f0bcd7e1ed33c85006656d46147bb716e827e43949be838bc1");
}

//
//- (void)testMerkleTreeOddElements {
//    NSArray *elements = @[@"a", @"b", @"c", @"d", @"e"];
//    NSMutableArray *leaves = [NSMutableArray array];
//    for (NSString *element in elements) {
//        NSData *elementData = [element dataUsingEncoding:NSUTF8StringEncoding];
//        [leaves addObject:uint256_data(elementData.blake3)];
//    }
//
//    NSData *firstLeaf = [leaves firstObject];
//
//    NSArray *expectedHashes = @[@"17762fddd969a453925d65717ac3eea21320b66b54342fde15128d6caf21215f".hexToData,
//        @"10e5cf3d3c8a4f9f3468c8cc58eea84892a22fdadbc1acb22410190044c1d553".hexToData,
//        @"ea7aa1fc9efdbe106dbb70369a75e9671fa29d52bd55536711bf197477b8f021".hexToData,
//        @"d5ede538f628f687e5e0422c7755b503653de2dcd7053ca8791afa5d4787d843".hexToData,
//        @"27bb492e108bf5e9c724176d7ae75d4cedc422fe4065020bd6140c3fcad3a9e7".hexToData];
//    XCTAssertEqualObjects([leaves copy], expectedHashes);
//
//    NSMutableArray *secondRow = [NSMutableArray array];
//    NSMutableData *secondRowFirstConcatData = [[[leaves objectAtIndex:0] reverse] mutableCopy];
//    [secondRowFirstConcatData appendData:[[leaves objectAtIndex:1] reverse]];
//    [secondRow addObject:uint256_data([secondRowFirstConcatData blake3_2]).reverse];
//
//    NSMutableData *secondRowSecondConcatData = [[[leaves objectAtIndex:2] reverse] mutableCopy];
//    [secondRowSecondConcatData appendData:[[leaves objectAtIndex:3] reverse]];
//    [secondRow addObject:uint256_data([secondRowSecondConcatData blake3_2]).reverse];
//
//    NSMutableData *secondRowThirdConcatData = [[[leaves objectAtIndex:4] reverse] mutableCopy];
//    [secondRowThirdConcatData appendData:[[leaves objectAtIndex:4] reverse]];
//    [secondRow addObject:uint256_data([secondRowThirdConcatData blake3_2]).reverse];
//
//    NSArray *expected2ndRowHashes = @[@"83c76487fb05702e5e955cd9d77d98318a65797ade8e5d22f9abdfe2cf36a8f9".hexToData,
//        @"e69fe01075cd8c29edb4bd66d4e67d24109a86b9b60e0a568f3ec56638d9bed3".hexToData,
//        @"f077665d64481f1ea4f3d56dab7924ccd8b4d9e6bef03485558e9215df36f636".hexToData];
//
//    XCTAssertEqualObjects([secondRow copy], expected2ndRowHashes);
//
//    NSData *merkleTreeProofData = @"010000000310e5cf3d3c8a4f9f3468c8cc58eea84892a22fdadbc1acb22410190044c1d553e69fe01075cd8c29edb4bd66d4e67d24109a86b9b60e0a568f3ec56638d9bed3d000dee0c3f75f8ba8755fa7b113f2c5c29afc26519bdef3f6bff249c308dd260107".hexToData;
//    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementToProve:firstLeaf.UInt256 proofData:merkleTreeProofData hashFunction:DSMerkleTreeHashFunction_BLAKE3];
//    UInt256 appHash = [merkleTree merkleRoot];
//    XCTAssertEqualObjects(uint256_hex(appHash), @"2eb4325d8b759161f1998b400a0ac377d506118eb97f0f855c54e6e6a2bacf19");
//}
//
//- (void)testProofSystem {
//    NSData *proofData = @"01e958e15a5e7f012711997ff747c3cba9921044b90c26dfbbf518f7e270fb5a9f02229ae7d97d361daa2e70c3d682f290bbceb5493d88a2a2f9ce560d20e1992fbd100199d48dfa38b7064d9aedbcc74f28a8f1dc3bb103bf7180d1a3d74d804d678fa302e25e4ea30c17a86514960601b92227339ce88d057a12d76561b41d676457061210011a6849de9e9f8c663d06f7dc4c86bf66ccee22c4ad4ff8ea1f4125414956c3ad02a4424847298b8406f057c9375747da7d6e96d61ec3b10d5d5fef1e3fb67907d2100320e3105acf7fe6b61e6a3b9bf8054f59fb9264170945c4b40fb25d58b2ac2a1d47008da56269645820e3105acf7fe6b61e6a3b9bf8054f59fb9264170945c4b40fb25d58b2ac2a1d476762616c616e63651a3b9ac7e6687265766973696f6e006a7075626c69634b65797381a36269640064646174615821032fc3bdf73d86c40bd27fbd62a793356cd625508b2306231167ce4e61af66e55f6474797065006f70726f746f636f6c56657273696f6e0002a5fee690784b06f4765fec55ddbde482b40a7b4bb9ce8ed01440b59aa2f78f881001226345b996d3e565bd98de759767b7daddf2d452e428e542e1872622a1ef2b9511111111".hexToData;
//    NSDictionary *elementDictionary = nil;
//    UInt256 rootHash = [proofData executeProofReturnElementDictionary:&elementDictionary].UInt256;
//    NSString *expectedRootHashString = @"784f1ad1fc6065d00bf3d4d2e60af5298716a0b973ee9a5e107585e60b921612";
//    XCTAssertEqualObjects(uint256_hex(rootHash), expectedRootHashString);
//
//    NSData *merkleTreeProofData = @"0100000003bfef7d172b666943c33fae47b614259412f52435edd99bbf933144411c3aeab4ffc0c0b0c5053f25cf5be50aead3aabb6b75575e54db7401e2db85094a0cd1ace5bc49ba1d2e2c670b7ab5463de2736125c8582b76c6f3896461fd2ce7049d980103".hexToData;
//    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementToProve:rootHash proofData:merkleTreeProofData hashFunction:DSMerkleTreeHashFunction_BLAKE3];
//    UInt256 appHash = [merkleTree merkleRoot];
//    XCTAssertEqualObjects(uint256_hex(appHash), @"a33ffcc2bdf85f17baf8b8dfa0261b6f61b5b97ac74846fae60b0ec771f44a7c");
//}
//
//- (void)testProofSystem2 {
//    NSData *proofData = @"032001010101010101010101010101010101010101010101010101010101010101010089a5626964582001010101010101010101010101010101010101010101010101010101010101016762616c616e636500687265766973696f6e006a7075626c69634b65797381a3626964006464617461582103c96f68a1b66e9cbff209ae9aa12ed0906254888aaeaba59c4fdb07f047174b766474797065006f70726f746f636f6c56657273696f6e00".hexToData;
//    NSDictionary *elementDictionary = nil;
//    UInt256 rootHash = [proofData executeProofReturnElementDictionary:&elementDictionary].UInt256;
//    NSString *expectedRootHashString = @"82691e23d293166361342239d3179c8464474cd787c0ca414cffff4148d7d4f0";
//    XCTAssertEqualObjects(uint256_hex(rootHash), expectedRootHashString);
//
//    NSData *merkleTreeProofData = @"01000000030000000000000000000000000000000000000000000000000000000000000000234f5a545b901b0f5e439d015a221694a4e6611e2e7c1cd211f5b7e999f7777c1043acd3542bff73d48696ea4ecd0ecbab41ccd169bcfe89bc8b9ba64c08b9bc0106".hexToData;
//    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementToProve:rootHash proofData:merkleTreeProofData hashFunction:DSMerkleTreeHashFunction_BLAKE3];
//    UInt256 appHash = [merkleTree merkleRoot];
//    XCTAssertEqualObjects(uint256_hex(appHash), @"5b55d82e12c5ebb3eca8ccea2f73120f92451574740ebc582bfa1c993fbaa4b9");
//}
//
//
//- (void)testNonInclusionProof {
//    NSData *proofData = @"01c34fe708edc9b5b3a0e459431fda06c9e0f3fe232943b567e14644bdb18077da0320be5ea52cdb9f09014e0ce111170c790cc75c20acb9eb3301f4b7e477a3cd9db1008ba56269645820be5ea52cdb9f09014e0ce111170c790cc75c20acb9eb3301f4b7e477a3cd9db16762616c616e63651901ab687265766973696f6e006a7075626c69634b65797381a362696400646461746158210366e10390ac98132dd75aadf0c8d026b4c8a9c22df39d8669a5e8d39baa67595a6474797065006f70726f746f636f6c56657273696f6e00100320e93f06e95cacfdd6f61de59d61ed596aec9eec1deedfa64200c1f9d441bc8d49008ba56269645820e93f06e95cacfdd6f61de59d61ed596aec9eec1deedfa64200c1f9d441bc8d496762616c616e636519089f687265766973696f6e006a7075626c69634b65797381a36269640064646174615821030721d4368d65e0bf9684f3166b89cb7d05ee5bfde55b48bcd9d745fab29b52006474797065006f70726f746f636f6c56657273696f6e0011".hexToData;
//    NSDictionary *elementDictionary = nil;
//    UInt256 rootHash = [proofData executeProofReturnElementDictionary:&elementDictionary].UInt256;
//    NSString *expectedRootHashString = @"8167e6c7b2f7f6b5b0c764b076b719e1219fe3a76690aff2a45622e09f28c42c";
//    XCTAssertEqualObjects(uint256_hex(rootHash), expectedRootHashString);
//}

- (void)testOProof {
    //    NSData *proofData = @"016182ec1165c5aede542626be9bf366834d794152f1bb2b5a7c14c4976c27bd7302550dc4e5bb1f43d622bdbd64dcc537f54c62b458acf72d4767763de230aa142010018f0e39a4da211f14b55d7062ddd03ecc12b4fb516bf4604dd9a5dcc1a78c97e711".hexToData;
    //    NSDictionary *elementDictionary = nil;
    //    UInt256 rootHash = [proofData executeProofReturnElementDictionary:&elementDictionary].UInt256;
    //    NSString *expectedRootHashString = @"784f1ad1fc6065d00bf3d4d2e60af5298716a0b973ee9a5e107585e60b921612";
    //    XCTAssertEqualObjects(uint256_hex(rootHash), expectedRootHashString);
}

- (void)testNonInclusionProof {
    NSData *proofData = @"0a60bfef7d172b666943c33fae47b614259412f52435edd99bbf933144411c3aeab49b901c60efbd5040ab1122197418963b88d06dc440b88e02efca9292f0f0f275072907f22609678cb56cacace7bbd6ca9d7b6db1effd1d674a83cab37d9d40ba12fa040af70401f5935375cf59fffdb6e1a952095920fc6c3be6e40ac4d544e54a1c04d72029ac02c97ff70a287f4d9741f5c54e5fc5e6a365043cdbedf623ae7d0e280a6a32b70b1001581ec666a851b0a6547f14bfcbd9d6b21f7f7fb944ef694dd00a28d9dc710ee302d6319f3e691f57474ccae8f14c482b856dc74559c1648b7f7640748f2de7f5a110032090c756d54d86613eee798c7c63901b3737103a4fff8e226ca0018bbd71073c21007e01000000a4626964582090c756d54d86613eee798c7c63901b3737103a4fff8e226ca0018bbd71073c216762616c616e636519117b687265766973696f6e006a7075626c69634b65797381a3626964006464617461582102ff7d43b945d51e15e2d18e6f726c8570eb48653729f57e606160075cc00a181564747970650011032097bbfe64471f69f36bc532b97c4cd807ceb0c9e14d6dfdc901c867218eb753ad007e01000000a4626964582097bbfe64471f69f36bc532b97c4cd807ceb0c9e14d6dfdc901c867218eb753ad6762616c616e6365190340687265766973696f6e006a7075626c69634b65797381a3626964006464617461582103901425c2e735100b33b1d86694846d3f19d6304c8036c04ddebf7f562dfe112264747970650010014278b5602a918a552629503a8389953f4846f1d8c70ed3d657e520aa3483562c11027f39f41ed72cdee1a84117a520a0e92ad615ad73884c9e752f5d27593d9f7eea1001114f06e497bcc272aa13d7c8e7b185283180a4dba5549331fa599d6f62ac139811021ff2e1078cea7c2c27daf05eed4a93d222105b894df3a39f0f2dbca7102ea9e31001be87efded4c0b8be1e396ae07aed3f332c13929a04745e531912dd21f18d256911111a20000000d5aaeab71f10c0a31433968840113801f489c0b2c93a8ce78da75e317f22608b7118182a6b5c1480ee0c9d4399138a2de5b883fe5fe71a41b190aacc70883514712f15ff8f08ab16925231fe72172508c9de9b8f7676d9b6ce5b229fb6611a0b05144efa22cb8b943d10ba94a56a1592220fe5c196193c571d1f6beeb11261".hexToData;

    NSData *metaData = @"08db2210c9a803".hexToData;

    NSData *signatureLLMQHashData = @"000000d5aaeab71f10c0a31433968840113801f489c0b2c93a8ce78da75e317f".hexToData;
    NSData *signatureData = @"8b7118182a6b5c1480ee0c9d4399138a2de5b883fe5fe71a41b190aacc70883514712f15ff8f08ab16925231fe72172508c9de9b8f7676d9b6ce5b229fb6611a0b05144efa22cb8b943d10ba94a56a1592220fe5c196193c571d1f6beeb11261".hexToData;
    NSData *rootTreeProofData = @"bfef7d172b666943c33fae47b614259412f52435edd99bbf933144411c3aeab49b901c60efbd5040ab1122197418963b88d06dc440b88e02efca9292f0f0f275072907f22609678cb56cacace7bbd6ca9d7b6db1effd1d674a83cab37d9d40ba".hexToData;
    NSData *identitiesProofData = @"01f5935375cf59fffdb6e1a952095920fc6c3be6e40ac4d544e54a1c04d72029ac02c97ff70a287f4d9741f5c54e5fc5e6a365043cdbedf623ae7d0e280a6a32b70b1001581ec666a851b0a6547f14bfcbd9d6b21f7f7fb944ef694dd00a28d9dc710ee302d6319f3e691f57474ccae8f14c482b856dc74559c1648b7f7640748f2de7f5a110032090c756d54d86613eee798c7c63901b3737103a4fff8e226ca0018bbd71073c21007e01000000a4626964582090c756d54d86613eee798c7c63901b3737103a4fff8e226ca0018bbd71073c216762616c616e636519117b687265766973696f6e006a7075626c69634b65797381a3626964006464617461582102ff7d43b945d51e15e2d18e6f726c8570eb48653729f57e606160075cc00a181564747970650011032097bbfe64471f69f36bc532b97c4cd807ceb0c9e14d6dfdc901c867218eb753ad007e01000000a4626964582097bbfe64471f69f36bc532b97c4cd807ceb0c9e14d6dfdc901c867218eb753ad6762616c616e6365190340687265766973696f6e006a7075626c69634b65797381a3626964006464617461582103901425c2e735100b33b1d86694846d3f19d6304c8036c04ddebf7f562dfe112264747970650010014278b5602a918a552629503a8389953f4846f1d8c70ed3d657e520aa3483562c11027f39f41ed72cdee1a84117a520a0e92ad615ad73884c9e752f5d27593d9f7eea1001114f06e497bcc272aa13d7c8e7b185283180a4dba5549331fa599d6f62ac139811021ff2e1078cea7c2c27daf05eed4a93d222105b894df3a39f0f2dbca7102ea9e31001be87efded4c0b8be1e396ae07aed3f332c13929a04745e531912dd21f18d25691111".hexToData;
    NSError *error = nil;
    Proof *proof = [[Proof alloc] initWithData:proofData error:&error];

    XCTAssertNil(error);

    XCTAssertEqualObjects(proof.signature, signatureData, @"Signature must match");
    XCTAssertEqualObjects(proof.signatureLlmqHash, signatureLLMQHashData, @"Signature quorum must match");
    XCTAssertEqualObjects(proof.rootTreeProof, rootTreeProofData, @"Root tree proof must match");
    XCTAssertEqualObjects(proof.storeTreeProofs.identitiesProof, identitiesProofData, @"Identity tree proof must match");

    DSQuorumEntry *quorumEntry = [[DSQuorumEntry alloc] initWithVersion:1
                                                                   type:DSLLMQType_10_60
                                                             quorumHash:@"7f315ea78de78c3ac9b2c089f40138114088963314a3c0101fb7eaaad5000000".hexToData.UInt256
                                                        quorumPublicKey:@"0a396fd00ac8f678a242c4b14004fe3402bdb9ada641e48e11ca6be3c87c5858b4cbc6014622d98df95b1a68b1bbd46c".hexToData.UInt384
                                                        quorumEntryHash:UINT256_ZERO
                                                               verified:TRUE
                                                                onChain:[DSChain testnet]];

    ResponseMetadata *responseMetaData = [[ResponseMetadata alloc] initWithData:metaData error:&error];

    XCTAssertNil(error);

    NSDictionary *results = [DSDAPIGRPCResponseHandler verifyAndExtractFromProof:proof withMetadata:responseMetaData query:nil forQuorumEntry:quorumEntry quorumType:DSLLMQType_10_60 error:&error];

    XCTAssertNil(error);
}

- (void)testWaitForStateTransitionResultInclusionProof {
    NSData *proofData = @"0a60efd5461124e5f8850a9d92e11133a29e54925508f728529b504cc89ea151504bc19588e2fc7e3a7f1b83289479f45e57d340e8befb5809be613443310bd77d11523efa305434c26c86cd1c97749996906f82df1f756207350ae5e18db782c76312bf040abc0401761149f5816723fdc7025790d285f63bbe26acb3471e57f28fa4db6e4859c3ae02887fcd3a7fef9b356dd12fc2e4d58c54c9e42908070dee2aaf7c7b5d389f736010017d1db154d2a87f5f5136a1b8581759b75e72d6047ee3efbfcba0889c2d4e8b6302b1a68c50747a42fd140dedcabb7c4ff3ebed1c729a1541ba1b44f1ad7c24a3e21003206c05f39cee3a2c1436b61a0746503a743658b2d0e76b432e741f9bbbe211dc34008001000000a462696458206c05f39cee3a2c1436b61a0746503a743658b2d0e76b432e741f9bbbe211dc346762616c616e63651a3b9ac7f4687265766973696f6e006a7075626c69634b65797381a36269640064646174615821032d6d975393f17c0d605efe8562c06cbfc913afcc73d0d855399c0a97d776154064747970650002163fc42a48f26886519b6e64280729c5246d92dad847823faef877eb282c7fb81001d715565e9f71ae94fe2d07568d1e2fd1043bca07c2da385dcb430cb84f92882211022325a14555b8403767a314c3bc9b8708a25e2bc756cecadf56e5184de8dcc3a31001b51e23fbb805bfd917bb0e131da4488c48417dbe82bd6d7e9d69a50abd77a3c31102f41f6cae67288cccacc79ab5c2c29fd6ec3b83919625131ec9139c65606849c61001f234e77a4845b865816729fa14801189395d2ce658c1a24130f45b076d8f047a11111102c97ff70a287f4d9741f5c54e5fc5e6a365043cdbedf623ae7d0e280a6a32b70b10018a28f5bebdbf987079878315cde74e22ef591983a576d3c6e2807ae1fd12ff88111a20000001941bf6624b148ce18aa8c3ee0be4d73156b459735e162e5365341a804822601424961c3c7f540d06bd4be13d3b066bb40adf3091919d095f887174a9d9c271af65c403ab8e3c177f15168dfcaeea2a10af7766703cc1c8b7dcd0da065ecb3b1c0e7f2e7a3c7c69027799980fa80559053fa7f969a4c73e940343a46290b392".hexToData;

    NSData *signatureLLMQHashData = @"000001941bf6624b148ce18aa8c3ee0be4d73156b459735e162e5365341a8048".hexToData;
    NSData *signatureData = @"1424961c3c7f540d06bd4be13d3b066bb40adf3091919d095f887174a9d9c271af65c403ab8e3c177f15168dfcaeea2a10af7766703cc1c8b7dcd0da065ecb3b1c0e7f2e7a3c7c69027799980fa80559053fa7f969a4c73e940343a46290b392".hexToData;
    NSData *rootTreeProofData = @"efd5461124e5f8850a9d92e11133a29e54925508f728529b504cc89ea151504bc19588e2fc7e3a7f1b83289479f45e57d340e8befb5809be613443310bd77d11523efa305434c26c86cd1c97749996906f82df1f756207350ae5e18db782c763".hexToData;
    NSData *identitiesProofData = @"01761149f5816723fdc7025790d285f63bbe26acb3471e57f28fa4db6e4859c3ae02887fcd3a7fef9b356dd12fc2e4d58c54c9e42908070dee2aaf7c7b5d389f736010017d1db154d2a87f5f5136a1b8581759b75e72d6047ee3efbfcba0889c2d4e8b6302b1a68c50747a42fd140dedcabb7c4ff3ebed1c729a1541ba1b44f1ad7c24a3e21003206c05f39cee3a2c1436b61a0746503a743658b2d0e76b432e741f9bbbe211dc34008001000000a462696458206c05f39cee3a2c1436b61a0746503a743658b2d0e76b432e741f9bbbe211dc346762616c616e63651a3b9ac7f4687265766973696f6e006a7075626c69634b65797381a36269640064646174615821032d6d975393f17c0d605efe8562c06cbfc913afcc73d0d855399c0a97d776154064747970650002163fc42a48f26886519b6e64280729c5246d92dad847823faef877eb282c7fb81001d715565e9f71ae94fe2d07568d1e2fd1043bca07c2da385dcb430cb84f92882211022325a14555b8403767a314c3bc9b8708a25e2bc756cecadf56e5184de8dcc3a31001b51e23fbb805bfd917bb0e131da4488c48417dbe82bd6d7e9d69a50abd77a3c31102f41f6cae67288cccacc79ab5c2c29fd6ec3b83919625131ec9139c65606849c61001f234e77a4845b865816729fa14801189395d2ce658c1a24130f45b076d8f047a11111102c97ff70a287f4d9741f5c54e5fc5e6a365043cdbedf623ae7d0e280a6a32b70b10018a28f5bebdbf987079878315cde74e22ef591983a576d3c6e2807ae1fd12ff8811".hexToData;
    // NSData *stateHash = @"255209dcf92ed09fac41d71d8d517f60e180abe5a8eb2d24a477be7a85eb85ea".hexToData;
    NSError *error = nil;
    Proof *proof = [[Proof alloc] initWithData:proofData error:&error];

    XCTAssertNil(error);

    XCTAssertEqualObjects(proof.signature, signatureData, @"Signature must match");
    XCTAssertEqualObjects(proof.signatureLlmqHash, signatureLLMQHashData, @"Signature quorum must match");
    XCTAssertEqualObjects(proof.rootTreeProof, rootTreeProofData, @"Root tree proof must match");
    XCTAssertEqualObjects(proof.storeTreeProofs.identitiesProof, identitiesProofData, @"Identity tree proof must match");

    DSQuorumEntry *quorumEntry = [[DSQuorumEntry alloc] initWithVersion:1
                                                                   type:DSLLMQType_10_60
                                                             quorumHash:@"48801a3465532e165e7359b45631d7e40beec3a88ae18c144b62f61b94010000".hexToData.UInt256
                                                        quorumPublicKey:@"103425b2fd21494e7116766182efecb7479da2572bb1f226936152d615625b100477538261beaa87ff4442822b85d75e".hexToData.UInt384
                                                        quorumEntryHash:UINT256_ZERO
                                                               verified:TRUE
                                                                onChain:[DSChain testnet]];

    ResponseMetadata *responseMetaData = [[ResponseMetadata alloc] init];
    responseMetaData.height = 5851;

    NSDictionary *results = [DSDAPIGRPCResponseHandler verifyAndExtractFromProof:proof withMetadata:responseMetaData query:nil forQuorumEntry:quorumEntry quorumType:DSLLMQType_10_60 error:&error];

    XCTAssertNil(error);
}

- (void)testb {
    NSData *proofData = @"01855c67fabc4c78c7f31ba4aaedbbb8bc0c3dc3a2c3934de085086fe884ab818702fbf32b582538666ca797807cd087df7e16caeffebfc40a94448f62e370ef7bba10012a1c507d151f798bd6caaacfcf81f9fb7d1082e622fceeb34fe635bbb2d5d12d02c6f5eeb25eca74b43d6257bfc85b570b70d76f0cf3e39385a70e964d537ea59a1001cade51b7cfa6ebff287bd8940a2867edb23e2c6a0023d16897d4ea76c4d6edb603146d5bb55b89df88a9b4e9c3481482f7f5591450f70020550fee513eb01b24e00f3ce061df61d26f72887a57a4a8b6a7b6ac4d337815091003146e79f54511d16bb62f4bd9e777601476492d2cf50020b940e7b5058cfa05e14728cec8f887aaa26ee85afb7f017cb0658fbe6139dcf01102aefddd2736cff4dca9a78a6c22581ced5a5504044941ce0738299597f76a2327100108b6f41d330f880503e46415d4163d78adf6304e1c2c412103709187123236cd1111021792cd1eb9b9e0bd298c2f393bebe82c17ad3c78e26a45ca759c0ff42d8adc95100124d4c679ffa39cac14c490d968bebe7a0ca4583cd99c30d5494d17a5be254d96110274d5cda9db960da8eebe9de190de382707eb35196776f133d76a73731ef34702100129d8dc5d79ca523ba86fb239feb0c0ed3f8cab0db99bb74435520fdb1c452d841102c1a461d30f21383643451cb8a99a03f946e23884799a7a68c172f7c7128ca2071001c9bd09e3e505df047585cbd8d810cc4eb5ccfa96ac9098414b0385536d9c114e03149c7868515d684da9468d6eaff354902795c1509800202947ab16436bb350747029bb2b317131d564ef524c33f4ad427b406a543c084e1003149e252ab65d4720219318757eaa72bbfc82b308fb0020a636c2bfccecc173ba17f6e02007d2a387296367a29432f7de739aa764a6c06602df5d0b07be32b38bf45622575cc13aaa76fbbead63605ecae90cad0b08d2fef710018b207bfe780dad5658d68b187bb19454b9d25bbe6eb273fddbfa1784cde6e567111102ecc64edb31efceda8464902aca9458bd0e79f3f67707cedcda9d0097e43395801001559c1b67c318222027dba00d01898a675de8e9259d17e079a55738e05c3379441102c988701bc990b52c71f95f1207caa3c28c8a920ab0e661ccb2aa64670516479c100148523875d70731aad42ab1bf741fee47c0df6b5dbf9a93ec2830d228491ddf241102fd0ca4e90c8c7e80095b9a02c3fbae2a017f8a27efdb572d3e08144693693e371001ef86c0cffc4c6d9f9aba624532882d582dbd383afef148d3a3911703e972ff0b1102e9010df939d28f3fd03cc1c42d1da8095069c9243dc85015cf13648d78dd315810016ace7c7c345d5e66218653cb09388e929dedb516ad53ea50a113323dfe696b4411025cba47bc15079bc723dcaeff8ebd7c29b3f57c4c5a818c4ac9ae8f20462a027a1001b336b955deef58085d824bfef1a3c17c86fde476a3da71cb12f6486efbf571c9026bc5326255618a14db7e39d3a2744e634987895e5e7ef8cb6dfc0645b7e04b3d100314d14934b8e8685d877559ddf6fa8573d4290499740020ac65e8f83dfefa356f241c0c2ab7257ff78bbbfa191482aa8c1d65ab050638ac110314d3d23850065dcf48401ccbe39c598c85e508477400209c7398b100a8ebdd2db02e930bd8fb4444fbf1b2e146122a47acf5e3f9ca7a0a1001961d9ad46e6baeee49c41aa14057ec2502a6ad210094e878dad45e0b80197b5a1102012b1dec68a745963a7c58df7d9e3451460c9ced23dc74ba71df8de8486d71dd100172832d20390866f34b88a9b2c5b925f3a8a7596547b589d6a01cca3d04840f6a02418cfb159b58cc72816cf863a24cc75d7532976b48438f74f713ab6ff9cc82b7100314d844229a7b088d8e3a43081347fffb09827bdbf700207e916651c5bfae593a72daaf7dfde0479dcec213d53a9940ee3ac57595d79ea60314da2141ce2eaad87828f562000f6656505c38c07b00209a75bd92be6f9f77fb6e6dc7913873ed968d36b4c46130549432bcde6f840a8611111102a1368ce9c74b0a304bc6a252b89022d62a9886c2feae877101175b861dafb0561001b55ca0e2dc9f4210481534e6c964215395a3efe19300157477d996ee3747f628110210fb20986a7acec33921501760797dbd14f4b66a44d7471a26f854fbdbd7151d10017aba4440baa3d5ba9cbbf9eca0455af56f5581ef23b61c0cc9e5b32ef798568411111111".hexToData;

    NSError *error = nil;
    NSDictionary *dictionary = nil;
    [proofData executeProofReturnElementDictionary:&dictionary query:nil decode:false usesVersion:true error:&error];

    XCTAssertNil(error);
}

- (void)testc {
    NSData *proofData = @"01e2650c850ddf52c73b05dd32595b2450cefe2f93bd3cbc348dab14c30160eeb302fbf32b582538666ca797807cd087df7e16caeffebfc40a94448f62e370ef7bba1001a753989d3b5dac05aed1352f3eb415c6a37f2041e12b7cccf5891927c71bea8802c6f5eeb25eca74b43d6257bfc85b570b70d76f0cf3e39385a70e964d537ea59a1001cade51b7cfa6ebff287bd8940a2867edb23e2c6a0023d16897d4ea76c4d6edb603146d5bb55b89df88a9b4e9c3481482f7f5591450f70020550fee513eb01b24e00f3ce061df61d26f72887a57a4a8b6a7b6ac4d337815091003146e79f54511d16bb62f4bd9e777601476492d2cf50020b940e7b5058cfa05e14728cec8f887aaa26ee85afb7f017cb0658fbe6139dcf01102aefddd2736cff4dca9a78a6c22581ced5a5504044941ce0738299597f76a2327100189c2cbf75d22980f753427205dd6de5792a56c1213d93e0348a71bfc597531481102d3ec8e51deef0d5da0bdd13a946fa757cca0708b208fd8e8e9a1f6f804d9f57a1001e70ece2315de31808aaa82dad1b48abf3d0b1644c4eca6e4a33815084d1b51511111021792cd1eb9b9e0bd298c2f393bebe82c17ad3c78e26a45ca759c0ff42d8adc9510017d6dede6d2be4b66c7a8661f97267d206934db6e56a9bcacb026c5a8c10166a0110274d5cda9db960da8eebe9de190de382707eb35196776f133d76a73731ef347021001326fb975a3234c753bb96106d72ed6fef35d6689958f81bcb31b14de4a6f10031102c1a461d30f21383643451cb8a99a03f946e23884799a7a68c172f7c7128ca2071001cc8cfd4b9e51cb19d863871b61269184f495b579dd9c66267ee1ad7a5ab034b502c284ad83e8ddf5bfbd38e07b7fb3b48b05359e0be219fd592a02e2ff5f8fd2bc1003149cf751d5530cbbaa6368902870ac400ea4951be8002040e5a125e4dcf76870ca84a874fac23b5600cef4e5edb75345f59c923ba8b36503149e252ab65d4720219318757eaa72bbfc82b308fb0020a636c2bfccecc173ba17f6e02007d2a387296367a29432f7de739aa764a6c066101102df5d0b07be32b38bf45622575cc13aaa76fbbead63605ecae90cad0b08d2fef71001cb2a932682bea2a11f4dacdff3d70ab339ce05103d01145895b877682c8c477e1102ecc64edb31efceda8464902aca9458bd0e79f3f67707cedcda9d0097e43395801001122bb7f38644a396cd5231f3c0c77fd77c839c9ac8ba44b54cf2e64ba4fea7751102c988701bc990b52c71f95f1207caa3c28c8a920ab0e661ccb2aa64670516479c1001440fdc81034d8690cbdb3bc1a93eaa5a8499b340b1910552096b120f15bedb8d1102fd0ca4e90c8c7e80095b9a02c3fbae2a017f8a27efdb572d3e08144693693e37100104d30bffec262d5de8e0bc227ea8e2b7548fc50e8c2ab4319f82018631c4686b027076941bbbf8f3298940420bdc6edeae7accf0adc5eba1a5b32f97121f4e8a811001cacfa5f13182793e3c215fa8a760b8e028e05232369fb4e37e3b8a361375fa3d023f7167d53807810b75f65a69f3b6037c101d9dfdcb75dbcab43cd99160061f871002052a45179078d6072ca3e841f8081da282c6fab26dccc2ea612994a19ea7bb5d0314b2c4d80c2d16da67cb42ad5765513668b4fc524d002011d2e8da81921c6e701d8efbdc7f5cc7f7e57c87e74a62a741ce2ea687364da01111110210f1b816fc208069ebb6d205718a1ae2debfb12a1d38c849511b2eb8d1dc70ee1001878c95e30fd3db684abaf60dcb18e33ab5bd38ae990e389c7caa727b9854270f111102e9010df939d28f3fd03cc1c42d1da8095069c9243dc85015cf13648d78dd31581001c054636a61b39cc13add5a9bc7dc7df79e29f2364f9af7f0c517b37e20122d7b11025cba47bc15079bc723dcaeff8ebd7c29b3f57c4c5a818c4ac9ae8f20462a027a1001b336b955deef58085d824bfef1a3c17c86fde476a3da71cb12f6486efbf571c9026bc5326255618a14db7e39d3a2744e634987895e5e7ef8cb6dfc0645b7e04b3d1002e72e4a09222f2e271c09be94c5fd1e82e0f91b9502d8103146af78fe2cf916820314d2af9b429c9094ae0f008f9d2a4bd8247601b0710020595934549be7cd8a4c366643a8180e3f4118a8088f2e253e4e3c1786bd121ef311110314d3d23850065dcf48401ccbe39c598c85e508477400209c7398b100a8ebdd2db02e930bd8fb4444fbf1b2e146122a47acf5e3f9ca7a0a1001961d9ad46e6baeee49c41aa14057ec2502a6ad210094e878dad45e0b80197b5a1102012b1dec68a745963a7c58df7d9e3451460c9ced23dc74ba71df8de8486d71dd1001333358550074eead02d16e27b11e8708fa71f82ec15a77a528e417281409882402a50fa6f8d83749859dc03d30369854abde3aa46e45ca7893e7a153dc24ccd477100314d8643c59a19fc6cf7fb89bf0e38f48147eb771650020517f6a53daffc9573d5c5eed1f976723c54da4bfad182c7520d6c98a36e164940314d96c436386e37be642c2d0c9819226e4b7059fab002053bed8a5de6ab4d86ba8a7f3a46fa0dee9548b60ce1972a3aa662996d678ff3f1001fbcc72ba62374f616b7ae2e796d0fd23446eb1cb7041dfca6df438292e20023011111102a1368ce9c74b0a304bc6a252b89022d62a9886c2feae877101175b861dafb05610012260b4f35d9f11b93166f2b37bb50951a81abe6c425ec316f3512a7cab4b6b2b110210fb20986a7acec33921501760797dbd14f4b66a44d7471a26f854fbdbd7151d100181ec1272f3510f9d14a9f7546122d6ad40c890d1d627c60b182e3c6214a2334911111111".hexToData;

    NSError *error = nil;
    NSDictionary *dictionary = nil;
    [proofData executeProofReturnElementDictionary:&dictionary query:nil decode:false usesVersion:true error:&error];

    XCTAssertNil(error);
}


@end
