//
//  DSHashTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BigIntTypes.h"
#import "DSPriceManager.h"
#import "NSData+DSHash.h"
#import "NSString+Bitcoin.h"

@interface DSHashTests : XCTestCase

@end

@implementation DSHashTests

- (void)testBase64HashSize {
    UInt256 hash = [[@"aaaa" hexToData] SHA256_2];
    NSString *base64Data = uint256_base64(hash);
    XCTAssertEqual([base64Data length], 44, @"The size of the base64 should be 44");
}

- (void)testBlake3 {
    UInt256 md = @"whats the Elvish word for friend".hexToData.blake3;
    XCTAssertEqualObjects(@"af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262", uint256_hex(md),
        @"[NSData blake3]"); // verified by wikipedia
}


- (void)testBlake {
    UInt512 md = [@"020000002cc0081be5039a54b686d24d5d8747ee9770d9973ec1ace02e5c0500000000008d7139724b11c52995db4370284c998b9114154b120ad3486f1a360a1d4253d310d40e55b8f70a1be8e32300"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .blake512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"728309A76516B83D4E326DB3C6782722129C2835A25DE336DFFC16A0C10E4EBA654D65A86C7CC606B80BEFCC665CDD9B2D966D6BDCD2179F226F36925CC1AB8F".hexToData.bytes, md),
        @"[NSData blake512]"); // verified by wikipedia
}

- (void)testBmw {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .bmw512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"4146f08952d34cb498486dc0a063939d7f7be69ede232f379f93c08091ea6d13d6ebdb4e06fe24030f7ca9ac07b8f59e5cfadbb05bded3b9bb3a9abecea031cb".hexToData.bytes, md),
        @"[NSData bmw512]"); // verified by wikipedia
}

- (void)testGroestl {
    UInt512 md = [@"Groestl is an Austrian dish, usually made of leftover potatoes and pork, cut into slice."
        dataUsingEncoding:NSUTF8StringEncoding]
                     .groestl512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"eefdf4c9d6b6fd53390049388de8974525b406206114a8885016aa36619652535835a22ab0be05a81ea15f47ebaed9c236a79f354f699e45b6a7aebc9648695d".hexToData.bytes, md),
        @"[NSData groestl512]");
}

- (void)testSkein {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .skein512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"1db131ba5bc4b3ec9e381a752b3f0d53e8dd25e3d22aa8b9f17b570c3b5938833b91a54939ba873d28483e8b936f9584f06e80b1232a716a074377abd5c2b3f0".hexToData.bytes, md),
        @"[NSData skein512]");
}

- (void)testJh {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .jh512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"9999b3770256821e3a74c780ada66013df52378103addef0bceaac4be4f889d5ff93dc99d654310cc0063f15baa4ab168a2d8b6301104905619c334a92f521a1".hexToData.bytes, md),
        @"[NSData jh512]");
}

- (void)testKeccak {
    UInt512 md = [@""
        dataUsingEncoding:NSUTF8StringEncoding]
                     .keccak512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b435f091ef2769fb160cdab33d3670680e".hexToData.bytes, md),
        @"[NSData keccak512]"); // verified by wikipedia
}

- (void)testLuffa {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .luffa512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"7181d2550acde547eff499c1d533293f6bf4a0464dd9f2264ff5f35e17bb3238a6f7eb036645119a7575627f65fd74288c9581f6cf8a8df034547900aa86d634".hexToData.bytes, md),
        @"[NSData luffa512]");
}

- (void)testCubehash {
    UInt512 md = [@"Hello"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .cubehash512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"dcc0503aae279a3c8c95fa1181d37c418783204e2e3048a081392fd61bace883a1f7c4c96b16b4060c42104f1ce45a622f1a9abaeb994beb107fed53a78f588c".hexToData.bytes, md),
        @"[NSData cubehash512]");
}

- (void)testShavite {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .shavite512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"45f24351ef4f5b7477214efe97f8cef4d69007e94e1e5f397011c4fecd4517fe69c509ea6aa758a9055dd6d0864b885498f4fdab5cc0458dbf98e7069b2c52dd".hexToData.bytes, md),
        @"[NSData shavite512]");
}

