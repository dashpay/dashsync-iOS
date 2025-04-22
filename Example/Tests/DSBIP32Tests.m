//
//  DSBIP32Tests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "dash_spv_apple_bindings.h"
#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSChain+Params.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSGapLimit.h"
#import "DSKeyManager.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Tests.h"
#import "NSData+Encryption.h"
#import "NSIndexPath+FFI.h"
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

//- (void)testBLSFingerprintFromSeed {
//    uint8_t seed[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
//    NSData *seedData = [NSData dataWithBytes:seed length:10];
//    
//    
//    
//    BLSKey *keyPair = key_bls_with_seed_data(seedData.bytes, seedData.length, true);
//    XCTAssertEqual(key_bls_fingerprint(keyPair), 0xddad59bb, @"Testing BLS private child public key fingerprint");
//    uint8_t seed2[] = {1, 50, 6, 244, 24, 199, 1, 25};
//    NSData *seedData2 = [NSData dataWithBytes:seed2 length:8];
//    BLSKey *keyPair2 = key_bls_with_bip32_seed_data(seedData2.bytes, seedData2.length, true);
//    XCTAssertEqual(key_bls_fingerprint(keyPair2), 0xa4700b27, @"Testing BLS extended private child public key fingerprint");
//    processor_destroy_bls_key(keyPair);
//    processor_destroy_bls_key(keyPair2);
//}
//
//- (void)testBLSDerivation {
//    uint8_t seed[] = {1, 50, 6, 244, 24, 199, 1, 25};
//    NSData *seedData = [NSData dataWithBytes:seed length:8];
//    BLSKey *keyPair = key_bls_with_bip32_seed_data(seedData.bytes, seedData.length, true);
//    NSData *chainCode = [DSKeyManager NSDataFrom:key_bls_chaincode(keyPair)];
//
//    XCTAssertEqualObjects(chainCode.hexString, @"d8b12555b4cc5578951e4a7c80031e22019cc0dce168b3ed88115311b8feb1e3", @"Testing BLS derivation chain code");
//
//    UInt256 derivationPathIndexes1[] = {uint256_from_long(77)};
//    BOOL hardened1[] = {YES};
//    DSDerivationPath *derivationPath1 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes1 hardened:hardened1 length:1 type:DSDerivationPathType_ClearFunds signingAlgorithm:KeyKind_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
//    NSIndexPath *baseIndexPath1 = derivationPath1.baseIndexPath;
//    
//    
//    IndexPathData *index_path1 = [baseIndexPath1 ffi_malloc];
//    BLSKey *keyPair1 = key_bls_private_derive_to_path(keyPair, index_path1);
//    [NSIndexPath ffi_free:index_path1];
//
//    NSData *chainCode1 = [DSKeyManager NSDataFrom:key_bls_chaincode(keyPair1)];
//    XCTAssertEqualObjects(chainCode1.hexString, @"f2c8e4269bb3e54f8179a5c6976d92ca14c3260dd729981e9d15f53049fd698b", @"Testing BLS private child derivation returning chain code");
//    XCTAssertEqual(key_bls_fingerprint(keyPair1), 0xa8063dcf, @"Testing BLS extended private child public key fingerprint");
//
//    UInt256 derivationPathIndexes2[] = {uint256_from_long(3), uint256_from_long(17)};
//    BOOL hardened2[] = {NO, NO};
//    DSDerivationPath *derivationPath2 = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes2 hardened:hardened2 length:2 type:DSDerivationPathType_ClearFunds signingAlgorithm:KeyKind_BLS reference:DSDerivationPathReference_Unknown onChain:[DSChain mainnet]];
//    NSIndexPath *baseIndexPath2 = derivationPath2.baseIndexPath;
//    IndexPathData *index_path2 = [baseIndexPath2 ffi_malloc];
//    BLSKey *keyPair2 = key_bls_private_derive_to_path(keyPair, index_path2);
//    XCTAssertEqual(key_bls_fingerprint(keyPair2), 0xff26a31f, @"Testing BLS extended private child public key fingerprint");
//    BLSKey *keyPair3 = key_bls_private_derive_to_path(keyPair, index_path2);
//    [NSIndexPath ffi_free:index_path2];
//    XCTAssertEqual(key_bls_fingerprint(keyPair3), 0xff26a31f, @"Testing BLS extended private child public key fingerprint");
//}

// MARK: - testBIP32Sequence

