//
//  DSBIP32Tests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSBLSKey.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSECDSAKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet.h"
#import "NSData+Encryption.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"


@interface DSBIP32Tests : XCTestCase

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic) DSWallet *wallet;
@property (strong, nonatomic) NSData *seed;

@end

@implementation DSBIP32Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // the chain to test on
    self.chain = [DSChain mainnet];
    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    self.seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    self.wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                         setCreationDate:0
                                                forChain:self.chain
                                         storeSeedPhrase:NO
                                             isTransient:YES];
}

// MARK: - testBIP32BLSSequence

// TEST_CASE("Key generation") {
//     SECTION("Should generate a keypair from a seed") {
//         uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
//
//
//         PrivateKey sk = PrivateKey::FromSeed(seed, sizeof(seed));
//         PublicKey pk = sk.GetPublicKey();
//         REQUIRE(core_get()->code == STS_OK);
//         REQUIRE(pk.GetFingerprint() == 0xddad59bb);
//     }
//     SECTION("Should calculate public key fingerprints") {
//         uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
//         ExtendedPrivateKey esk = ExtendedPrivateKey::FromSeed(
//                                                               seed, sizeof(seed));
//         uint32_t fingerprint = esk.GetPublicKey().GetFingerprint();
//         REQUIRE(fingerprint == 0xa4700b27);
//     }
// }
- (void)testBLSFingerprintFromSeed {
    uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    NSData *seedData = [NSData dataWithBytes:seed length:10];
    DSBLSKey *keyPair = [DSBLSKey keyWithSeedData:seedData];
    uint32_t fingerprint = keyPair.publicKeyFingerprint;
    XCTAssertEqual(fingerprint, 0xddad59bb, @"Testing BLS private child public key fingerprint");

    uint8_t seed2[] = {1, 50, 6, 244, 24, 199, 1, 25};
    NSData *seedData2 = [NSData dataWithBytes:seed2 length:8];
    DSBLSKey *keyPair2 = [DSBLSKey extendedPrivateKeyWithSeedData:seedData2];
    uint32_t fingerprint2 = keyPair2.publicKeyFingerprint;
    XCTAssertEqual(fingerprint2, 0xa4700b27, @"Testing BLS extended private child public key fingerprint");
}

// SECTION("Test vector 3") {
//     uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
//     ExtendedPrivateKey esk = ExtendedPrivateKey::FromSeed(
//                                                           seed, sizeof(seed));
//     REQUIRE(esk.GetPublicKey().GetFingerprint() == 0xa4700b27);
//     uint8_t chainCode[32];
//     esk.GetChainCode().Serialize(chainCode);
//     REQUIRE(Util::HexStr(chainCode, 32) == "d8b12555b4cc5578951e4a7c80031e22019cc0dce168b3ed88115311b8feb1e3");
//
//     ExtendedPrivateKey esk77 = esk.PrivateChild(77 + (1 << 31));
//     esk77.GetChainCode().Serialize(chainCode);
//     REQUIRE(Util::HexStr(chainCode, 32) == "f2c8e4269bb3e54f8179a5c6976d92ca14c3260dd729981e9d15f53049fd698b");
//     REQUIRE(esk77.GetPrivateKey().GetPublicKey().GetFingerprint() == 0xa8063dcf);
//
//     REQUIRE(esk.PrivateChild(3)
//             .PrivateChild(17)
//             .GetPublicKey()
//             .GetFingerprint() == 0xff26a31f);
//     REQUIRE(esk.GetExtendedPublicKey()
//             .PublicChild(3)
//             .PublicChild(17)
//             .GetPublicKey()
//             .GetFingerprint() == 0xff26a31f);
// }
- (void)testBLSDerivation {
    uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
    NSData *seedData = [NSData dataWithBytes:seed length:8];
    DSBLSKey *keyPair = [DSBLSKey extendedPrivateKeyWithSeedData:seedData];

    UInt256 chainCode = keyPair.chainCode;
    XCTAssertEqualObjects([NSData dataWithUInt256:chainCode].hexString, @"d8b12555b4cc5578951e4a7c80031e22019cc0dce168b3ed88115311b8feb1e3", @"Testing BLS derivation chain code");

    UInt256 derivationPathIndexes1[] = {uint256_from_long(77)};
    BOOL hardened1[] = {YES};
    DSDerivationPath *derivationPath1 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes1 hardened:hardened1 length:1 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
    DSBLSKey *keyPair1 = [keyPair privateDeriveToPath:derivationPath1.baseIndexPath];
    UInt256 chainCode1 = keyPair1.chainCode;
    XCTAssertEqualObjects([NSData dataWithUInt256:chainCode1].hexString, @"f2c8e4269bb3e54f8179a5c6976d92ca14c3260dd729981e9d15f53049fd698b", @"Testing BLS private child derivation returning chain code");
    XCTAssertEqual(keyPair1.publicKeyFingerprint, 0xa8063dcf, @"Testing BLS extended private child public key fingerprint");

    UInt256 derivationPathIndexes2[] = {uint256_from_long(3), uint256_from_long(17)};
    BOOL hardened2[] = {NO, NO};
    DSDerivationPath *derivationPath2 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes2 hardened:hardened2 length:2 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
    DSBLSKey *keyPair2 = [keyPair privateDeriveToPath:derivationPath2.baseIndexPath];
    XCTAssertEqual(keyPair2.publicKeyFingerprint, 0xff26a31f, @"Testing BLS extended private child public key fingerprint");

    DSBLSKey *keyPair3 = [keyPair publicDeriveToPath:derivationPath2.baseIndexPath];
    XCTAssertEqual(keyPair3.publicKeyFingerprint, 0xff26a31f, @"Testing BLS extended private child public key fingerprint");
}

