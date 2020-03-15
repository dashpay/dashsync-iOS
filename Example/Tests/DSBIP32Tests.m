//
//  DSBIP32Tests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSChain.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSMutableData+Dash.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "NSData+Encryption.h"


@interface DSBIP32Tests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSBIP32Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testBIP32BLSSequence

//TEST_CASE("Key generation") {
//    SECTION("Should generate a keypair from a seed") {
//        uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
//
//
//        PrivateKey sk = PrivateKey::FromSeed(seed, sizeof(seed));
//        PublicKey pk = sk.GetPublicKey();
//        REQUIRE(core_get()->code == STS_OK);
//        REQUIRE(pk.GetFingerprint() == 0xddad59bb);
//    }
//    SECTION("Should calculate public key fingerprints") {
//        uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
//        ExtendedPrivateKey esk = ExtendedPrivateKey::FromSeed(
//                                                              seed, sizeof(seed));
//        uint32_t fingerprint = esk.GetPublicKey().GetFingerprint();
//        REQUIRE(fingerprint == 0xa4700b27);
//    }
//}
-(void)testBLSFingerprintFromSeed {
    uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData * seedData = [NSData dataWithBytes:seed length:10];
    DSBLSKey * keyPair = [DSBLSKey blsKeyWithPrivateKeyFromSeed:seedData onChain:[DSChain mainnet]];
    uint32_t fingerprint =keyPair.publicKeyFingerprint;
    XCTAssertEqual(fingerprint, 0xddad59bb,@"Testing BLS private child public key fingerprint");
    
    uint8_t seed2[] = {1, 50, 6, 244, 24, 199, 1, 25};
    NSData * seedData2 = [NSData dataWithBytes:seed2 length:8];
    DSBLSKey * keyPair2 = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seedData2 onChain:[DSChain mainnet]];
    uint32_t fingerprint2 = keyPair2.publicKeyFingerprint;
    XCTAssertEqual(fingerprint2, 0xa4700b27,@"Testing BLS extended private child public key fingerprint");
}

//SECTION("Test vector 3") {
//    uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
//    ExtendedPrivateKey esk = ExtendedPrivateKey::FromSeed(
//                                                          seed, sizeof(seed));
//    REQUIRE(esk.GetPublicKey().GetFingerprint() == 0xa4700b27);
//    uint8_t chainCode[32];
//    esk.GetChainCode().Serialize(chainCode);
//    REQUIRE(Util::HexStr(chainCode, 32) == "d8b12555b4cc5578951e4a7c80031e22019cc0dce168b3ed88115311b8feb1e3");
//
//    ExtendedPrivateKey esk77 = esk.PrivateChild(77 + (1 << 31));
//    esk77.GetChainCode().Serialize(chainCode);
//    REQUIRE(Util::HexStr(chainCode, 32) == "f2c8e4269bb3e54f8179a5c6976d92ca14c3260dd729981e9d15f53049fd698b");
//    REQUIRE(esk77.GetPrivateKey().GetPublicKey().GetFingerprint() == 0xa8063dcf);
//
//    REQUIRE(esk.PrivateChild(3)
//            .PrivateChild(17)
//            .GetPublicKey()
//            .GetFingerprint() == 0xff26a31f);
//    REQUIRE(esk.GetExtendedPublicKey()
//            .PublicChild(3)
//            .PublicChild(17)
//            .GetPublicKey()
//            .GetFingerprint() == 0xff26a31f);
//}
-(void)testBLSDerivation {
    uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
    NSData * seedData = [NSData dataWithBytes:seed length:8];
    DSBLSKey * keyPair = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seedData onChain:[DSChain mainnet]];
    
    UInt256 chainCode = keyPair.chainCode;
    XCTAssertEqualObjects([NSData dataWithUInt256:chainCode].hexString, @"d8b12555b4cc5578951e4a7c80031e22019cc0dce168b3ed88115311b8feb1e3",@"Testing BLS derivation chain code");
    
    UInt256 derivationPathIndexes1[] = {uint256_from_long(77)};
    BOOL hardened1[] = {YES};
    DSDerivationPath * derivationPath1 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes1 hardened:hardened1 length:1 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
    DSBLSKey * keyPair1 = [keyPair deriveToPath:derivationPath1.baseIndexPath];
    UInt256 chainCode1 = keyPair1.chainCode;
    XCTAssertEqualObjects([NSData dataWithUInt256:chainCode1].hexString, @"f2c8e4269bb3e54f8179a5c6976d92ca14c3260dd729981e9d15f53049fd698b",@"Testing BLS private child derivation returning chain code");
    XCTAssertEqual(keyPair1.publicKeyFingerprint, 0xa8063dcf,@"Testing BLS extended private child public key fingerprint");
    
    UInt256 derivationPathIndexes2[] = {uint256_from_long(3),uint256_from_long(17)};
    BOOL hardened2[] = {NO,NO};
    DSDerivationPath * derivationPath2 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes2 hardened:hardened2 length:2 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
    DSBLSKey * keyPair2 = [keyPair deriveToPath:derivationPath2.baseIndexPath];
    XCTAssertEqual(keyPair2.publicKeyFingerprint, 0xff26a31f,@"Testing BLS extended private child public key fingerprint");
    
    DSBLSKey * keyPair3 = [keyPair publicDeriveToPath:derivationPath2.baseIndexPath];
    XCTAssertEqual(keyPair3.publicKeyFingerprint, 0xff26a31f,@"Testing BLS extended private child public key fingerprint");
}