- (void)testBIP32SequencePrivateKeyFromString {
    // from plastic upon blast park salon ticket timber disease tree camera economy what alpha birth category
    NSString *seedString = @"000102030405060708090a0b0c0d0e0f";

    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedString setCreationDate:[[NSDate date] timeIntervalSince1970] forChain:self.chain storeSeedPhrase:NO isTransient:YES];
    DSAccount *account = [wallet accountWithNumber:0];
    DSFundsDerivationPath *derivationPath = account.bip32DerivationPath;

    NSData *seed = seedString.hexToData;
    
    NSUInteger internalIndexes[] = {1, 2 | BIP32_HARD};
    NSString *pk = [DSDerivationPathFactory serializedPrivateKeysAtIndexPaths:@[[NSIndexPath indexPathWithIndexes:internalIndexes length:2]] fromSeed:seed derivationPath:derivationPath].lastObject;
    
    NSLog(@"pk: %@", pk);
    NSData *d = pk.base58checkToData;

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/1/2' prv = %@", [NSString hexWithData:d]);


    XCTAssertEqualObjects(d.hexString, @"cccbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca01",
        @"[DSDerivationPath privateKey:internal:fromSeed:]");

    // Test for correct zero padding of private keys, a nasty potential bug
    NSUInteger externalIndexes[] = {0, 97};

    pk = [DSDerivationPathFactory serializedPrivateKeysAtIndexPaths:@[[NSIndexPath indexPathWithIndexes:externalIndexes length:2]] fromSeed:seed derivationPath:derivationPath].lastObject;
//
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
        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        rootDerivationPath.wallet = wallet;
        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPublicKey:rootDerivationPath],
                              @"xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:rootDerivationPath],
                              @"xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0' //
    //--------------------------------------------------------------------------------------------------//

    {
        DSAccount *account = [wallet accountWithNumber:0];
        DSFundsDerivationPath *derivationPath = account.bip32DerivationPath;
        NSString *serializedBip32ExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedBip32ExtendedPublicKey,
                              @"xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw",
                              @"[DSDerivationPath serializedExtendedPublicKey:]");
        NSString *serializedBip32ExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedBip32ExtendedPrivateKey,
                              @"xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed:]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1)};
        BOOL hardened[] = {YES, NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:2 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPublicKey:derivationPath],
                              @"xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath],
                              @"xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2' //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2)};
        BOOL hardened[] = {YES, NO, YES};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:3 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPublicKey:derivationPath],
                              @"xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath],
                              @"xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2'/2 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2), uint256_from_long(2)};
        BOOL hardened[] = {YES, NO, YES, NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:4 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPublicKey:derivationPath],
                              @"xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath],
                              @"xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0'/1/2'/2/1000000000 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(1), uint256_from_long(2), uint256_from_long(2), uint256_from_long(1000000000)};
        BOOL hardened[] = {YES, NO, YES, NO, NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:5 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPublicKey:derivationPath],
                              @"xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        XCTAssertEqualObjects([DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath],
                              @"xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76",
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
        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        rootDerivationPath.wallet = wallet;
        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:rootDerivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:rootDerivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0)};
        BOOL hardened[] = {NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:1 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647)};
        BOOL hardened[] = {NO, YES};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:2 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1)};
        BOOL hardened[] = {NO, YES, NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:3 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1/2147483646' //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1), uint256_from_long(2147483646)};
        BOOL hardened[] = {NO, YES, NO, YES};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:4 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc",
                              @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0/2147483647'/1/2147483646'/2 //
    //--------------------------------------------------------------------------------------------------//
    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0), uint256_from_long(2147483647), uint256_from_long(1), uint256_from_long(2147483646), uint256_from_long(2)};
        BOOL hardened[] = {NO, YES, NO, YES, NO};
        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:5 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];
        derivationPath.wallet = wallet;
        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];
        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPublicKey,
                              @"xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt",
                              @"[DSDerivationPath serializedExtendedPublicKey]");
        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];
        XCTAssertEqualObjects(serializedRootExtendedPrivateKey,
                              @"xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j",
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

        DSDerivationPath *rootDerivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexesRoot hardened:hardenedRoot length:0 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];

        rootDerivationPath.wallet = wallet;

        [rootDerivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:rootDerivationPath];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:rootDerivationPath];

        XCTAssertEqualObjects(serializedRootExtendedPrivateKey, @"xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6",
            @"[DSDerivationPath serializedExtendedPrivateKeyFromSeed]");
    }

    //--------------------------------------------------------------------------------------------------//
    // m/0' //
    //--------------------------------------------------------------------------------------------------//

    {
        UInt256 derivationPathIndexes[] = {uint256_from_long(0)};
        BOOL hardened[] = {YES};

        DSDerivationPath *derivationPath = [DSDerivationPath derivationPathWithIndexes:derivationPathIndexes hardened:hardened length:1 type:DSDerivationPathType_Unknown signingAlgorithm:DKeyKindECDSA() reference:DSDerivationPathReference_Root onChain:self.chain];

        derivationPath.wallet = wallet;

        [derivationPath generateExtendedPublicKeyFromSeed:seedData storeUnderWalletUniqueId:nil];

        NSString *serializedRootExtendedPublicKey = [DSDerivationPathFactory serializedExtendedPublicKey:derivationPath];

        XCTAssertEqualObjects(serializedRootExtendedPublicKey, @"xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y",
            @"[DSDerivationPath serializedExtendedPublicKey]");

        NSString *serializedRootExtendedPrivateKey = [DSDerivationPathFactory serializedExtendedPrivateKeyFromSeed:seedData derivationPath:derivationPath];

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
    NSUInteger indexes[] = {0, 0};
    NSData *pub = [account.bip32DerivationPath publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:2]];

    NSLog(@"000102030405060708090a0b0c0d0e0f/0'/0/0 pub = %@", [NSString hexWithData:pub]);

    XCTAssertEqualObjects(pub, @"027b6a7dd645507d775215a9035be06700e1ed8c541da9351b4bd14bd50ab61428".hexToData,
        @"[DSBIP32Sequence publicKey:internal:masterPublicKey:]");
}