// MARK: - testBIP32Sequence

- (void)testBIP32SequencePrivateKeyFromString {
    // from plastic upon blast park salon ticket timber disease tree camera economy what alpha birth category
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

- (void)testBIP32SerializationsBasic {
    NSData *seedData = @"000102030405060708090a0b0c0d0e0f".hexToData;

    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:seedData forChain:self.chain];


    //--------------------------------------------------------------------------------------------------//
    // m //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexesRoot[] = {};
        BOOL hardenedRoot[] = {};

        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        rootDerivationPath.wallet = wallet;

        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [rootDerivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [rootDerivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0' //
    //--------------------------------------------------------------------------------------------------//

    {
        DSAccount *account = [wallet accountWithNumber:0];
        DSFundsDerivationPath *derivationPath = account.bip32DerivationPath;

        NSString *serializedBip32ExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedBip32ExtendedPublicKey, @"xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw",
            @"[DSDerivationPath serializedExtendedPublicKey:]");

        NSString *serializedBip32ExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedBip32ExtendedPrivateKey, @"xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed:]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1)};
        BOOL hardened[] = {YES, NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:2 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2)};
        BOOL hardened[] = {YES, NO, YES};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:3 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2'/2 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2), uint256_from_long(2)};
        BOOL hardened[] = {YES, NO, YES, NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:4 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2'/2/1000000000 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2), uint256_from_long(2), uint256_from_long(1000000000)};
        BOOL hardened[] = {YES, NO, YES, NO, NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:5 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }
}

- (void)testBIP32SerializationsAdvanced {
    NSData *seedData = @"fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542".hexToData;

    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:seedData forChain:self.chain];

    //--------------------------------------------------------------------------------------------------//
    // m //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexesRoot[] = {};
        BOOL hardenedRoot[] = {};

        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        rootDerivationPath.wallet = wallet;

        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [rootDerivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [rootDerivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0)};
        BOOL hardened[] = {NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:1 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647)};
        BOOL hardened[] = {NO, YES};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:2 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1)};
        BOOL hardened[] = {NO, YES, NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:3 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1/2147483646' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1), uint256_from_long(2147483646)};
        BOOL hardened[] = {NO, YES, NO, YES};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:4 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1/2147483646'/2 //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1), uint256_from_long(2147483646), uint256_from_long(2)};
        BOOL hardened[] = {NO, YES, NO, YES, NO};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:5 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }
}

