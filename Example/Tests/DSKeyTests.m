//
//  DSKeyTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "dash_shared_core.h"
#import "DSChain.h"
#import "DSKeyManager.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"

@interface DSKeyTests : XCTestCase
@property (strong, nonatomic) DSChain *chain;
@end

@implementation DSKeyTests

- (void)setUp {
    [super setUp];
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testKey
- (void)testKeyWithPrivateKey {
    XCTAssertFalse([@"7s18Ypj1scza76SPf56Jm9zraxSrv58TgzmxwuDXoauvV84ud61" isValidDashPrivateKeyOnChain:self.chain],
        @"[NSString+Base58 isValidDashPrivateKey]");
    // uncompressed private key
    XCTAssertTrue([@"7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62" isValidDashPrivateKeyOnChain:self.chain],
        @"[NSString+Base58 isValidDashPrivateKey]");
    OpaqueKey *key = [DSKeyManager keyWithPrivateKeyString:@"7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62" ofKeyType:KeyKind_ECDSA forChainType:self.chain.chainType];
    NSLog(@"privKey:7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62 = %@", [DSKeyManager addressForKey:key forChainType:self.chain.chainType]);
    XCTAssertEqualObjects(@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", [DSKeyManager addressForKey:key forChainType:self.chain.chainType], @"[DSKey keyWithPrivateKey:]");
    processor_destroy_opaque_key(key);
    // compressed private key
    key = [DSKeyManager keyWithPrivateKeyString:@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6" ofKeyType:KeyKind_ECDSA forChainType:self.chain.chainType];
    NSLog(@"privKey:KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL = %@", [DSKeyManager addressForKey:key forChainType:self.chain.chainType]);
    XCTAssertEqualObjects(@"XbKPGyV1BpzzxNAggx6Q9a6o7GaBWTLhJS", [DSKeyManager addressForKey:key forChainType:self.chain.chainType], @"[DSKey keyWithPrivateKey:]");
    // compressed private key export
    NSLog(@"privKey = %@", [DSKeyManager serializedPrivateKey:key chainType:self.chain.chainType]);
    XCTAssertEqualObjects(@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6", [DSKeyManager serializedPrivateKey:key chainType:self.chain.chainType], @"[DSKey privateKey]");
}
//
//// MARK: - testKeyWithBIP38Key
//
#if !SKIP_BIP38
// implemented in rust
- (void)testKeyWithBIP38Key {
    
    // TODO: compressed/uncompressed BIP38Key tests
    NSString *privKey = [DSKeyManager ecdsaKeyWithBIP38Key:@"6PfV898iMrVs3d9gJSw5HTYyGhQRR5xRu5ji4GE6H5QdebT2YgK14Lu1E5" passphrase:@"TestingOneTwoThree" forChainType:self.chain.chainType];
    XCTAssertEqualObjects(@"7sEJGJRPeGoNBsW8tKAk4JH52xbxrktPfJcNxEx3uf622ZrGR5k", privKey, @"[DSKey keyWithBIP38Key:andPassphrase:]");
    // TODO: make rust binding for this
//    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree" onChain:self.chain],
//        @"6PRT3Wy4p7MZETE3n56KzyjyizMsE26WnMWpSeSoZawawEm7jaeCVa2wMu", // not EC multiplied (todo)
//        @"[DSKey BIP38KeyWithPassphrase:]");
}
#endif


// MARK: - testSign
- (void)testSign {
    // secret data / message / signature
    NSArray<NSArray *> *data = @[
        @[
            @"0000000000000000000000000000000000000000000000000000000000000001",
            @"Everything should be made as simple as possible, but not simpler.",
            @"3044022033a69cd2065432a30f3d1ce4eb0d59b8ab58c74f27c41a7fdb5696ad4e6108c902206f807982866f785d3f6418d24163ddae117b7db4d5fdf0071de069fa54342262",
        ],
        @[
            @"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140",
            @"Equations are more important to me, because politics is for the present, but an equation is something for eternity.",
            @"3044022054c4a33c6423d689378f160a7ff8b61330444abb58fb470f96ea16d99d4a2fed022007082304410efa6b2943111b6a4e0aaa7b7db55a07e9861d1fb3cb1f421044a5",
        ],
        @[
            @"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140",
            @"Not only is the Universe stranger than we think, it is stranger than we can think.",
            @"3045022100ff466a9f1b7b273e2f4c3ffe032eb2e814121ed18ef84665d0f515360dab3dd002206fc95f5132e5ecfdc8e5e6e616cc77151455d46ed48f5589b7db7771a332b283",
        ],
        @[
            @"0000000000000000000000000000000000000000000000000000000000000001",
            @"How wonderful that we have met with a paradox. Now we have some hope of making progress.",
            @"3045022100c0dafec8251f1d5010289d210232220b03202cba34ec11fec58b3e93a85b91d3022075afdc06b7d6322a590955bf264e7aaa155847f614d80078a90292fe205064d3",
        ],
        @[
            @"69ec59eaa1f4f2e36b639716b7c30ca86d9a5375c7b38d8918bd9c0ebc80ba64",
            @"Computer science is no more about computers than astronomy is about telescopes.",
            @"304402207186363571d65e084e7f02b0b77c3ec44fb1b257dee26274c38c928986fea45d02200de0b38e06807e46bda1f1e293f4f6323e854c86d58abdd00c46c16441085df6",
        ],
        @[
            @"00000000000000000000000000007246174ab1e92e9149c6e446fe194d072637",
            @"...if you aren't, at any given time, scandalized by code you wrote five or even three years ago, you're not learning anywhere near enough",
            @"3045022100fbfe5076a15860ba8ed00e75e9bd22e05d230f02a936b653eb55b61c99dda48702200e68880ebb0050fe4312b1b1eb0899e1b82da89baa5b895f612619edf34cbd37",
        ],
        @[
            @"000000000000000000000000000000000000000000056916d0f9b31dc9b637f3",
            @"The question of whether computers can think is like the question of whether submarines can swim.",
            @"3045022100cde1302d83f8dd835d89aef803c74a119f561fbaef3eb9129e45f30de86abbf9022006ce643f5049ee1f27890467b77a6a8e11ec4661cc38cd8badf90115fbd03cef",
        ],
    ];
    
    NSData *sig;
    UInt256 md;
    OpaqueKey *key;
    for (NSArray *triple in data) {
        key = [DSKeyManager keyWithPrivateKeyData:((NSString *)triple[0]).hexToData ofType:KeyKind_ECDSA];
        md = [(NSString *) triple[1] dataUsingEncoding:NSUTF8StringEncoding].SHA256;
        sig = [DSKeyManager NSDataFrom:key_ecdsa_sign(key->ecdsa, md.u8, 32)];
        XCTAssertEqualObjects(sig, ((NSString *)triple[2]).hexToData, @"[DSKey sign:]");
        XCTAssertTrue([DSKeyManager verifyMessageDigest:key digest:md signature:sig], @"[DSKey verify:signature:]");
        processor_destroy_opaque_key(key);
    }
}

// MARK: - testCompactSign
// implemented in rust
- (void)testCompactSign {
    NSData *sec = @"0000000000000000000000000000000000000000000000000000000000000001".hexToData;
    NSData *sig;
    UInt256 md;
    OpaqueKey *key, *reckey;

    key = key_create_ecdsa_from_secret(sec.bytes, sec.length, true);
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [DSKeyManager signMesasageDigest:key digest:md];
    reckey = key_ecdsa_recovered_from_compact_sig(sig.bytes, sig.length, md.u8);
    XCTAssertEqualObjects([DSKeyManager publicKeyData:key], [DSKeyManager publicKeyData:reckey]);
    processor_destroy_opaque_key(key);
    processor_destroy_opaque_key(reckey);
    
    key = key_create_ecdsa_from_secret(sec.bytes, sec.length, false);
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [DSKeyManager signMesasageDigest:key digest:md];
    reckey = key_ecdsa_recovered_from_compact_sig(sig.bytes, sig.length, md.u8);
    XCTAssertEqualObjects([DSKeyManager publicKeyData:key], [DSKeyManager publicKeyData:reckey]);
    processor_destroy_opaque_key(reckey);
    
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3kq9e842BzkMfbPSbhKVwGZgspDSkz4YfqjdBYQPWDzqd77gPgR1zq4XG7KtAL5DZTcfFFs2iph4urNyXeBkXsEYY".base58ToData;
    reckey = key_ecdsa_recovered_from_compact_sig(sig.bytes, sig.length, md.u8);
    XCTAssertEqualObjects(@"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData, [DSKeyManager publicKeyData:reckey]);
    processor_destroy_opaque_key(reckey);

    md = [@"i am a test signed string do de dah" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3qECEYmb6x4X22sH98Aer68SdfrLwtqvb5Ncv7EqKmzbxeYYJ1hU9irP6R5PeCctCPYo5KQiWFgoJ3H5MkuX18gHu".base58ToData;
    reckey = key_ecdsa_recovered_from_compact_sig(sig.bytes, sig.length, md.u8);
    XCTAssertEqualObjects(@"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData, [DSKeyManager publicKeyData:reckey]);
    processor_destroy_opaque_key(reckey);

    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3oHQhxq5eW8dnp7DquTCbA5tECoNx7ubyiubw4kiFm7wXJF916SZVykFzb8rB1K6dEu7mLspBWbBEJyYk79jAosVR".base58ToData;
    reckey = key_ecdsa_recovered_from_compact_sig(sig.bytes, sig.length, md.u8);
    XCTAssertEqualObjects(@"gpRv1sNA3XURB6QEtGrx6Q18DZ5cSgUSDQKX4yYypxpW".base58ToData, [DSKeyManager publicKeyData:reckey]);
    processor_destroy_opaque_key(reckey);
    processor_destroy_opaque_key(key);
}

// implemented in rust
- (void)testBLSVerify {
    uint8_t seed1[5] = {1, 2, 3, 4, 5};
    NSData *seedData1 = [NSData dataWithBytes:seed1 length:5];
    uint8_t message1[3] = {7, 8, 9};
    NSData *messageData1 = [NSData dataWithBytes:message1 length:3];
    OpaqueKey *wrapper = key_with_seed_data(seedData1.bytes, seedData1.length, KeyKind_BLS);
    NSData *publicKeyData = [DSKeyManager publicKeyData:wrapper];
    NSData *privateKeyData = [DSKeyManager privateKeyData:wrapper];
    XCTAssertEqualObjects(publicKeyData.hexString, @"02a8d2aaa6a5e2e08d4b8d406aaf0121a2fc2088ed12431e6b0663028da9ac5922c9ea91cde7dd74b7d795580acc7a61");
    XCTAssertEqualObjects(privateKeyData.hexString, @"022fb42c08c12de3a6af053880199806532e79515f94e83461612101f9412f9e");
    NSData *signature1 = [DSKeyManager NSDataFrom:key_bls_sign_data(wrapper->bls_legacy, messageData1.bytes, messageData1.length)];
    XCTAssertEqualObjects(signature1.hexString, @"023f5c750f402c69dab304e5042a7419722536a38d58ce46ba045be23e99d4f9ceeffbbc6796ebbdab6e9813c411c78f07167a3b76bef2262775a1e9f95ff1a80c5fa9fe8daa220d4d9da049a96e8932d5071aaf48fbff27a920bc4aa7511fd4");
    NSData *pkData = [DSKeyManager NSDataFrom:key_bls_public_key(wrapper->bls_legacy)];
    BOOL verified = key_bls_verify(pkData.bytes, true, [messageData1 SHA256_2].u8, signature1.bytes);
    processor_destroy_opaque_key(wrapper);
    XCTAssertTrue(verified, @"Testing BLS signature verification");
}

@end
