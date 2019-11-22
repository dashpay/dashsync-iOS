//
//  DSSparseMerkleTreeTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 11/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSSparseMerkleTree.h"
#import "NSData+Bitcoin.h"
#import "NSString+Dash.h"

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
    
    NSData * valueData = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData;
    UInt256 key = @"505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"adb4e8a521216f1eb1c6f6663c4c04dcee910109c7c4657bb542d80fe1fde0a3".hexToData, [defaultNodeData copy], @"ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /* 2. inclusion proof for key 5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d:

    hashes: [3648f97f06e804f77cd36e4de4eee313b149f9357acf9377efa4cc4f6e128e13, 00, ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9, 00, 5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0
    error: <nil> */
    
    {
    
    NSData * valueData = @"3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0".hexToData;
    UInt256 key = @"5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"3648f97f06e804f77cd36e4de4eee313b149f9357acf9377efa4cc4f6e128e13".hexToData, [defaultNodeData copy], @"ee2c0ed291a897a32f1221b17b24aa69018c69c4dac494918a65e39ebca426b9".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /* 3. inclusion proof for key 5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d:

    hashes: [e9455cb528388fc14678a440582dfee3fd267f28c50163928e5d4285e3e25c04, 00, 5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 69ee174fca84f3a77aae498ef75db4ae80811d57969301e08f4ad736bb9fa231
    error: <nil> */
    
    {
    
    NSData * valueData = @"69ee174fca84f3a77aae498ef75db4ae80811d57969301e08f4ad736bb9fa231".hexToData;
    UInt256 key = @"5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"e9455cb528388fc14678a440582dfee3fd267f28c50163928e5d4285e3e25c04".hexToData, [defaultNodeData copy], @"5189f89042bacaf1691c2a09ae480283910dccec2ee0541cf2d7a833b73c0450".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /* 4. inclusion proof for key 63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce:

    hashes: [35c119a1313c9f503b1700ef7a9d85e1bf833d967d8a479c51d42dec38d04ae4, 66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: 7b029896bb622ca5e21916c9b3c5a2e8b60e44b9da5442af1c8fc178922d70fe
    error: <nil> */
    
    {
    
    NSData * valueData = @"7b029896bb622ca5e21916c9b3c5a2e8b60e44b9da5442af1c8fc178922d70fe".hexToData;
    UInt256 key = @"63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"35c119a1313c9f503b1700ef7a9d85e1bf833d967d8a479c51d42dec38d04ae4".hexToData,
                         @"66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /* 5. inclusion proof for key 6b2635e55813363bb79c180332489ab19a8b1e8d71bc4ded9e9564b101485538:

    hashes: [1bcbff246376885b33b3bf49d73f96ae270d038583c74408e75fd11a559c788e, 66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    included: true
    proof value: a77c88bfb32b7bfa3c0ae8bae5a483db161ed58df5baf4c13aadaa67ecc5b76a
    error: <nil> */
    
    {
    
    NSData * valueData = @"a77c88bfb32b7bfa3c0ae8bae5a483db161ed58df5baf4c13aadaa67ecc5b76a".hexToData;
    UInt256 key = @"6b2635e55813363bb79c180332489ab19a8b1e8d71bc4ded9e9564b101485538".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"1bcbff246376885b33b3bf49d73f96ae270d038583c74408e75fd11a559c788e".hexToData,
                         @"66cb3c546ea6824d81a0729ac246753a772b4fb80113546f9b2c1f92ee36c893".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /* 6. inclusion proof for key 7de7689b7743b75b7f3682d77ae8cc88fb599f82cf376a0afbb9bec757b53dea:

    hashes: [be35b14d1fde819744c1408dd382320eeecba25ec77a3d2492ddb2cbd751f8dc, 3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a, 00, 5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3]
    proof value: e14839a44f4fa7d399ed3f1cbc7d02fb81dcfb60be698902ac3c792a4f46064e
    error: <nil> */
    
    {
    
    NSData * valueData = @"e14839a44f4fa7d399ed3f1cbc7d02fb81dcfb60be698902ac3c792a4f46064e".hexToData;
    UInt256 key = @"7de7689b7743b75b7f3682d77ae8cc88fb599f82cf376a0afbb9bec757b53dea".hexToData.UInt256;
    UInt256 root = @"5ee64d1f17cd3c4b991c74ec4d6e0032d5f0121ba5b39540fec95203a9a27a6a".hexToData.UInt256;
    
    uint8_t zero = 0;
    NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
    
    NSArray * hashes = @[@"be35b14d1fde819744c1408dd382320eeecba25ec77a3d2492ddb2cbd751f8dc".hexToData, @"3bab95cf444b269440ecf8363d7108a7c545ddac97ef94d0151dcbf5e421bd0a".hexToData, [defaultNodeData copy], @"5ba3005b625a11558ae072550f2e2c141757adc299cec78b0ba00b212b41f9d3".hexToData];
        
    [DSSparseMerkleTree verifyInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
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
    
    NSArray * hashes = @[@"cff42290786a4cda6ac477a433ac17e0a8bdfcb51de80a6034e054aaaf691634".hexToData, @"b282d08971cd786752ce7a9047da6ed9016124f2a071e095c0e55cf5b02a3136".hexToData, @"3216e3f35f32a28cef785491ad3989f463431ed0f25d6910e0d3fd9ee9c531b4".hexToData];
    
    [DSSparseMerkleTree verifyNonInclusionWithRoot:root forKey:key withProofKeyData:[NSData data] withProofValueData:[NSData data] againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
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
    
    NSData * valueData = @"0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5".hexToData;
    UInt256 key = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"e0".hexToData;
    
    NSArray * hashes = @[@"bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:3 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
/*  2. compressed inclusion proof for key 3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0:
    bitmap: [e0]
    hashes: [bf6fee408e5469396eab0ff814773129a83bf90d1b8e44883902c73f2bfaf034, 464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 3
    included: true
    proof value: 21c817b446dace1b294ce407e6190f04ad9c92fe48a9264b11f733bcd5c6fb12
    error: <nil> */
    
    {
    
    NSData * valueData = @"21c817b446dace1b294ce407e6190f04ad9c92fe48a9264b11f733bcd5c6fb12".hexToData;
    UInt256 key = @"3d52390e626ad78572d813ccc5b6b74a42a87b022f149f3a09ee0aa0a5e7c2f0".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"e0".hexToData;
    
    NSArray * hashes = @[@"bf6fee408e5469396eab0ff814773129a83bf90d1b8e44883902c73f2bfaf034".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:3 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /*  3. compressed inclusion proof for key 505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67:
    bitmap: [ae]
    hashes: [4b5e4d3fad51630d2fae01e617074e1b1c97b68467493b5e5bbf3648b7c1a905, cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 7
    included: true
    proof value: 2b63dadf2107b10b52b6374c05fd7152062bd0c67bd3796e3aa70bb68c2d6005
    error: <nil> */
    
    {
    
    NSData * valueData = @"2b63dadf2107b10b52b6374c05fd7152062bd0c67bd3796e3aa70bb68c2d6005".hexToData;
    UInt256 key = @"505a7b82139b213ec5db84252f0b4a2e669f0b9e8cac0d255e68dc3e35a0dd67".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"ae".hexToData;
    
    NSArray * hashes = @[@"4b5e4d3fad51630d2fae01e617074e1b1c97b68467493b5e5bbf3648b7c1a905".hexToData, @"cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
        @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
        @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:7 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /*  4. compressed inclusion proof for key 5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d:
    bitmap: [ae]
    hashes: [744aca6fb75026664bd26c3759bec7606a7837db11be4329ee30c928334e0657, cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    lenght: 7
    included: true
    proof value: 3662035a8e2a7f40130baaa4178564f75a020f7f869b36e701efff4ae146aaf5
    error: <nil> */
    
    {
    
    NSData * valueData = @"3662035a8e2a7f40130baaa4178564f75a020f7f869b36e701efff4ae146aaf5".hexToData;
    UInt256 key = @"5345c6cbdee4462a708d51194ff5802d52b3772d28f15bb3215aac76051ec46d".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"ae".hexToData;
    
    NSArray * hashes = @[@"744aca6fb75026664bd26c3759bec7606a7837db11be4329ee30c928334e0657".hexToData, @"cb0696e4fbf67b29e7e8ecebc52d3cfbdcb24e9d859bbf398667bcd90f2e7a88".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
        @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
        @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:7 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /*  5. compressed inclusion proof for key 5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d:
    bitmap: [b8]
    hashes:  [088e8d435a628a6c6966e7fca6225779dde08a6405cede722e9cf76d70886a89, f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    lenght: 5
    included: true
    proof value: 40d4fd1568130be6926f2a6023b4b83c4197a1fe309b2dc762d46fc015c5182a
    error: <nil> */
    
    {
    
    NSData * valueData = @"40d4fd1568130be6926f2a6023b4b83c4197a1fe309b2dc762d46fc015c5182a".hexToData;
    UInt256 key = @"5a41c0b600c88656cfe8678dca763899f7d5eafa0a8a01cbc7d4362175c9c82d".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"b8".hexToData;
    
    NSArray * hashes = @[@"088e8d435a628a6c6966e7fca6225779dde08a6405cede722e9cf76d70886a89".hexToData, @"f88ba5eef9bf589da4327bfece90580103da499a4ff0b6f34b8d3b3cc139f055".hexToData,
        @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
        @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:5 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
    }
    
    /*  6. compressed inclusion proof for key 63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce:
    bitmap: [f8]
    hashes: [88fbab40d43219bb5dfa20ea713724da7c8e4403249fef4996cf7ecbdd62d5c2, b79593e6d96ac011687a1c4db8efdd3a8c97e02f5614b5f0c13f40ee806f7940, b01249919fd8940f972aaade5bc4034fe1556ffe47243ab0fa40094a898f4070, 5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68, ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3]
    length: 5
    included: true
    proof value: 4352b80b63fbb5b86a21a3c8fc8a4d96e0b4c855d94c10af4d407f26b73ee170
    error: <nil> */
    
    {
    
    NSData * valueData = @"4352b80b63fbb5b86a21a3c8fc8a4d96e0b4c855d94c10af4d407f26b73ee170".hexToData;
    UInt256 key = @"63390db6b63e34b09e15a71b0be9c92fd88b7ef43c938f15c9667334f7b825ce".hexToData.UInt256;
    UInt256 root = @"eb2c9b7c6005720a01f77f417e8193508eb86b57543cf004870825075ed99659".hexToData.UInt256;
        NSData * bitmap = @"f8".hexToData;
    
    NSArray * hashes = @[@"88fbab40d43219bb5dfa20ea713724da7c8e4403249fef4996cf7ecbdd62d5c2".hexToData, @"b79593e6d96ac011687a1c4db8efdd3a8c97e02f5614b5f0c13f40ee806f7940".hexToData,
        @"b01249919fd8940f972aaade5bc4034fe1556ffe47243ab0fa40094a898f4070".hexToData,
        @"5a2f5df10e62b0bddeda0de7ca257da2840a2adcdb82ca6d9ab58fb789170e68".hexToData,
        @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
        
    [DSSparseMerkleTree verifyCompressedInclusionWithRoot:root forKey:key withValueData:valueData againstProofHashes:hashes compressionData:bitmap length:5 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
        
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
    
    NSData * proofKeyData = @"1dfc5a0a3f2fab0370e1c2f76a502ff3066bc7731a02e309cf5f4b5a70a5441f".hexToData;
    NSData * proofValueData = @"0c40b8dd39bc511f7cbad02944e8762e69524104d2517ea28b3d4fddfc2155c5".hexToData;
    
    NSArray * hashes = @[@"bd4f2752a330b5509d3616d58f883d032246d95bcb00d4c63ac945f92c0a58aa".hexToData, @"464f80175948e41b03cb6143fcd06ee4712f865b1899dc82959f992ea986357b".hexToData, @"ac7379a00a7058a3973ac5b770da5b14227e56931208ecd9ea5fac4797d097a3".hexToData];
    NSData * bitmap = @"e0".hexToData;
    
    [DSSparseMerkleTree verifyCompressedNonInclusionWithRoot:root forKey:key withProofKeyData:proofKeyData withProofValueData:proofValueData againstProofHashes:hashes compressionData:bitmap length:3 completion:^(BOOL verified, NSError * _Nullable error) {
        XCTAssert(verified,@"This should be verified");
    } ];
}

@end