- (void)testBIP32SerializationsLeadingZeros {
    NSData *seedData = @"4b381541583be4423346c643850da4b320e46a87ae3d2a4e6da11eba819cd4acba45d239319ac14f863b8d5ab5a0d0c64d2e8a1e7d1457df2e5a3c51c73235be".hexToData;

    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:seedData forChain:self.chain];

    //--------------------------------------------------------------------------------------------------//
    // m //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexesRoot[] = {};
        BOOL hardenedRoot[] = {};

        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        rootDerivationPath.wallet = wallet;

        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [rootDerivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [rootDerivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0)};
        BOOL hardened[] = {YES};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:1 type:DSDerivationPathType_Unknown signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [derivationPath serializedExtendedPublicKey];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [derivationPath serializedExtendedPrivateKeyFromSeed:seedData];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9uPDJpEQgRQfDcW7BkF7eTya6RPxXeJCqCJGHuCJ4GiRVLzkTXBAJMu2qaMWPrS7AANYqdq6vcBcBUdJCVVFceUvJFjaPdGZ2y9WACViL4L",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }
}

- (void)testBIP32SequenceMasterPublicKeyFromSeed {
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];

    DSAccount *account = [wallet accountWithNumber:0];

    NSData *mpk = account.bip32DerivationPath.extendedPublicKeyData;

    NSLog(@"000102030405060708090a0b0c0d0e0f/0' pub+chain = %@", [NSString hexWithData:mpk]);

    XCTAssertEqualObjects(mpk, @"3442193e"
                                "47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141"
                                "035a784662a4a20a65bf6aab9ae98a6c068a81c52e4b032c0fb5400c706cfccc56".hexToData,
        @"[DSBIP32Sequence extendedPublicKeyForAccount:0 fromSeed:]");
}

- (void)testBIP32SequencePublicKey {
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];

    DSAccount *account = [wallet accountWithNumber:0];

    NSData *pub = [account.bip32DerivationPath publicKeyDataAtIndex:0 internal:NO];

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/0 pub = %@", [NSString hexWithData:pub]);

    XCTAssertEqualObjects(pub, @"027b6a7dd645507d775215a9035be06700e1ed8c541da9351b4bd14bd50ab61428".hexToData,
        @"[DSBIP32Sequence publicKey:internal:masterPublicKey:]");
}