- (void)testBIP32SequenceSerializedPrivateMasterFromSeed {
    NSString *seedString = @"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f";
    NSData *seed = seedString.hexToData;
    Slice_u8 *seed_slice = slice_ctor(seed);
    char *c_string = DECDSAKeySerializedPrivateMasterKey(seed_slice, self.chain.chainType);
    
    NSString *xprv = [DSKeyManager NSStringFrom:c_string];
    NSLog(@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f xpriv = %@", xprv);
    XCTAssertEqualObjects(xprv,
        @"xprv9s21ZrQH143K27s8Yy6TJSKmKUxTBuXJr4RDTjJ5Jqq13d9v2VzYymSoM4VodDK7nrQHTruX6TuBsGuEVXoo91GwZnmBcTaqUhgK7HeysNv",
        @"[DSBIP32Sequence serializedPrivateMasterFromSeedData:forChain:]");
}

- (void)testBIP32SequenceSerializedMasterPublicKey {
    // from Mnemonic stay issue box trade stock chaos raccoon candy obey wet refuse carbon silent guide crystal
    DSWallet *wallet = [DSWallet transientWalletWithDerivedKeyData:@"bb22c8551ef39739fa007efc150975fce0187e675d74c804ab32f87fe0b9ad387fe9b044b8053dfb26cf9d7e4857617fa66430c880e7f4c96554b4eed8a0ad2f".hexToData forChain:self.chain];

    DSAccount *account = [wallet accountWithNumber:0];

    NSString *xpub = [DSDerivationPathFactory serializedExtendedPublicKey:account.bip32DerivationPath];

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

    xpub = [DSDerivationPathFactory serializedExtendedPublicKey:account2.bip32DerivationPath];

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

    NSString *xpub = [DSDerivationPathFactory serializedExtendedPublicKey:account2.bip44DerivationPath];

    XCTAssertEqualObjects(xpub,
        @"xpub6CAqVZYbGiQCTyzzvvueEoBy8M74VWtPywf2F3zpwbS8AugDSSMSLcewpDaRQxVCxtL4kbTbWb1fzWg2R5933ECsxrEtKBA4gkJu8quduHs",
        @"[DSDerivationPath serializedExtendedPublicKey]");

    NSData *deserializedMpk = [DSDerivationPathFactory deserializedExtendedPublicKey:xpub onChain:self.chain];

    XCTAssertEqualObjects(mpk,
        deserializedMpk,
        @"[DSDerivationPath deserializedMasterPublicKey: onChain:]");
}
// TODO: make rust bindings for these tests if needed
//- (void)test31BitDerivation {
//    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
//    NSData *seed = [[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
//    UInt512 I;
//    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
//    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
//    DOpaqueKey *parentSecret = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *parentPublicKey = [DSKeyManager publicKeyData:parentSecret];
//    uint32_t derivation = 0;
//    CKDpriv(&secret, &chain, derivation);
//    DOpaqueKey *derivedKey = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *publicKey = [DSKeyManager publicKeyData:derivedKey];
//    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
//    CKDpub(&pubKey, &chain2, 0);
//    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
//    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");
//    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");
//}
//
//- (void)test31BitCompatibilityModeDerivation {
//    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
//    NSData *seed = [[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
//    UInt512 I;
//    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
//    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
//    DOpaqueKey *parentSecret = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *parentPublicKey = [DSKeyManager publicKeyData:parentSecret];
//    UInt256 derivation = UINT256_ZERO;
//    CKDpriv256(&secret, &chain, derivation, NO);
//    DOpaqueKey *derivedKey = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *publicKey = [DSKeyManager publicKeyData:derivedKey];
//    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
//    CKDpub256(&pubKey, &chain2, derivation, NO);
//    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
//    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");
//    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");
//}

- (void)testECDSAPrivateDerivation {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:self.wallet];
    XCTAssertNotNil(derivationPath, @"derivationPath should exist");
    [derivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:self.wallet.uniqueIDString storePrivateKey:NO];
    const NSUInteger indexes1[] = {1, 5};
    const NSUInteger indexes2[] = {4, 6};
    NSIndexPath *indexPath1 = [NSIndexPath indexPathWithIndexes:indexes1 length:2];
    NSIndexPath *indexPath2 = [NSIndexPath indexPathWithIndexes:indexes2 length:2];
    DMaybeOpaqueKey *privateKey1 = [derivationPath privateKeyAtIndexPath:indexPath1 fromSeed:self.seed];
    DMaybeOpaqueKey *publicKey1 = [derivationPath publicKeyAtIndexPath:indexPath1];
    Vec_u8 *publicKey1_data = DOpaqueKeyPublicKeyData(publicKey1->ok);
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey1->ok, publicKey1_data), @"the public keys must match");
    DMaybeOpaqueKey *privateKey2 = [derivationPath privateKeyAtIndexPath:indexPath2 fromSeed:self.seed];
    DMaybeOpaqueKey *publicKey2 = [derivationPath publicKeyAtIndexPath:indexPath2];
    Vec_u8 *publicKey2_data = DOpaqueKeyPublicKeyData(publicKey2->ok);
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey2->ok, publicKey2_data), @"the public keys must match");
    
    DMaybeOpaqueKeys *privateKeys = [DSDerivationPathFactory privateKeysAtIndexPaths:@[indexPath1, indexPath2]
                                                                            fromSeed:self.seed
                                                                      derivationPath:derivationPath];
    
    DOpaqueKey *privateKey1FromMultiIndex = privateKeys->ok->values[0];
    DOpaqueKey *privateKey2FromMultiIndex = privateKeys->ok->values[1];

    Vec_u8 *privateKey1_public_key_data = DOpaqueKeyPublicKeyData(privateKey1->ok);
    Vec_u8 *privateKey2_public_key_data = DOpaqueKeyPublicKeyData(privateKey2->ok);
    DMaybeKeyData *privateKey1_private_key_data = DOpaqueKeyPrivateKeyData(privateKey1->ok);
    DMaybeKeyData *privateKey2_private_key_data = DOpaqueKeyPrivateKeyData(privateKey2->ok);
    u256 *privateKey1_private_key_data_u = Arr_u8_32_ctor(privateKey1_private_key_data->ok->count, privateKey1_private_key_data->ok->values);
    u256 *privateKey2_private_key_data_u = Arr_u8_32_ctor(privateKey2_private_key_data->ok->count, privateKey2_private_key_data->ok->values);
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey1FromMultiIndex, privateKey1_public_key_data), @"the public keys must match");
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey2FromMultiIndex, privateKey2_public_key_data), @"the public keys must match");
    XCTAssert(DOpaqueKeyPrivateKeyDataEqualTo(privateKey1FromMultiIndex, privateKey1_private_key_data_u), @"the private keys must match");
    XCTAssert(DOpaqueKeyPrivateKeyDataEqualTo(privateKey2FromMultiIndex, privateKey2_private_key_data_u), @"the private keys must match");
}