- (void)testSimd {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .simd512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"e736a132375bd8aa02d00ea3ff3f0ef4cb8fbdd0b3cf3d619cf3e270896d2911105dc9bf46c395db98f17601529d24b8fa89a28e75f73da110d91a19c44f8975".hexToData.bytes, md),
        @"[NSData simd512]");
}

- (void)testEcho {
    UInt512 md = [@"DASH"
        dataUsingEncoding:NSUTF8StringEncoding]
                     .echo512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"42a2ee2bb582f59d1be01e4a24ed31041aa1898a3c6c2efe6956e5c6b9eb33d4a9f390f6eccdb7c757d4cb6ad3d3aed302d97740fdf78f569f599ab8cd71ff49".hexToData.bytes, md),
        @"[NSData echo512]");
}


- (void)testX11 {
    NSString *x11 = @"020000002cc0081be5039a54b686d24d5d8747ee9770d9973ec1ace02e5c0500000000008d7139724b11c52995db4370284c998b9114154b120ad3486f1a360a1d4253d310d40e55b8f70a1be8e32300";
    NSData *x11Data = [NSData dataFromHexString:x11];
    UInt256 md = x11Data.x11;
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"f29c0f286fd8071669286c6987eb941181134ff5f3978bf89f34070000000000".hexToData.bytes, md),
        @"[NSData x11]");
}

// MARK: - testBase58

- (void)testBase58 {
    // test bad input
    NSString *s = [NSString base58WithData:[BTC @"#&$@*^(*#!^" base58ToData]];

    XCTAssertTrue(s.length == 0, @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"" base58ToData]];
    XCTAssertEqualObjects(@"", s, @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz" base58ToData]];
    XCTAssertEqualObjects(@"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", s,
        @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"1111111111111111111111111111111111111111111111111111111111111111111" base58ToData]];
    XCTAssertEqualObjects(@"1111111111111111111111111111111111111111111111111111111111111111111", s,
        @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"111111111111111111111111111111111111111111111111111111111111111111z" base58ToData]];
    XCTAssertEqualObjects(@"111111111111111111111111111111111111111111111111111111111111111111z", s,
        @"[NSString base58WithData:]");

    s = [NSString base58WithData:[@"z" base58ToData]];
    XCTAssertEqualObjects(@"z", s, @"[NSString base58WithData:]");

    s = [NSString base58checkWithData:nil];
    XCTAssertTrue(s == nil, @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"".hexToData];
    XCTAssertEqualObjects([NSData data], [s base58checkToData], @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"000000000000000000000000000000000000000000".hexToData];
    XCTAssertEqualObjects(@"000000000000000000000000000000000000000000".hexToData, [s base58checkToData],
        @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"000000000000000000000000000000000000000001".hexToData];
    XCTAssertEqualObjects(@"000000000000000000000000000000000000000001".hexToData, [s base58checkToData],
        @"[NSString base58checkWithData:]");

    s = [NSString base58checkWithData:@"05FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".hexToData];
    XCTAssertEqualObjects(@"05FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".hexToData, [s base58checkToData],
        @"[NSString base58checkWithData:]");
    
    NSData *keyIdVotingData = @"yhedxEwiZ162jKCd3WpvWgWWocDiciJuKk".base58ToData;
    
    UInt160 keyIdVoting = keyIdVotingData.UInt160;
    s = uint160_base58(keyIdVoting);
    NSData *d = uint160_data(keyIdVoting);
//    s = [NSString base58WithData:[NSData dataWithUInt160:keyIdVoting]];
    NSLog(@"keyIdVotingData: %@", keyIdVotingData.base58String);
    NSLog(@"keyIdVotingData: %@", d.base58String);
    NSLog(@"keyIdVoting: %@", s);
    XCTAssertEqualObjects(keyIdVotingData.base58String, @"yhedxEwiZ162jKCd3WpvWgWWocDiciJuKk");
    XCTAssertEqualObjects(s, @"yhedxEwiZ162jKCd3WpvWgWWocDiciJuKk");
    
}

// MARK: - textSHA1