- (void)testBIP32SequenceSerializedPrivateMasterFromSeed {
    NSString *seedString = @"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f";
    NSData *seed = seedString.hexToData;

    NSString *xprv = [DSECDSAKey serializedPrivateMasterFromSeedData:seed forChain:self.chain];

    NSLog(@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f xpriv = %@", xprv);

    XCTAssertEqualObjects(xprv,
        @"xprv9s21ZrQH143K27s8Yy6TJSKmKUxTBuXJr4RDTjJ5Jqq13d9v2VzYymSoM4VodDK7nrQHTruX6TuBsGuEVXoo91GwZnmBcTaqUhgK7HeysNv",
        @"[DSBIP32Sequence serializedPrivateMasterFromSeedData:forChain:]");
}

- (void)testBIP32SequenceSerializedMasterPublicKey {
    // from Mnemonic stay issue box trade stock chaos raccoon candy obey wet refuse carbon silent guide crystal
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f".hexToData forChain:self.chain];

    DSAccount *account = [wallet accountWithNumber:0];

    NSString *xpub = [account.bip32DerivationPath serializedExtendedPublicKey];

    NSLog(@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f xpub = %@", xpub);

    XCTAssertEqualObjects(xpub,
        @"xpub6949NHhpyXW7qCtj5eKxLG14JgbFdxUwRdmZ4M51t2Bcj95bCREEDmvdWhC6c31SbobAf5X86SLg76A5WirhTYFCG5F9wkeY6314q4ZtA68",
        @"[DSBIP32Sequence serializedMasterPublicKey:depth:]");


    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    DSBIP39Mnemonic *mnemonic = [DSBIP39Mnemonic new];
    NSData *seed = [mnemonic deriveKeyFromPhrase:seedPhrase withPassphrase:nil];

    XCTAssertEqualObjects(seed.hexString,
        @"467c2dd58bbd29427fb3c5467eee339021a87b21309eeabfe9459d31eeb6eba9b2a1213c12a173118c84fd49e8b4bf9282272d67bf7b7b394b088eab53b438bc",
        @"[DSBIP39Mnemonic deriveKeyFromPhrase:withPassphrase:]");


    DSWallet *wallet2 = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                               setCreationDate:0
                                                      forChain:self.chain
                                               storeSeedPhrase:NO
                                                   isTransient:YES];

    DSAccount *account2 = [wallet2 accountWithNumber:0];

    NSData *mpk = [account2.bip32DerivationPath extendedPublicKeyData];
    XCTAssertEqualObjects(mpk.hexString,
        @"c93fa1867e984d7255df4736e7d7d6243026b9744e62374cbb54a0a47cc0fe0c334f876e02cdfeed62990ac98b6932e0080ce2155b4f5c7a8341271e9ee9c90cd87300009c",
        @"[DSDerivationPath extendedPublicKey]");

    xpub = [account2.bip32DerivationPath serializedExtendedPublicKey];

    XCTAssertEqualObjects(xpub,
        @"xpub69NHuRQrRn5GbT7j881uR64arreu3TFmmPAMnTeHdGd68BmAFxssxhzhmyvQoL3svMWTSbymV5FdHoypDDmaqV1C5pvnKbcse1vgrENbau7",
        @"[DSDerivationPath serializedExtendedPublicKey]");
}

- (void)testBIP44SequenceSerializedMasterPublicKey {
    DSAccount *account2 = [self.wallet accountWithNumber:0];

    NSData *mpk = [account2.bip44DerivationPath extendedPublicKeyData];
    XCTAssertEqualObjects(mpk.hexString,
        @"4687e396a07188bd71458a0e90987f92b18a6451e99eb52f0060be450e0b4b3ce3e49f9f033914476cf503c7c2dcf5a0f90d3e943a84e507551bdf84891dd38c0817cca97a",
        @"[DSDerivationPath extendedPublicKey]");

    NSString *xpub = [account2.bip44DerivationPath serializedExtendedPublicKey];

    XCTAssertEqualObjects(xpub,
        @"xpub6CAqVZYbGiQCTyzzvvueEoBy8M74VWtPywf2F3zpwbS8AugDSSMSLcewpDaRQxVCxtL4kbTbWb1fzWg2R5933ECsxrEtKBA4gkJu8quduHs",
        @"[DSDerivationPath serializedExtendedPublicKey]");

    NSData *deserializedMpk = [DSDerivationPath deserializedExtendedPublicKey:xpub onChain:self.chain];

    XCTAssertEqualObjects(mpk,
        deserializedMpk,
        @"[DSDerivationPath deserializedMasterPublicKey: onChain:]");
}

- (void)test31BitDerivation {
    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    UInt512 I;

    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);

    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];

    DSECDSAKey *parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];

    NSData *parentPublicKey = parentSecret.publicKeyData;

    uint32_t derivation = 0;

    CKDpriv(&secret, &chain, derivation);

    NSData *publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;

    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);

    CKDpub(&pubKey, &chain2, 0);

    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];

    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");

    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");
}

- (void)test31BitCompatibilityModeDerivation {
    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    UInt512 I;

    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);

    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];

    DSECDSAKey *parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];

    NSData *parentPublicKey = parentSecret.publicKeyData;

    UInt256 derivation = UINT256_ZERO;

    CKDpriv256(&secret, &chain, derivation, NO);

    NSData *publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;

    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);

    CKDpub256(&pubKey, &chain2, derivation, NO);

    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];

    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");

    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");
}