- (void)testBLSPrivateDerivation {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesBLSKeysDerivationPathForWallet:self.wallet];
    [derivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:self.wallet.uniqueIDString storePrivateKey:YES];
    const NSUInteger indexes1[] = {1, 5};
    const NSUInteger indexes2[] = {4, 6};
    NSIndexPath *indexPath1 = [NSIndexPath indexPathWithIndexes:indexes1 length:2];
    NSIndexPath *indexPath2 = [NSIndexPath indexPathWithIndexes:indexes2 length:2];
    DMaybeOpaqueKey *privateKey1 = [derivationPath privateKeyAtIndexPath:indexPath1];
    DMaybeOpaqueKey *publicKey1 = [derivationPath publicKeyAtIndexPath:indexPath1];
    
    Vec_u8 *publicKey1_public_key_data = DOpaqueKeyPublicKeyData(publicKey1->ok);
    
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey1->ok, publicKey1_public_key_data), @"the public keys must match");
//    XCTAssert(keys_public_key_data_is_equal(privateKey1, publicKey1), @"the public keys must match");
    DMaybeOpaqueKey *privateKey2 = [derivationPath privateKeyAtIndexPath:indexPath2];
    DMaybeOpaqueKey *publicKey2 = [derivationPath publicKeyAtIndexPath:indexPath2];
    
    Vec_u8 *publicKey2_public_key_data = DOpaqueKeyPublicKeyData(publicKey2->ok);

    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey2->ok, publicKey2_public_key_data), @"the public keys must match");
    DMaybeOpaqueKeys *privateKeys = [DSDerivationPathFactory privateKeysAtIndexPaths:@[indexPath1, indexPath2]
                                                                            fromSeed:self.seed
                                                                      derivationPath:derivationPath];

    DOpaqueKey *privateKey1FromMultiIndex = privateKeys->ok->values[0];
    DOpaqueKey *privateKey2FromMultiIndex = privateKeys->ok->values[1];
    
    
    Vec_u8 *privateKey1_public_key_data = DOpaqueKeyPublicKeyData(privateKey1->ok);
    Vec_u8 *privateKey2_public_key_data = DOpaqueKeyPublicKeyData(privateKey2->ok);
    DMaybeKeyData *privateKey1_private_key_data = DOpaqueKeyPrivateKeyData(privateKey1->ok);
    DMaybeKeyData *privateKey2_private_key_data = DOpaqueKeyPrivateKeyData(privateKey2->ok);
    u256 *privateKey1_private_key_data_u = Arr_u8_32_ctor(privateKey1_private_key_data->ok->count, privateKey1_private_key_data->ok->values);
    u256 *privateKey2_private_key_data_u = Arr_u8_32_ctor(privateKey2_private_key_data->ok->count, privateKey2_private_key_data->ok->values);

    
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey1FromMultiIndex, privateKey1_public_key_data), @"the public keys must match");
    XCTAssert(DOpaqueKeyPublicKeyDataEqualTo(privateKey2FromMultiIndex, privateKey2_public_key_data), @"the public keys must match");
    XCTAssert(DOpaqueKeyPrivateKeyDataEqualTo(privateKey1FromMultiIndex, privateKey1_private_key_data_u), @"the private keys must match");
    XCTAssert(DOpaqueKeyPrivateKeyDataEqualTo(privateKey2FromMultiIndex, privateKey2_private_key_data_u), @"the private keys must match");

    
