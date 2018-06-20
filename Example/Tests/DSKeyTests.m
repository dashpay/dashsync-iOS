//
//  DSKeyTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSString+Dash.h"
#import "DSKey.h"
#import "DSKey+BIP38.h"
#import "DSChain.h"
#import "NSData+Bitcoin.h"

@interface DSKeyTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSKeyTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testKey

- (void)testKeyWithPrivateKey
{
    XCTAssertFalse([@"7s18Ypj1scza76SPf56Jm9zraxSrv58TgzmxwuDXoauvV84ud61" isValidDashPrivateKeyOnChain:self.chain],
                   @"[NSString+Base58 isValidDashPrivateKey]");
    
    // uncompressed private key
    XCTAssertTrue([@"7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62" isValidDashPrivateKeyOnChain:self.chain],
                  @"[NSString+Base58 isValidDashPrivateKey]");
    
    DSKey *key = [DSKey keyWithPrivateKey:@"7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62" onChain:self.chain];
    
    NSLog(@"privKey:7r17Ypj1scza76SPf56Jm9zraxSrv58ThzmxwuDXoauvV84ud62 = %@", [key addressForChain:self.chain]);
    XCTAssertEqualObjects(@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", [key addressForChain:self.chain], @"[DSKey keyWithPrivateKey:]");
    
    // compressed private key
    key = [DSKey keyWithPrivateKey:@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6" onChain:self.chain];
    
    NSLog(@"privKey:KyvGbxRUoofdw3TNydWn2Z78dBHSy2odn1d3wXWN2o3SAtccFNJL = %@", [key addressForChain:self.chain]);
    XCTAssertEqualObjects(@"XbKPGyV1BpzzxNAggx6Q9a6o7GaBWTLhJS", [key addressForChain:self.chain], @"[DSKey keyWithPrivateKey:]");
    
    // compressed private key export
    NSLog(@"privKey = %@", [key privateKeyStringForChain:self.chain]);
    XCTAssertEqualObjects(@"XDHVuTeSrRs77u15134RPtiMrsj9KFDvsx1TwKUJxcgb4oiP6gA6", [key privateKeyStringForChain:self.chain],
                          @"[DSKey privateKey]");
}

// MARK: - testKeyWithBIP38Key

#if ! SKIP_BIP38
- (void)testKeyWithBIP38Key
{
    DSKey *key;

    //to do compressed/uncompressed BIP38Key tests
    key = [DSKey keyWithBIP38Key:@"6PfV898iMrVs3d9gJSw5HTYyGhQRR5xRu5ji4GE6H5QdebT2YgK14Lu1E5"
                   andPassphrase:@"TestingOneTwoThree"
           onChain:self.chain];
    NSLog(@"privKey = %@", [key privateKeyStringForChain:self.chain]);
    XCTAssertEqualObjects(@"7sEJGJRPeGoNBsW8tKAk4JH52xbxrktPfJcNxEx3uf622ZrGR5k", [key privateKeyStringForChain:self.chain],
                          @"[DSKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree" onChain:self.chain],
                          @"6PRT3Wy4p7MZETE3n56KzyjyizMsE26WnMWpSeSoZawawEm7jaeCVa2wMu",  //not EC multiplied (todo)
                          @"[DSKey BIP38KeyWithPassphrase:]");

    // incorrect password test
    key = [DSKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn" andPassphrase:@"foobar" onChain:self.chain];
    NSLog(@"privKey = %@", [key privateKeyStringForChain:self.chain]);
    XCTAssertNil(key, @"[DSKey keyWithBIP38Key:andPassphrase:]");
}
#endif

// MARK: - testSign

- (void)testSign
{
    NSData *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    DSKey *key = [DSKey keyWithSecret:sec compressed:YES];

    md = [@"Everything should be made as simple as possible, but not simpler."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022033a69cd2065432a30f3d1ce4eb0d59b8ab58c74f27c41a7fdb5696ad4e6108c902206f80798286"
                          "6f785d3f6418d24163ddae117b7db4d5fdf0071de069fa54342262".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"Equations are more important to me, because politics is for the present, but an equation is something for "
          "eternity." dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3044022054c4a33c6423d689378f160a7ff8b61330444abb58fb470f96ea16d99d4a2fed02200708230441"
                          "0efa6b2943111b6a4e0aaa7b7db55a07e9861d1fb3cb1f421044a5".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"Not only is the Universe stranger than we think, it is stranger than we can think."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100ff466a9f1b7b273e2f4c3ffe032eb2e814121ed18ef84665d0f515360dab3dd002206fc95f51"
                          "32e5ecfdc8e5e6e616cc77151455d46ed48f5589b7db7771a332b283".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"How wonderful that we have met with a paradox. Now we have some hope of making progress."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100c0dafec8251f1d5010289d210232220b03202cba34ec11fec58b3e93a85b91d3022075afdc06"
                          "b7d6322a590955bf264e7aaa155847f614d80078a90292fe205064d3".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"69ec59eaa1f4f2e36b639716b7c30ca86d9a5375c7b38d8918bd9c0ebc80ba64".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"Computer science is no more about computers than astronomy is about telescopes."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"304402207186363571d65e084e7f02b0b77c3ec44fb1b257dee26274c38c928986fea45d02200de0b38e06"
                          "807e46bda1f1e293f4f6323e854c86d58abdd00c46c16441085df6".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"00000000000000000000000000007246174ab1e92e9149c6e446fe194d072637".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"...if you aren't, at any given time, scandalized by code you wrote five or even three years ago, you're not"
          " learning anywhere near enough" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100fbfe5076a15860ba8ed00e75e9bd22e05d230f02a936b653eb55b61c99dda48702200e68880e"
                          "bb0050fe4312b1b1eb0899e1b82da89baa5b895f612619edf34cbd37".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");

    sec = *(UInt256 *)@"000000000000000000000000000000000000000000056916d0f9b31dc9b637f3".hexToData.bytes;
    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"The question of whether computers can think is like the question of whether submarines can swim."
          dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key sign:md];

    XCTAssertEqualObjects(sig, @"3045022100cde1302d83f8dd835d89aef803c74a119f561fbaef3eb9129e45f30de86abbf9022006ce643f"
                          "5049ee1f27890467b77a6a8e11ec4661cc38cd8badf90115fbd03cef".hexToData, @"[DSKey sign:]");
    XCTAssertTrue([key verify:md signature:sig], @"[DSKey verify:signature:]");
}

// MARK: - testCompactSign

- (void)testCompactSign
{
    NSData *pubkey, *sig;
    UInt256 md, sec = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    DSKey *key;

    key = [DSKey keyWithSecret:sec compressed:YES];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [DSKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKey;

    XCTAssertEqualObjects(key.publicKey, pubkey);

    key = [DSKey keyWithSecret:sec compressed:NO];
    md = [@"foo" dataUsingEncoding:NSUTF8StringEncoding].SHA256;
    sig = [key compactSign:md];
    pubkey = [DSKey keyRecoveredFromCompactSig:sig andMessageDigest:md].publicKey;

    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3kq9e842BzkMfbPSbhKVwGZgspDSkz4YfqjdBYQPWDzqd77gPgR1zq4XG7KtAL5DZTcfFFs2iph4urNyXeBkXsEYY".base58ToData;
    key = [DSKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"26wZYDdvpmCrYZeUcxgqd1KquN4o6wXwLomBW5SjnwUqG".base58ToData;
    md = [@"i am a test signed string do de dah" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3qECEYmb6x4X22sH98Aer68SdfrLwtqvb5Ncv7EqKmzbxeYYJ1hU9irP6R5PeCctCPYo5KQiWFgoJ3H5MkuX18gHu".base58ToData;
    key = [DSKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKey, pubkey);

    pubkey = @"gpRv1sNA3XURB6QEtGrx6Q18DZ5cSgUSDQKX4yYypxpW".base58ToData;
    md = [@"i am a test signed string" dataUsingEncoding:NSUTF8StringEncoding].SHA256_2;
    sig = @"3oHQhxq5eW8dnp7DquTCbA5tECoNx7ubyiubw4kiFm7wXJF916SZVykFzb8rB1K6dEu7mLspBWbBEJyYk79jAosVR".base58ToData;
    key = [DSKey keyRecoveredFromCompactSig:sig andMessageDigest:md];

    XCTAssertEqualObjects(key.publicKey, pubkey);
}

@end