- (void)testSHA1 {
    UInt160 md = [@"Free online SHA1 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA1;

    XCTAssertTrue(uint160_eq(*(UInt160 *)@"6fc2e25172cb15193cb1c6d48f607d42c1d2a215".hexToData.bytes, md),
        @"[NSData SHA1]");

    md = [@"this is some text to test the sha1 implementation with more than 64bytes of data since it's internal "
           "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"085194658a9235b2951a83d1b826b987e9385aa3".hexToData.bytes, md),
        @"[NSData SHA1]");

    md = [@"123456789012345678901234567890123456789012345678901234567890"
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"245be30091fd392fe191f4bfcec22dcb30a03ae6".hexToData.bytes, md),
        @"[NSData SHA1]");

    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA1; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"c71490fc24aa3d19e11282da77032dd9cdb33103".hexToData.bytes, md),
        @"[NSData SHA1]");

    md = [NSData data].SHA1; // empty
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"da39a3ee5e6b4b0d3255bfef95601890afd80709".hexToData.bytes, md),
        @"[NSData SHA1]");

    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA1;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"86f7e437faa5a7fce15d1ddcb9eaeaea377667b8".hexToData.bytes, md),
        @"[NSData SHA1]");
}

// MARK: - textSHA256

- (void)testSHA256 {
    UInt256 md = [@"Free online SHA256 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA256;

    XCTAssertTrue(uint256_eq(*(UInt256 *)@"43fd9deb93f6e14d41826604514e3d7873a549ac87aebebf3d1c10ad6eb057d0".hexToData.bytes, md),
        @"[NSData SHA256]");

    md = [@"this is some text to test the sha256 implementation with more than 64bytes of data since it's internal "
           "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"40fd0933df2e7747f19f7d39cd30e1cb89810a7e470638a5f623669f3de9edd4".hexToData.bytes, md),
        @"[NSData SHA256]");

    md = [@"123456789012345678901234567890123456789012345678901234567890"
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"decc538c077786966ac863b5532c4027b8587ff40f6e3103379af62b44eae44d".hexToData.bytes, md),
        @"[NSData SHA256]");

    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
        dataUsingEncoding:NSUTF8StringEncoding]
             .SHA256; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"676491965ed3ec50cb7a63ee96315480a95c54426b0b72bca8a0d4ad1285ad55".hexToData.bytes, md),
        @"[NSData SHA256]");

    md = [NSData data].SHA256; // empty
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".hexToData.bytes, md),
        @"[NSData SHA256]");

    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    XCTAssertTrue(uint256_eq(*(UInt256 *)@"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb".hexToData.bytes, md),
        @"[NSData SHA256]");
}

// MARK: - textSHA512

- (void)testSHA512 {
    UInt512 md = [@"Free online SHA512 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].SHA512;

    XCTAssertTrue(uint512_eq(*(UInt512 *)@"04f1154135eecbe42e9adc8e1d532f9c607a8447b786377db8447d11a5b2232cdd419b863922"
                                          "4f787a51d110f72591f96451a1bb511c4a829ed0a2ec891321f3".hexToData.bytes,
                      md),
        @"[NSData SHA512]");

    md = [@"this is some text to test the sha512 implementation with more than 128bytes of data since it's internal "
           "digest buffer is 128bytes in size" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"9bd2dc7b05fbbe9934cb3289b6e06b8ca9fd7a55e6de5db7e1e4eeddc6629b575307367cd018"
                                          "3a4461d7eb2dfc6a27e41e8b70f6598ebcc7710911d4fb16a390".hexToData.bytes,
                      md),
        @"[NSData SHA512]");

    md = [@"12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567"
           "8901234567890" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"0d9a7df5b6a6ad20da519effda888a7344b6c0c7adcc8e2d504b4af27aaaacd4e7111c713f71"
                                          "769539629463cb58c86136c521b0414a3c0edf7dc6349c6edaf3".hexToData.bytes,
                      md),
        @"[NSData SHA512]");

    md = [@"12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567"
           "890123456789012345678" dataUsingEncoding:NSUTF8StringEncoding]
             .SHA512; // exactly 128bytes (internal buf size)
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"222b2f64c285e66996769b5a03ef863cfd3b63ddb0727788291695e8fb84572e4bfe5a80674a"
                                          "41fd72eeb48592c9c79f44ae992c76ed1b0d55a670a83fc99ec6".hexToData.bytes,
                      md),
        @"[NSData SHA512]");

    md = [NSData data].SHA512; // empty
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85"
                                          "f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e".hexToData.bytes,
                      md),
        @"[NSData SHA512]");

    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].SHA512;
    XCTAssertTrue(uint512_eq(*(UInt512 *)@"1f40fc92da241694750979ee6cf582f2d5d7d28e18335de05abc54d0560e0f5302860c652bf0"
                                          "8d560252aa5e74210546f369fbbbce8c12cfc7957b2652fe9a75".hexToData.bytes,
                      md),
        @"[NSData SHA512]");
}