//    NSValue *privateKey1FromMultiIndexValue = privateKeys[0];
//    NSValue *privateKey2FromMultiIndexValue = privateKeys[1];
//    DOpaqueKey *privateKey1FromMultiIndex = privateKey1FromMultiIndexValue.pointerValue;
//    DOpaqueKey *privateKey2FromMultiIndex = privateKey2FromMultiIndexValue.pointerValue;
//    XCTAssert(keys_public_key_data_is_equal(privateKey1FromMultiIndex, privateKey1), @"the public keys must match");
//    XCTAssert(keys_public_key_data_is_equal(privateKey2FromMultiIndex, privateKey2), @"the public keys must match");
//    XCTAssert(keys_private_key_data_is_equal(privateKey1FromMultiIndex, privateKey1), @"the private keys must match");
//    XCTAssert(keys_private_key_data_is_equal(privateKey2FromMultiIndex, privateKey2), @"the private keys must match");
}

// TODO: make rust bindings for these tests if needed
//- (void)test256BitDerivation {
//    NSString *seedPhrase = @"upper renew that grow pelican pave subway relief describe enforce suit hedgehog blossom dose swallow";
//
//    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
//        deriveKeyFromPhrase:seedPhrase
//             withPassphrase:nil];
//
//    UInt512 I;
//    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
//    UInt256 secret = *(UInt256 *)&I, chain2, chain = chain2 = *(UInt256 *)&I.u8[sizeof(UInt256)];
//    DOpaqueKey *parentSecret = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *parentPublicKey = [DSKeyManager publicKeyData:parentSecret];
//    UInt256 derivation = ((UInt256){.u64 = { 5, 12, 15, 1337 }});
//    CKDpriv256(&secret, &chain, derivation, NO);
//    DOpaqueKey *derivedSecret = key_create_ecdsa_from_secret(secret.u8, 32, true);
//    NSData *publicKey = [DSKeyManager publicKeyData:derivedSecret];
//    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentPublicKey.bytes);
//    CKDpub256(&pubKey, &chain2, derivation, NO);
//    NSData *publicKey2 = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
//    XCTAssertEqualObjects(uint256_hex(chain), uint256_hex(chain2), @"the bip32 chains must match");
//    XCTAssertEqualObjects(publicKey, publicKey2, @"the public keys must match");
//    XCTAssertEqualObjects(uint256_data(derivation), @"05000000000000000c000000000000000f000000000000003905000000000000".hexToData, @"derivation must match the correct value");
//    XCTAssertEqualObjects(publicKey.hexString, @"029d469d2a7070d6367afc099be3d0a8d6467ced43228b8ce3d1723f6f4f78cac7", @"the public must match the correct value");
//}

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
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];
    DSIncomingFundsDerivationPath *path = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:destinationUser2 sourceIdentityUniqueId:sourceUser1 forAccount:account onChain:self.chain];
    DMaybeOpaqueKey *extendedPublicKeyFromMasterContactDerivationPath = [path generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    NSData *extendedPublicKeyFromMasterContactDerivationPathData = [DSKeyManager extendedPublicKeyData:extendedPublicKeyFromMasterContactDerivationPath->ok];
    DMaybeOpaqueKey *extendedPublicKeyFromSeed = [path generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    NSData *extendedPublicKeyFromSeedData = [DSKeyManager extendedPublicKeyData:extendedPublicKeyFromSeed->ok];
    XCTAssertEqualObjects(extendedPublicKeyFromMasterContactDerivationPathData.hexString,
                          extendedPublicKeyFromSeedData.hexString,
                          @"The extended public keys should be the same");
    XCTAssertEqualObjects(extendedPublicKeyFromMasterContactDerivationPathData.hexString,
                          @"351973adaa8073a0ac848c08ba1c6df9a14d3c52033febe9bf4c5b365546a163bac5c8180240b908657221ebdc8fde7cd3017531159a7c58b955db380964c929dc6a85ac86",
                          @"Incorrect value for extended public key");
    NSData *pubKey = [path publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:(const NSUInteger[]){0} length:1]];

    XCTAssertEqualObjects([DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:path.chain.chainType],
                          @"Xs8zNYNY5hT38KFb8tq8EbnPn7GCNaqr45",
                          @"First address should match expected value");
}