// MARK: - testBIP32Sequence

- (void)testBIP32SequencePrivateKeyFromString
{
    //from plastic upon blast park salon ticket timber disease tree camera economy what alpha birth category
    NSString *seedString = @"000102030405060708090a0b0c0d0e0f";
    
    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedString setCreationDate:[[NSDate date] timeIntervalSince1970] forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    DSAccount *account = [wallet accountWithNumber:0];
    DSFundsDerivationPath *derivationPath = account.bip32DerivationPath;
    
    NSData *seed = seedString.hexToData;
    NSString *pk = [derivationPath privateKeyStringAtIndex:2 | BIP32_HARD internal:YES fromSeed:seed];
    NSData *d = pk.base58checkToData;
    
    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/1/2' prv = %@", [NSString hexWithData:d]);
    
    
    XCTAssertEqualObjects(d.hexString, @"cccbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca01",
                          @"[DSDerivationPath privateKey:internal:fromSeed:]");
    
    // Test for correct zero padding of private keys, a nasty potential bug
    pk = [derivationPath privateKeyStringAtIndex:97 internal:NO fromSeed:seed];
    d = pk.base58checkToData;
    
    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/97 prv = %@", [NSString hexWithData:d]);
    
    XCTAssertEqualObjects(d.hexString, @"cc00136c1ad038f9a00871895322a487ed14f1cdc4d22ad351cfa1a0d235975dd701",
                          @"[DSBIP32Sequence privateKey:internal:fromSeed:]");
}

// TODO: some of tests below are disabled because extendedPublicKeyForAccount: method is not implemented yet

- (void)testBIP32SequenceMasterPublicKeyFromSeed
{
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];
    
    DSAccount *account = [wallet accountWithNumber:0];
    
    NSData *mpk = account.bip32DerivationPath.extendedPublicKey;

    NSLog(@"000102030405060708090a0b0c0d0e0f/0' pub+chain = %@", [NSString hexWithData:mpk]);

    XCTAssertEqualObjects(mpk, @"3442193e"
                          "47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141"
                          "035a784662a4a20a65bf6aab9ae98a6c068a81c52e4b032c0fb5400c706cfccc56".hexToData,
                          @"[DSBIP32Sequence extendedPublicKeyForAccount:0 fromSeed:]");
}

- (void)testBIP32SequencePublicKey
{
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];
    
    DSAccount *account = [wallet accountWithNumber:0];
    
    NSData *pub = [account.bip32DerivationPath publicKeyDataAtIndex:0 internal:NO];

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/0 pub = %@", [NSString hexWithData:pub]);

    XCTAssertEqualObjects(pub, @"027b6a7dd645507d775215a9035be06700e1ed8c541da9351b4bd14bd50ab61428".hexToData,
                          @"[DSBIP32Sequence publicKey:internal:masterPublicKey:]");
}