// MARK: - testRMD160

- (void)testRMD160 {
    UInt160 md = [@"Free online RIPEMD160 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].RMD160;

    XCTAssertTrue(uint160_eq(*(UInt160 *)@"9501a56fb829132b8748f0ccc491f0ecbc7f945b".hexToData.bytes, md),
        @"[NSData RMD160]");

    md = [@"this is some text to test the ripemd160 implementation with more than 64bytes of data since it's internal "
           "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding]
             .RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"4402eff42157106a5d92e4d946185856fbc50e09".hexToData.bytes, md),
        @"[NSData RMD160]");

    md = [@"123456789012345678901234567890123456789012345678901234567890"
        dataUsingEncoding:NSUTF8StringEncoding]
             .RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"00263b999714e756fa5d02814b842a2634dd31ac".hexToData.bytes, md),
        @"[NSData RMD160]");

    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
        dataUsingEncoding:NSUTF8StringEncoding]
             .RMD160; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"fa8c1a78eb763bb97d5ea14ce9303d1ce2f33454".hexToData.bytes, md),
        @"[NSData RMD160]");

    md = [NSData data].RMD160; // empty
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"9c1185a5c5e9fc54612808977ee8f548b2258d31".hexToData.bytes, md),
        @"[NSData RMD160]");

    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].RMD160;
    XCTAssertTrue(uint160_eq(*(UInt160 *)@"0bdc9d2d256b3ee9daae347be6f4dc835a467ffe".hexToData.bytes, md),
        @"[NSData RMD160]");
}

// MARK: - testMD5

- (void)testMD5 {
    UInt128 md = [@"Free online MD5 Calculator, type text here..." dataUsingEncoding:NSUTF8StringEncoding].MD5;

    XCTAssertTrue(uint128_eq(*(UInt128 *)@"0b3b20eaf1696462f50d1a3bbdd30cef".hexToData.bytes, md), @"[NSData MD5]");

    md = [@"this is some text to test the md5 implementation with more than 64bytes of data since it's internal "
           "digest buffer is 64bytes in size" dataUsingEncoding:NSUTF8StringEncoding]
             .MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"56a161f24150c62d7857b7f354927ebe".hexToData.bytes, md), @"[NSData MD5]");

    md = [@"123456789012345678901234567890123456789012345678901234567890"
        dataUsingEncoding:NSUTF8StringEncoding]
             .MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"c5b549377c826cc3712418b064fc417e".hexToData.bytes, md), @"[NSData MD5]");

    md = [@"1234567890123456789012345678901234567890123456789012345678901234"
        dataUsingEncoding:NSUTF8StringEncoding]
             .MD5; // a message exactly 64bytes long (internal buffer size)
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"eb6c4179c0a7c82cc2828c1e6338e165".hexToData.bytes, md), @"[NSData MD5]");

    md = [NSData data].MD5; // empty
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"d41d8cd98f00b204e9800998ecf8427e".hexToData.bytes, md), @"[NSData MD5]");

    md = [@"a" dataUsingEncoding:NSUTF8StringEncoding].MD5;
    XCTAssertTrue(uint128_eq(*(UInt128 *)@"0cc175b9c0f1b6a831c399e269772661".hexToData.bytes, md), @"[NSData MD5]");
}

@end
