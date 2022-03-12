//
//  DSKeyTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSBLSKey.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "DSKey+BIP38.h"
#import "DSKey.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"

@interface DSKeyTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSKeyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

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

    DSECDSAKey *key = [DSECDSAKey keyWithPrivateKey:@"7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62" onChain:self.chain];

    NSLog(@"privKey:7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62 = %@", [key addressForChain:self.chain]);
    XCTAssertEqualObjects(@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", [key addressForChain:self.chain], @"[DSKey keyWithPrivateKey:]");

    // compressed private key
    key = [DSECDSAKey keyWithPrivateKey:@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6" onChain:self.chain];

    NSLog(@"privKey:KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL = %@", [key addressForChain:self.chain]);
    XCTAssertEqualObjects(@"XbKPGyV1BpzzxNAggx6Q9a6o7GaBWTLhJS", [key addressForChain:self.chain], @"[DSKey keyWithPrivateKey:]");

    // compressed private key export
    NSLog(@"privKey = %@", [key serializedPrivateKeyForChain:self.chain]);
    XCTAssertEqualObjects(@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6", [key serializedPrivateKeyForChain:self.chain],
        @"[DSKey privateKey]");
}

// MARK: - testKeyWithBIP38Key

#if !SKIP_BIP38
- (void)testKeyWithBIP38Key {
    DSECDSAKey *key;

    //to do compressed/uncompressed BIP38Key tests
    key = [DSECDSAKey keyWithBIP38Key:@"6PfV898iMrVs3d9gJSw5HTYyGhQRR5xRu5ji4GE6H5QdebT2YgK14Lu1E5"
                        andPassphrase:@"TestingOneTwoThree"
                              onChain:self.chain];
    NSLog(@"privKey = %@", [key serializedPrivateKeyForChain:self.chain]);
    XCTAssertEqualObjects(@"7sEJGJRPeGoNBsW8tKAk4JH52xbxrktPfJcNxEx3uf622ZrGR5k", [key serializedPrivateKeyForChain:self.chain],
        @"[DSKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree" onChain:self.chain],
        @"6PRT3Wy4p7MZETE3n56KzyjyizMsE26WnMWpSeSoZawawEm7jaeCVa2wMu", //not EC multiplied (todo)
        @"[DSKey BIP38KeyWithPassphrase:]");

    // incorrect password test
    key = [DSECDSAKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn" andPassphrase:@"foobar" onChain:self.chain];
    NSLog(@"privKey = %@", [key serializedPrivateKeyForChain:self.chain]);
    XCTAssertNil(key, @"[DSKey keyWithBIP38Key:andPassphrase:]");
}
#endif

// MARK: - testSign

- (void)testSign {
    NSData *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    DSECDSAKey *key = [DSECDSAKey keyWithSecret:sec compressed:YES];

    md = [@"Everything should be made as simple as possible, but not simpler."
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022033a69cd2065432a30f3d1ce4eb0d59b8ab58c74f27c41a7fdb5696ad4e6108c902206f80798286"
                                "6f785d3f6418d24163ddae117b7db4d5fdf0071de069fa54342262".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"Equations are more important to me, because politics is for the present, but an equation is something for "
           "eternity." dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022054c4a33c6423d689378f160a7ff8b61330444abb58fb470f96ea16d99d4a2fed02200708230441"
                                "0efa6b2943111b6a4e0aaa7b7db55a07e9861d1fb3cb1f421044a5".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"Not only is the Universe stranger than we think, it is stranger than we can think."
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100ff466a9f1b7b273e2f4c3ffe032eb2e814121ed18ef84665d0f515360dab3dd002206fc95f51"
                                "32e5ecfdc8e5e6e616cc77151455d46ed48f5589b7db7771a332b283".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"How wonderful that we have met with a paradox. Now we have some hope of making progress."
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100c0dafec8251f1d5010289d210232220b03202cba34ec11fec58b3e93a85b91d3022075afdc06"
                                "b7d6322a590955bf264e7aaa155847f614d80078a90292fe205064d3".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"69ec59eaa1f4f2e36b639716b7c30ca86d9a5375c7b38d8918bd9c0ebc80ba64".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"Computer science is no more about computers than astronomy is about telescopes."
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"304402207186363571d65e084e7f02b0b77c3ec44fb1b257dee26274c38c928986fea45d02200de0b38e06"
                                "807e46bda1f1e293f4f6323e854c86d58abdd00c46c16441085df6".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"00000000000000000000000000007246174ab1e92e9149c6e446fe194d072637".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"...if you aren't, at any given time, scandalized by code you wrote five or even three years ago, you're not"
           " learning anywhere near enough" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100fbfe5076a15860ba8ed00e75e9bd22e05d230f02a936b653eb55b61c99dda48702200e68880e"
                                "bb0050fe4312b1b1eb0899e1b82da89baa5b895f612619edf34cbd37".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"000000000000000000000000000000000000000000056916d0f9b31dc9b637f3".hexToData.bytes;
    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"The question of whether computers can think is like the question of whether submarines can swim."
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100cde1302d83f8dd835d89aef803c74a119f561fbaef3eb9129e45f30de86abbf9022006ce643f"
                                "5049ee1f27890467b77a6a8e11ec4661cc38cd8badf90115fbd03cef".hexToData,
        @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signatureData:sig], @"[DSKey verify:signature:]");
}