- (void)testBIP32SequenceSerializedPrivateMasterFromSeed
{
    NSString *seedString = @"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f";
    NSData *seed = seedString.hexToData;

    NSString *xprv = [DSDerivationPath serializedPrivateMasterFromSeed:seed forChain:self.chain];

    NSLog(@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f xpriv = %@", xprv);

    XCTAssertEqualObjects(xprv,
                          @"xprv9s21ZrQH143K27s8Yy6TJSKmKUxTBuXJr4RDTjJ5Jqq13d9v2VzYymSoM4VodDK7nrQHTruX6TuBsGuEVXoo91GwZnmBcTaqUhgK7HeysNv",
                          @"[DSBIP32Sequence serializedPrivateMasterFromSeed:forChain:]");
}

- (void)testBIP32SequenceSerializedMasterPublicKey
{
    //from Mnemonic stay issue box trade stock chaos raccoon candy obey wet refuse carbon silent guide crystal
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f".hexToData forChain:self.chain];
    
    DSAccount *account = [wallet accountWithNumber:0];
    
    NSString *xpub = [account.bip32DerivationPath serializedExtendedPublicKey];

    NSLog(@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f xpub = %@", xpub);

    XCTAssertEqualObjects(xpub,
                          @"xpub6949NHhpyXW7qCtj5eKxLG14JgbFdxUwRdmZ4M51t2Bcj95bCREEDmvdWhC6c31SbobAf5X86SLg76A5WirhTYFCG5F9wkeY6314q4ZtA68",
                          @"[DSBIP32Sequence serializedMasterPublicKey:depth:]");

    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    DSBIP39Mnemonic * mnemonic = [DSBIP39Mnemonic new];
    NSData * seed = [mnemonic deriveKeyFromPhrase:seedPhrase withPassphrase:nil];

    XCTAssertEqualObjects(seed.hexString,
                          @"467c2dd58bbd29427fb3c5467eee339021a87b21309eeabfe9459d31eeb6eba9b2a1213c12a173118c84fd49e8b4bf9282272d67bf7b7b394b088eab53b438bc",
                          @"[DSBIP39Mnemonic deriveKeyFromPhrase:withPassphrase:]");
    
    
    DSWallet *wallet2 = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSAccount *account2 = [wallet2 accountWithNumber:0];

    NSData * mpk = [account2.bip32DerivationPath extendedPublicKey];
    XCTAssertEqualObjects(mpk.hexString,
                          @"c93fa1867e984d7255df4736e7d7d6243026b9744e62374cbb54a0a47cc0fe0c334f876e02cdfeed62990ac98b6932e0080ce2155b4f5c7a8341271e9ee9c90cd87300009c",
                          @"[DSDerivationPath extendedPublicKey]");

    xpub = [account2.bip32DerivationPath serializedExtendedPublicKey];

    XCTAssertEqualObjects(xpub,
                          @"xpub69NHuRQrRn5GbT7j881uR64arreu3TFmmPAMnTeHdGd68BmAFxssxhzhmyvQoL3svMWTSbymV5FdHoypDDmaqV1C5pvnKbcse1vgrENbau7",
                          @"[DSDerivationPath serializedExtendedPublicKey]");
}

- (void)testBIP44SequenceSerializedMasterPublicKey
{
    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    DSWallet *wallet2 = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSAccount *account2 = [wallet2 accountWithNumber:0];
    
    NSData * mpk = [account2.bip44DerivationPath extendedPublicKey];
    XCTAssertEqualObjects(mpk.hexString,
                          @"4687e396a07188bd71458a0e90987f92b18a6451e99eb52f0060be450e0b4b3ce3e49f9f033914476cf503c7c2dcf5a0f90d3e943a84e507551bdf84891dd38c0817cca97a",
                          @"[DSDerivationPath extendedPublicKey]");
    
    NSString * xpub = [account2.bip44DerivationPath serializedExtendedPublicKey];
    
    XCTAssertEqualObjects(xpub,
                          @"xpub6CAqVZYbGiQCTyzzvvueEoBy8M74VWtPywf2F3zpwbS8AugDSSMSLcewpDaRQxVCxtL4kbTbWb1fzWg2R5933ECsxrEtKBA4gkJu8quduHs",
                          @"[DSDerivationPath serializedExtendedPublicKey]");

    NSData * deserializedMpk = [DSDerivationPath deserializedExtendedPublicKey:xpub onChain:self.chain];

    XCTAssertEqualObjects(mpk,
                          deserializedMpk,
                          @"[DSDerivationPath deserializedMasterPublicKey: onChain:]");
}

-(void)test31BitDerivation {
    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    DSECDSAKey * parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];
    
    NSData * parentPublicKey = parentSecret.publicKeyData;
    
    uint32_t derivation = 0;
    
    CKDpriv(&secret, &chain, derivation);
    
    NSData * publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;
    
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
    
    CKDpub(&pubKey, &chain2, 0);
    
    NSData * publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    
    XCTAssertEqualObjects(uint256_hex(chain),uint256_hex(chain2),@"the bip32 chains must match");
    
    XCTAssertEqualObjects(publicKey,publicKey2,@"the public keys must match");
    
}

-(void)test31BitCompatibilityModeDerivation {
    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    DSECDSAKey * parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];
    
    NSData * parentPublicKey = parentSecret.publicKeyData;
    
    UInt256 derivation = UINT256_ZERO;
    
    CKDpriv256(&secret, &chain, derivation,NO);
    
    NSData * publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;
    
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
    
    CKDpub256(&pubKey, &chain2, derivation,NO);
    
    NSData * publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    
    XCTAssertEqualObjects(uint256_hex(chain),uint256_hex(chain2),@"the bip32 chains must match");
    
    XCTAssertEqualObjects(publicKey,publicKey2,@"the public keys must match");
    
}