- (void)testECDSAPrivateDerivation {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesECDSAKeysDerivationPathForWallet:self.wallet];

    XCTAssertNotNil(derivationPath, @"derivationPath should exist");

    [derivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:self.wallet.uniqueIDString storePrivateKey:NO];

    const NSUInteger indexes1[] = {1, 5};
    const NSUInteger indexes2[] = {4, 6};

    NSIndexPath *indexPath1 = [NSIndexPath indexPathWithIndexes:indexes1 length:2];
    NSIndexPath *indexPath2 = [NSIndexPath indexPathWithIndexes:indexes2 length:2];

    DSKey *privateKey1 = [derivationPath privateKeyAtIndexPath:indexPath1 fromSeed:self.seed];
    DSKey *publicKey1 = [derivationPath publicKeyAtIndexPath:indexPath1];

    XCTAssertEqualObjects(privateKey1.publicKeyData, publicKey1.publicKeyData, @"the public keys must match");

    DSKey *privateKey2 = [derivationPath privateKeyAtIndexPath:indexPath2 fromSeed:self.seed];
    DSKey *publicKey2 = [derivationPath publicKeyAtIndexPath:indexPath2];

    XCTAssertEqualObjects(privateKey2.publicKeyData, publicKey2.publicKeyData, @"the public keys must match");

    NSArray *privateKeys = [derivationPath privateKeysAtIndexPaths:@[indexPath1, indexPath2] fromSeed:self.seed];
    DSKey *privateKey1FromMultiIndex = privateKeys[0];
    DSKey *privateKey2FromMultiIndex = privateKeys[1];
    XCTAssertEqualObjects(privateKey1FromMultiIndex.publicKeyData, privateKey1.publicKeyData, @"the public keys must match");
    XCTAssertEqualObjects(privateKey2FromMultiIndex.publicKeyData, privateKey2.publicKeyData, @"the public keys must match");

    XCTAssertEqualObjects(privateKey1FromMultiIndex.privateKeyData, privateKey1.privateKeyData, @"the private keys must match");
    XCTAssertEqualObjects(privateKey2FromMultiIndex.privateKeyData, privateKey2.privateKeyData, @"the private keys must match");
}

- (void)testBLSPrivateDerivation {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self.wallet];

    [derivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:self.wallet.uniqueIDString storePrivateKey:YES];

    const NSUInteger indexes1[] = {1, 5};
    const NSUInteger indexes2[] = {4, 6};

    NSIndexPath *indexPath1 = [NSIndexPath indexPathWithIndexes:indexes1 length:2];
    NSIndexPath *indexPath2 = [NSIndexPath indexPathWithIndexes:indexes2 length:2];

    DSKey *privateKey1 = [derivationPath privateKeyAtIndexPath:indexPath1];
    DSKey *publicKey1 = [derivationPath publicKeyAtIndexPath:indexPath1];

    XCTAssertEqualObjects(privateKey1.publicKeyData, publicKey1.publicKeyData, @"the public keys must match");

    DSKey *privateKey2 = [derivationPath privateKeyAtIndexPath:indexPath2];
    DSKey *publicKey2 = [derivationPath publicKeyAtIndexPath:indexPath2];

    XCTAssertEqualObjects(privateKey2.publicKeyData, publicKey2.publicKeyData, @"the public keys must match");

    NSArray *privateKeys = [derivationPath privateKeysAtIndexPaths:@[indexPath1, indexPath2] fromSeed:self.seed];
    DSKey *privateKey1FromMultiIndex = privateKeys[0];
    DSKey *privateKey2FromMultiIndex = privateKeys[1];
    XCTAssertEqualObjects(privateKey1FromMultiIndex.publicKeyData, privateKey1.publicKeyData, @"the public keys must match");
    XCTAssertEqualObjects(privateKey2FromMultiIndex.publicKeyData, privateKey2.publicKeyData, @"the public keys must match");

    XCTAssertEqualObjects(privateKey1FromMultiIndex.privateKeyData, privateKey1.privateKeyData, @"the private keys must match");
    XCTAssertEqualObjects(privateKey2FromMultiIndex.privateKeyData, privateKey2.privateKeyData, @"the private keys must match");
}

- (void)test256BitDerivation {
    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    UInt512 I;

    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);

    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];

    DSECDSAKey *parentSecret = [DSECDSAKey keyWithSecret:secret compressed:YES];

    NSData *parentPublicKey = parentSecret.publicKeyData;

    UInt256 derivation = ((UInt256){.u64 = {
                                        5,
                                        12,
                                        15,
                                        1337,
                                    }});

    CKDpriv256(&secret, &chain, derivation, NO);

    NSData *publicKey = [DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData;

    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);

    CKDpub256(&pubKey, &chain2, derivation, NO);

    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];

    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");

    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");

    XCTAssertEqualObjects(uint256_data(derivation), @"05000000000000000c000000000000000f000000000000003905000000000000".hexToData, @"derivation must match the correct value");

    XCTAssertEqualObjects(publicKey.hexString, @"029d469d2a7070d6367afc099be3d0a8d6467ced43228b8ce3d1723f6f4f78cac7", @"the public must match the correct value");
}