// MARK: - testCompactSign

- (void)testCompactSign {
    NSData *pubkey, *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    DSECDSAKey *key;

    key = [DSECDSAKey keyWithSecret:sec compressed:YES];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKeyData;

    XCTAssertEqualObjects(key.publicKeyData, pubkey);

    key = [DSECDSAKey keyWithSecret:sec compressed:NO];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKeyData;

    XCTAssertEqualObjects(key.publicKeyData, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3kq9e842BzkMfbPSbhKVwGZgspDSkz4YfqjdBYQPWDzqd77gPgR1zq4XG7KtAL5DZTcfFFs2iph4urNyXeBkXsEYY".base58ToData;
    key = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKeyData, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string do de dah" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3qECEYmb6x4X22sH98Aer68SdfrLwtqvb5Ncv7EqKmzbxeYYJ1hU9irP6R5PeCctCPYo5KQiWFgoJ3H5MkuX18gHu".base58ToData;
    key = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKeyData, pubkey);

    pubkey = @"gpRv1sNA3XURB6QEtGrx6Q18DZ5cSgUSDQKX4yYypxpW".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3oHQhxq5eW8dnp7DquTCbA5tECoNx7ubyiubw4kiFm7wXJF916SZVykFzb8rB1K6dEu7mLspBWbBEJyYk79jAosVR".base58ToData;
    key = [DSECDSAKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKeyData, pubkey);
}

// MARK: - test BLS Sign