- (void)testBase64ExtendedPublicKeySizeBLS {
    DSAccount *account = [self.wallet accountWithNumber:0];
    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:nil];
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];
    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:destinationUser2 sourceIdentityUniqueId:sourceUser1 forAccount:account onChain:self.chain];
    DMaybeOpaqueKey *extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesBLSKeysDerivationPathForWallet:self.wallet];
    NSData *seed_data = [NSData dataWithBytes:(uint8_t[10]) {10, 9, 8, 7, 6, 6, 7, 8, 9, 10} length:10];
    Slice_u8 *seed_slice = slice_ctor(seed_data);
    DKeyKind *kind = DKeyKindBLS();
    DMaybeOpaqueKey *bobKeyPairBLS = DMaybeOpaqueKeyFromSeed(kind, seed_slice);
//    DOpaqueKey *bobKeyPairBLS = key_with_seed_data((uint8_t[10]) {10, 9, 8, 7, 6, 6, 7, 8, 9, 10}, 10, (int16_t) KeyKind_BLS);
    DMaybeOpaqueKey *privateKeyBLS = [derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:0] fromSeed:self.seed];
    NSData *extendedPublicKeyFromMasterContactDerivationPathData = [DSKeyManager extendedPublicKeyData:extendedPublicKeyFromMasterContactDerivationPath->ok];
    NSData *encryptedDataBLS = [extendedPublicKeyFromMasterContactDerivationPathData encryptWithSecretKey:privateKeyBLS->ok forPublicKey:bobKeyPairBLS->ok];
    XCTAssertEqual([encryptedDataBLS.base64String length], 128, @"The size of the base64 should be 128");
    // Destroying in dealloc of DSDerivationPath
    DMaybeOpaqueKeyDtor(bobKeyPairBLS);
    DMaybeOpaqueKeyDtor(privateKeyBLS);
}