- (void)testDashpayDerivation {
    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                              setCreationDate:0
                                                     forChain:self.chain
                                              storeSeedPhrase:NO
                                                  isTransient:YES];

    DSAccount *account = [wallet accountWithNumber:0];

    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];

    // NSData * data = [account.masterContactsDerivationPath extendedPublicKey];

    UInt256 sourceUser1 = @"01".hexToData.SHA256;

    UInt256 destinationUser2 = @"02".hexToData.SHA256;

    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];

    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:destinationUser2 sourceBlockchainIdentityUniqueId:sourceUser1 forAccountNumber:0 onChain:self.chain];

    incomingFundsDerivationPath.account = account;

    DSKey *extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];

    DSKey *extendedPublicKeyFromSeed = [incomingFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];

    XCTAssertEqualObjects(extendedPublicKeyFromMasterContactDerivationPath.extendedPublicKeyData, extendedPublicKeyFromSeed.extendedPublicKeyData, @"The extended public keys should be the same");

    XCTAssertEqualObjects(extendedPublicKeyFromMasterContactDerivationPath.extendedPublicKeyData.hexString, @"351973adaa8073a0ac848c08ba1c6df9a14d3c52033febe9bf4c5b365546a163bac5c8180240b908657221ebdc8fde7cd3017531159a7c58b955db380964c929dc6a85ac86", @"Incorrect value for extended public key");

    XCTAssertEqualObjects([incomingFundsDerivationPath addressAtIndex:0], @"Xs8zNYNY5hT38KFb8tq8EbnPn7GCNaqr45", @"First address should match expected value");
}


- (void)testBase64ExtendedPublicKeySize {
    DSAccount *account = [self.wallet accountWithNumber:0];

    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:nil];

    // NSData * data = [account.masterContactsDerivationPath extendedPublicKey];

    UInt256 sourceUser1 = @"01".hexToData.SHA256;

    UInt256 destinationUser2 = @"02".hexToData.SHA256;

    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];

    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:destinationUser2 sourceBlockchainIdentityUniqueId:sourceUser1 forAccountNumber:0 onChain:self.chain];

    incomingFundsDerivationPath.account = account;

    DSKey *extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];

    uint8_t bobSeed[10] = {10, 9, 8, 7, 6, 6, 7, 8, 9, 10};
    NSData *bobSeedData = [NSData dataWithBytes:bobSeed length:10];
    DSBLSKey *bobKeyPairBLS = [DSBLSKey keyWithSeedData:bobSeedData];

    DSAuthenticationKeysDerivationPath *derivationPathBLS = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self.wallet];
    DSKey *privateKeyBLS = [derivationPathBLS privateKeyAtIndex:0 fromSeed:self.seed];
    NSData *encryptedDataBLS = [extendedPublicKeyFromMasterContactDerivationPath.extendedPublicKeyData encryptWithSecretKey:privateKeyBLS forPublicKey:bobKeyPairBLS];

    NSString *base64DataBLS = encryptedDataBLS.base64String;
    XCTAssertEqual([base64DataBLS length], 128, @"The size of the base64 should be 128");

    UInt256 bobSecret = *(UInt256 *)@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData.bytes;

    DSECDSAKey *bobKeyPairECDSA = [DSECDSAKey keyWithSecret:bobSecret compressed:YES];

    DSAuthenticationKeysDerivationPath *derivationPathECDSA = [DSAuthenticationKeysDerivationPath blockchainIdentitiesECDSAKeysDerivationPathForWallet:self.wallet];
    DSKey *privateKeyECDSA = [derivationPathECDSA privateKeyAtIndex:0 fromSeed:self.seed];
    NSData *encryptedDataECDSA = [extendedPublicKeyFromMasterContactDerivationPath.extendedPublicKeyData encryptWithSecretKey:privateKeyECDSA forPublicKey:bobKeyPairECDSA];

    NSString *base64DataECDSA = encryptedDataECDSA.base64String;
    XCTAssertEqual([base64DataECDSA length], 128, @"The size of the base64 should be 128");
}

@end