//SECTION("Test vectors 1") {
//    uint8_t seed1[5] = {1, 2, 3, 4, 5};
//    uint8_t seed2[6] = {1, 2, 3, 4, 5, 6};
//    uint8_t message1[3] = {7, 8, 9};
//
//    PrivateKey sk1 = PrivateKey::FromSeed(seed1, sizeof(seed1));
//    PublicKey pk1 = sk1.GetPublicKey();
//    Signature sig1 = sk1.Sign(message1, sizeof(message1));
//
//    PrivateKey sk2 = PrivateKey::FromSeed(seed2, sizeof(seed2));
//    PublicKey pk2 = sk2.GetPublicKey();
//    Signature sig2 = sk2.Sign(message1, sizeof(message1));
//
//    uint8_t buf[Signature::SIGNATURE_SIZE];
//    uint8_t buf2[PrivateKey::PRIVATE_KEY_SIZE];
//
//    REQUIRE(pk1.GetFingerprint() == 0x26d53247);
//    REQUIRE(pk2.GetFingerprint() == 0x289bb56e);
//
//
//    sig1.Serialize(buf);
//    sk1.Serialize(buf2);
//
//    REQUIRE(Util::HexStr(buf, Signature::SIGNATURE_SIZE)
//            == "93eb2e1cb5efcfb31f2c08b235e8203a67265bc6a13d9f0ab77727293b74a357ff0459ac210dc851fcb8a60cb7d393a419915cfcf83908ddbeac32039aaa3e8fea82efcb3ba4f740f20c76df5e97109b57370ae32d9b70d256a98942e5806065");
//    REQUIRE(Util::HexStr(buf2, PrivateKey::PRIVATE_KEY_SIZE)
//            == "022fb42c08c12de3a6af053880199806532e79515f94e83461612101f9412f9e");
//
//    sig2.Serialize(buf);
//    REQUIRE(Util::HexStr(buf, Signature::SIGNATURE_SIZE)
//            == "975b5daa64b915be19b5ac6d47bc1c2fc832d2fb8ca3e95c4805d8216f95cf2bdbb36cc23645f52040e381550727db420b523b57d494959e0e8c0c6060c46cf173872897f14d43b2ac2aec52fc7b46c02c5699ff7a10beba24d3ced4e89c821e");
//
//    vector<Signature> sigs = {sig1, sig2};
//    Signature aggSig1 = Signature::AggregateSigs(sigs);
//
//    aggSig1.Serialize(buf);
//    REQUIRE(Util::HexStr(buf, Signature::SIGNATURE_SIZE)
//            == "0a638495c1403b25be391ed44c0ab013390026b5892c796a85ede46310ff7d0e0671f86ebe0e8f56bee80f28eb6d999c0a418c5fc52debac8fc338784cd32b76338d629dc2b4045a5833a357809795ef55ee3e9bee532edfc1d9c443bf5bc658");
//    REQUIRE(aggSig1.Verify());
//
//    uint8_t message2[3] = {1, 2, 3};
//    uint8_t message3[4] = {1, 2, 3, 4};
//    uint8_t message4[2] = {1, 2};
//    Signature sig3 = sk1.Sign(message2, sizeof(message2));
//    Signature sig4 = sk1.Sign(message3, sizeof(message3));
//    Signature sig5 = sk2.Sign(message4, sizeof(message4));
//    vector<Signature> sigs2 = {sig3, sig4, sig5};
//    Signature aggSig2 = Signature::AggregateSigs(sigs2);
//    REQUIRE(aggSig2.Verify());
//    aggSig2.Serialize(buf);
//    REQUIRE(Util::HexStr(buf, Signature::SIGNATURE_SIZE)
//            == "8b11daf73cd05f2fe27809b74a7b4c65b1bb79cc1066bdf839d96b97e073c1a635d2ec048e0801b4a208118fdbbb63a516bab8755cc8d850862eeaa099540cd83621ff9db97b4ada857ef54c50715486217bd2ecb4517e05ab49380c041e159b");
//}