- (void)testBase64ExtendedPublicKeySizeECDSA {
    DSAccount *account = [self.wallet accountWithNumber:0];
    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:nil];
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];
    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:destinationUser2 sourceIdentityUniqueId:sourceUser1 forAccount:account onChain:self.chain];
    DMaybeOpaqueKey *extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    NSData *extendedPublicKeyFromMasterContactDerivationPathData = [DSKeyManager extendedPublicKeyData:extendedPublicKeyFromMasterContactDerivationPath->ok];
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:self.wallet];
    NSData *bobSecretData = @"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140".hexToData;
    
    Slice_u8 *bob_secret_slice = slice_ctor(bobSecretData);
    
    DMaybeOpaqueKey *bobKeyPairECDSA = DMaybeOpaqueKeyWithPrivateKeyData(DKeyKindECDSA(), bob_secret_slice);
    
    DMaybeOpaqueKey *privateKeyECDSA = [derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:0] fromSeed:self.seed];
    NSData *encryptedDataECDSA = [extendedPublicKeyFromMasterContactDerivationPathData encryptWithSecretKey:privateKeyECDSA->ok forPublicKey:bobKeyPairECDSA->ok];
    XCTAssertEqual([encryptedDataECDSA.base64String length], 128, @"The size of the base64 should be 128");
    
    DMaybeOpaqueKeyDtor(bobKeyPairECDSA);
    DMaybeOpaqueKeyDtor(privateKeyECDSA);
}

- (void)testIdDer {
    NSString *seedPhrase = @"kitchen shop average soccer husband relax creek project divorce plastic sand evil";
    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase
                                              setCreationDate:0
                                                     forChain:[DSChain testnet]
                                              storeSeedPhrase:YES
                                                  isTransient:NO];
    NSMutableArray<NSData *> *keyHashes = [NSMutableArray array];

    uint32_t unusedIndex = [wallet unusedIdentityIndex];
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:wallet];
    const int keysToCheck = 5;
    NSLog(@"•••••••••••••••••••••");
    NSMutableDictionary *keyIndexes = [NSMutableDictionary dictionary];
    for (int i = 0; i < keysToCheck; i++) {
        const NSUInteger indexes[] = {(unusedIndex + i) | BIP32_HARD, 0 | BIP32_HARD};
        NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
        DMaybeOpaqueKey *key = [derivationPath publicKeyAtIndexPath:indexPath];
        u160 *key_hash = DOpaqueKeyPublicKeyHash(key->ok);
        NSData *keyHash = NSDataFromPtr(key_hash);
        u160_dtor(key_hash);
        [keyHashes addObject:keyHash];
        Vec_u8 *pub_key_data = DOpaqueKeyPublicKeyData(key->ok);
        [keyIndexes setObject:@(unusedIndex + i) forKey:NSDataFromPtr(pub_key_data)];
        Vec_u8_destroy(pub_key_data);
    }
    for (NSData *keyIndexData in keyIndexes) {
        NSNumber *keyIndex = keyIndexes[keyIndexData];
        NSLog(@"keyIndex: %@: %@", keyIndex, keyIndexData.hexString);
    }
    
    for (NSData *keyHash in keyHashes) {
        NSLog(@"keyHash: %@", keyHash.hexString);
        
    }
    
}