-(void)test256BitDerivation {
    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    DSECDSAKey * parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];
    
    NSData * parentPublicKey = parentSecret.publicKeyData;
    
    UInt256 derivation = ((UInt256){.u64 = {
        5,
        12,
        15,
        1337,
    }});
    
    CKDpriv256(&secret, &chain, derivation,NO);
    
    NSData * publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;
    
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
    
    CKDpub256(&pubKey, &chain2, derivation,NO);
    
    NSData * publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    
    XCTAssertEqualObjects(uint256_hex(chain),uint256_hex(chain2),@"the bip32 chains must match");
    
    XCTAssertEqualObjects(publicKey,publicKey2,@"the public keys must match");
    
    XCTAssertEqualObjects(uint256_data(derivation),@"05000000000000000c000000000000000f000000000000003905000000000000".hexToData,@"derivation must match the correct value");
    
    XCTAssertEqualObjects(publicKey,@"02909fb2c2cd18c8fb99277bc26ec606e381d27c2af6bd87e222304e3baf450bf7".hexToData,@"the public must match the correct value");
    
}

-(void)testDashpayDerivation {
    
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSAccount *account = [wallet accountWithNumber:0];
    
    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    
    //NSData * data = [account.masterContactsDerivationPath extendedPublicKey];
    
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    
    DSDerivationPath * masterContactsDerivationPath = [account masterContactsDerivationPath];
    
    DSIncomingFundsDerivationPath * incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:destinationUser2 sourceBlockchainIdentityUniqueId:sourceUser1 forAccountNumber:0 onChain:self.chain];
    
    incomingFundsDerivationPath.account = account;
    
    NSData * extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    
    NSData * extendedPublicKeyFromSeed = [incomingFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    
    XCTAssertEqualObjects(extendedPublicKeyFromMasterContactDerivationPath,extendedPublicKeyFromSeed,@"The extended public keys should be the same");
}


-(void)testBase64ExtendedPublicKeySize {
    NSString * seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0 forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    
    DSAccount *account = [wallet accountWithNumber:0];
    
    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    
    //NSData * data = [account.masterContactsDerivationPath extendedPublicKey];
    
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    
    DSDerivationPath * masterContactsDerivationPath = [account masterContactsDerivationPath];
    
    DSIncomingFundsDerivationPath * incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:destinationUser2 sourceBlockchainIdentityUniqueId:sourceUser1 forAccountNumber:0 onChain:self.chain];
    
    incomingFundsDerivationPath.account = account;
    
    NSData * extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    
    uint8_t bobSeed[10] = {10, 9, 8, 7, 6, 6, 7, 8, 9, 10};
    NSData *bobSeedData = [NSData dataWithBytes:bobSeed length:10];
    DSBLSKey *bobKeyPairBLS = [DSBLSKey blsKeyWithPrivateKeyFromSeed:bobSeedData onChain:[DSChain mainnet]];
    
    DSAuthenticationKeysDerivationPath * derivationPathBLS = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:wallet];
    DSKey * privateKeyBLS = [derivationPathBLS privateKeyAtIndex:0 fromSeed:seed];
    NSData * encryptedDataBLS = [extendedPublicKeyFromMasterContactDerivationPath encryptWithSecretKey:privateKeyBLS forPeerWithPublicKey:bobKeyPairBLS];
    
    NSString * base64DataBLS = encryptedDataBLS.base64String;
    XCTAssertEqual([base64DataBLS length], 128, @"The size of the base64 should be 128");
    
    UInt256 bobSecret = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;
    
    DSECDSAKey *bobKeyPairECDSA = [DSECDSAKey keyWithSecret:bobSecret compressed:YES];
    
    DSAuthenticationKeysDerivationPath * derivationPathECDSA = [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:wallet];
    DSKey * privateKeyECDSA = [derivationPathECDSA privateKeyAtIndex:0 fromSeed:seed];
    NSData * encryptedDataECDSA = [extendedPublicKeyFromMasterContactDerivationPath encryptWithSecretKey:privateKeyECDSA forPeerWithPublicKey:bobKeyPairECDSA];
    
    NSString * base64DataECDSA = encryptedDataECDSA.base64String;
    XCTAssertEqual([base64DataECDSA length], 128, @"The size of the base64 should be 128");
}

@end