- (void)testBLSSign {
    //In dash we use SHA256_2, however these test vectors from the BLS library use a single SHA256

    uint8_t seed1[5] = {1, 2, 3, 4, 5};
    NSData *seedData1 = [NSData dataWithBytes:seed1 length:5];
    uint8_t seed2[6] = {1, 2, 3, 4, 5, 6};
    NSData *seedData2 = [NSData dataWithBytes:seed2 length:6];
    uint8_t message1[3] = {7, 8, 9};
    uint8_t message2[3] = {1, 2, 3};
    uint8_t message3[4] = {1, 2, 3, 4};
    uint8_t message4[2] = {1, 2};
    NSData *messageData1 = [NSData dataWithBytes:message1 length:3];
    NSData *messageData2 = [NSData dataWithBytes:message2 length:3];
    NSData *messageData3 = [NSData dataWithBytes:message3 length:4];
    NSData *messageData4 = [NSData dataWithBytes:message4 length:2];
    DSBLSKey *keyPair1 = [DSBLSKey keyWithSeedData:seedData1];
    DSBLSKey *keyPair2 = [DSBLSKey keyWithSeedData:seedData2];

    uint32_t fingerprint1 = keyPair1.publicKeyFingerprint;
    XCTAssertEqual(fingerprint1, 0x26d53247, @"Testing BLS private child public key fingerprint");

    uint32_t fingerprint2 = keyPair2.publicKeyFingerprint;
    XCTAssertEqual(fingerprint2, 0x289bb56e, @"Testing BLS private child public key fingerprint");

    UInt768 signature1 = [keyPair1 signDataSingleSHA256:messageData1];

    XCTAssertEqualObjects([NSData dataWithUInt768:signature1].hexString, @"93eb2e1cb5efcfb31f2c08b235e8203a67265bc6a13d9f0ab77727293b74a357ff0459ac210dc851fcb8a60cb7d393a419915cfcf83908ddbeac32039aaa3e8fea82efcb3ba4f740f20c76df5e97109b57370ae32d9b70d256a98942e5806065", @"Testing BLS signing");

    XCTAssertEqualObjects([NSData dataWithUInt256:keyPair1.secretKey].hexString, @"022fb42c08c12de3a6af053880199806532e79515f94e83461612101f9412f9e", @"Testing BLS private key");

    UInt768 signature2 = [keyPair2 signDataSingleSHA256:messageData1];

    XCTAssertEqualObjects([NSData dataWithUInt768:signature2].hexString, @"975b5daa64b915be19b5ac6d47bc1c2fc832d2fb8ca3e95c4805d8216f95cf2bdbb36cc23645f52040e381550727db420b523b57d494959e0e8c0c6060c46cf173872897f14d43b2ac2aec52fc7b46c02c5699ff7a10beba24d3ced4e89c821e", @"Testing BLS signing");

//    UInt768 aggregateSignature1 = [DSBLSKey aggregateSignatures:@[[NSData dataWithUInt768:signature1], [NSData dataWithUInt768:signature2]] withPublicKeys:@[[DSBLSKey keyWithPublicKey:keyPair1.publicKey], [DSBLSKey keyWithPublicKey:keyPair2.publicKey]] withMessages:@[messageData1, messageData1]];
//
//    XCTAssertEqualObjects([NSData dataWithUInt768:aggregateSignature1].hexString, @"0a638495c1403b25be391ed44c0ab013390026b5892c796a85ede46310ff7d0e0671f86ebe0e8f56bee80f28eb6d999c0a418c5fc52debac8fc338784cd32b76338d629dc2b4045a5833a357809795ef55ee3e9bee532edfc1d9c443bf5bc658", @"Testing BLS simple signature aggregation");
//
//    UInt768 signature3 = [keyPair1 signDataSingleSHA256:messageData2];
//    UInt768 signature4 = [keyPair1 signDataSingleSHA256:messageData3];
//    UInt768 signature5 = [keyPair2 signDataSingleSHA256:messageData4];
//
//    UInt768 aggregateSignature2 = [DSBLSKey aggregateSignatures:@[[NSData dataWithUInt768:signature3], [NSData dataWithUInt768:signature4], [NSData dataWithUInt768:signature5]] withPublicKeys:@[[DSBLSKey keyWithPublicKey:keyPair1.publicKey], [DSBLSKey keyWithPublicKey:keyPair1.publicKey], [DSBLSKey keyWithPublicKey:keyPair2.publicKey]] withMessages:@[messageData2, messageData3, messageData4]];
//
//    XCTAssertEqualObjects([NSData dataWithUInt768:aggregateSignature2].hexString, @"8b11daf73cd05f2fe27809b74a7b4c65b1bb79cc1066bdf839d96b97e073c1a635d2ec048e0801b4a208118fdbbb63a516bab8755cc8d850862eeaa099540cd83621ff9db97b4ada857ef54c50715486217bd2ecb4517e05ab49380c041e159b", @"Testing BLS complex signature aggregation");
}

- (void)testBLSVerify {
    uint8_t seed1[5] = {1, 2, 3, 4, 5};
    NSData *seedData1 = [NSData dataWithBytes:seed1 length:5];
    uint8_t message1[3] = {7, 8, 9};
    NSData *messageData1 = [NSData dataWithBytes:message1 length:3];
    DSBLSKey *keyPair1 = [DSBLSKey keyWithSeedData:seedData1];

    UInt768 signature1 = [keyPair1 signData:messageData1];

    XCTAssertTrue([keyPair1 verify:[messageData1 SHA256_2] signature:signature1], @"Testing BLS signature verification");
}


@end