- (void)testAddressRegistration {
    NSLog(@"SEED: %@ ", self.seed.hexString);
    DSAccount *account = [self.wallet accountWithNumber:0];
//    [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:self.seed storeUnderWalletUniqueId:nil];
    UInt256 sourceUser1 = @"01".hexToData.SHA256;
    UInt256 destinationUser2 = @"02".hexToData.SHA256;
    DSDerivationPath *masterContactsDerivationPath = [account masterContactsDerivationPath];

    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:destinationUser2
                                                                                                                                   sourceIdentityUniqueId:sourceUser1
                        
                                                                                                                                               forAccount:account
                                                                                                                                                  onChain:self.chain];

    NSArray *addr = @[
        @"Xs8zNYNY5hT38KFb8tq8EbnPn7GCNaqr45", @"XwWQUo4dVZyBbFPfYFaDeQPheAyF1UMNrM", @"Xn1ZbTGjxfm2u8NvgkkaqVTpGDQEje7WcE",
        @"XgBYmmXKzwyEtfAEjckYeF6rDn9soWTVGh", @"Xpj22eAisURDuR78wgn6oXu1MCjioG9q2o", @"XggND74Hr7T5BEbGUQh2KA6HekH3ETLboQ",
        @"XrbDuBSQgGirgeej84CrAei3utTgLn5idh", @"XgbqXkwJ6mF2kD1ewHL328SsmFNgSJWw52", @"XeMUeHCYRJAHs75xhgBPPxmDMQQZ8eA8Yq",
        @"XyfLokqnEqP1n28RaaGyYr3h7i1gaPuFrx"
    ];

    DMaybeOpaqueKey *extendedPublicKeyFromMasterContactDerivationPath = [incomingFundsDerivationPath generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    NSArray *addresses = [incomingFundsDerivationPath registerAddressesWithSettings:[DSGapLimit withLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL]];
    XCTAssertEqualObjects(addr, addresses, @"Incoming Funds Address registration is broken");

    
    DSFundsDerivationPath *fundsDerivationPath = account.bip32DerivationPath;
    NSUInteger registerGapLimit = [fundsDerivationPath shouldUseReducedGapLimit] ? SEQUENCE_UNUSED_GAP_LIMIT_INITIAL : SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL;

    addr = @[@"Xo6DdaeXwo6RrZmo5ANJHX3rbtyjbe9T8E", @"XoAyZ8XGiuoWaTGZKr4Twt9qJ6N5NoAkcC", @"Xiw2UrfyKk25Axz688bTR2Q4wrEqe25s53",
             @"XninCEW1c3tTtLJhWZSS4hxXxvifud7MwV", @"XvvX9mv9zjiuvTiJMngvxyd2nsRg35ncQv", @"XvgxEYMPsRcArR278s6KhSAT1e5TMCyFmz",
             @"XxsafWegPEfTyo7yFpKrHCFYoq4rU51Hez", @"XgBckqELMYgdQ8NLh788CQ8b4NhCnSZDix", @"XgZnMiKv9kz6rkSooWGCjAorJcWKU7BTme",
             @"XszcLZPFZiFwrieYqYqGi5aiWNW1sVMstg", @"Xtba4ANeMmqWLnC1sHGx4mpLZE36TGS4zP", @"Xi2xGMNENSUxwX5PoZ3krczoTThUbkethW",
             @"Xf7H7nBDsMp31AN4dB8ESPCvuxkrw2y9nV", @"XkyNdyxsMRNQqB2Ns5tAr44ypFak9APtZQ", @"XjRZhQjwgEDv6NgC72HzNQ9veFKN9dF1DV"];
    
    addresses = [fundsDerivationPath registerAddressesWithSettings:[DSGapLimitFunds external:registerGapLimit]];
    XCTAssertEqualObjects(addr, addresses, @"External Funds Address registration is broken");

    addr = @[@"XrXhvXAfNjqwRKRhGbJjzmdjEQFaS9fPyn", @"XgerxzzfUZbxmPFwd1KWHheUGHXMJE3JBT", @"Xp2chci79M3bpdMKqewM4SephDqyQDA4d4",
             @"XugKvwuXt1bJd9oWoPCL4y77uf5BPyDpEq", @"XiiVyHz4JBdeib22QC9wfmj8PpsrfTRG47", @"XsvExbmoEAZTmbzS7GmKvu5RWRezbhDSNM",
             @"Xjut8E67j1YhmusRH4eHaM6QHoTf8PcyxE", @"Xh1xphusd1jSWH5bznLZeVzUjyVSRcyYfv", @"Xdrc2g25JWSQQpMKDFt9pxBXFno8B7ZRfr",
             @"Xm9wfkssebS1guJW3WfSYudTxJaDqf1wWB", @"Xfr3Md6SAcxqeVmgtSPyUVof5YgG6mivFP", @"Xw4wqZJoUVY4mTokF8cMUjvzh1sngRzAvM",
             @"XyXyaNQs5Zv3RAdTaCJLdhD2UzVVUjB9uv", @"XhLh5YmLjDwyq3eT4q1zukmGZcAkhD5X5Q", @"Xcny5L7z2x9VvdiAqTDdoRvjP3nC8Pbe8H"];
    
    addresses = [fundsDerivationPath registerAddressesWithSettings:[DSGapLimitFunds internal:registerGapLimit]];
    XCTAssertEqualObjects(addr, addresses, @"Internal Funds Address registration is broken");


}

@end
