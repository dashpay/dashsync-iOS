//
//  DSProviderTransactionsTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 3/8/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSChainsManager.h"
#import "DSDerivationPath.h"
#import "DSFundsDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSporkManager.h"
#import "DSTransaction.h"
#import "DSTransactionFactory.h"
#import "DSTransactionInput.h"
#import "DSTransactionManager.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#include <arpa/inet.h>

@interface DSProviderTransactionsTests : XCTestCase

@end

@implementation DSProviderTransactionsTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testCollateralProviderRegistrationTransaction {
    DSChain *chain = [DSChain testnet];

    NSString *seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
    [chain addWallet:wallet];

    NSData *hexData = [NSData dataFromHexString:@"0300010001ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab58010000006b483045022100fe8fec0b3880bcac29614348887769b0b589908e3f5ec55a6cf478a6652e736502202f30430806a6690524e4dd599ba498e5ff100dea6a872ebb89c2fd651caa71ed012103d85b25d6886f0b3b8ce1eef63b720b518fad0b8e103eba4e85b6980bfdda2dfdffffffff018e37807e090000001976a9144ee1d4e5d61ac40a13b357ac6e368997079678c888ac00000000fd1201010000000000ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab580000000000000000000000000000ffff010205064e1f3dd03f9ec192b5f275a433bfc90f468ee1a3eb4c157b10706659e25eb362b5d902d809f9160b1688e201ee6e94b40f9b5062d7074683ef05a2d5efb7793c47059c878dfad38a30fafe61575db40f05ab0a08d55119b0aad300001976a9144fbc8fb6e11e253d77e5a9c987418e89cf4a63d288ac3477990b757387cb0406168c2720acf55f83603736a314a37d01b135b873a27b411fb37e49c1ff2b8057713939a5513e6e711a71cff2e517e6224df724ed750aef1b7f9ad9ec612b4a7250232e1e400da718a9501e1d9a5565526e4b1ff68c028763"];


    DSProviderRegistrationTransaction *providerRegistrationTransactionFromMessage = [[DSProviderRegistrationTransaction alloc] initWithMessage:hexData onChain:chain];

    NSLog(@"%@", providerRegistrationTransactionFromMessage.coreRegistrationCommand);

    //    protx register_prepare
    //    58ab8ba7dce591c745f8b78ee49156d13277fff20880855f7cda501705439aca
    //    0
    //    1.2.5.6:19999
    //    yRxHYGLf9G4UVYdtAoB2iAzR3sxxVaZB6y
    //    97762493aef0bcba1925870abf51dc21f4bc2b8c410c79b7589590e6869a0e04
    //    yfbxyP4ctRJR1rs3A8C3PdXA4Wtcrw7zTi
    //    0
    //    ycBFJGv7V95aSs6XvMewFyp1AMngeRHBwy

    NSString *txIdString = @"e65f550356250100513aa9c260400562ac8ee1b93ae1cc1214cc9f6830227b51";
    NSValue *inputTransactionHashValue = uint256_obj(@"ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab58".hexToData.UInt256);
    NSString *inputAddress0 = @"yQxPwSSicYgXiU22k4Ysq464VxRtgbnvpJ";
    NSString *outputAddress0 = @"yTWY6DsS4HBGs2JwDtnvVcpykLkbvtjUte";
    NSString *collateralAddress = @"yeNVS6tFeQNXJVkjv6nm6gb7PtTERV5dGh";
    NSString *collateralHash = @"58ab8ba7dce591c745f8b78ee49156d13277fff20880855f7cda501705439aca";
    uint32_t collateralIndex = 0;
    DSUTXO reversedCollateral = (DSUTXO){.hash = collateralHash.hexToData.reverse.UInt256, .n = collateralIndex};
    NSString *payoutAddress = @"yTb47qEBpNmgXvYYsHEN4nh8yJwa5iC4Cs";
    NSString *checkInputAddress0 = [wallet privateKeyAddressForAddress:inputAddress0 fromSeed:seed];
    XCTAssertEqualObjects(checkInputAddress0, inputAddress0, @"Private key does not match input address");

    DSAccount *collateralAccount = [providerRegistrationTransactionFromMessage.chain accountContainingAddress:collateralAddress];

    DSAccount *inputAccount = [providerRegistrationTransactionFromMessage.chain accountContainingAddress:inputAddress0];
    DSFundsDerivationPath *inputDerivationPath = (DSFundsDerivationPath *)[inputAccount derivationPathContainingAddress:inputAddress0];

    OpaqueKey *inputPrivateKey = [inputDerivationPath privateKeyForKnownAddress:inputAddress0 fromSeed:seed];

    NSMutableData *stringMessageData = [NSMutableData data];
    [stringMessageData appendString:DASH_MESSAGE_MAGIC];
    [stringMessageData appendString:providerRegistrationTransactionFromMessage.payloadCollateralString];
    UInt256 messageDigest = stringMessageData.SHA256_2;

    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.inputsHash), @"7ba273b835b1017da314a3363760835ff5ac20278c160604cb8773750b997734", @"Payload hash calculation has issues");

    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.payloadHash), @"71e973f79003accd202b9a2ab2613ac6ced601b26684e82f561f6684fef2f102", @"Payload hash calculation has issues");

    XCTAssertEqualObjects(@"yTb47qEBpNmgXvYYsHEN4nh8yJwa5iC4Cs|0|yRxHYGLf9G4UVYdtAoB2iAzR3sxxVaZB6y|yfbxyP4ctRJR1rs3A8C3PdXA4Wtcrw7zTi|71e973f79003accd202b9a2ab2613ac6ced601b26684e82f561f6684fef2f102", providerRegistrationTransactionFromMessage.payloadCollateralString, @"Provider transaction collateral string doesn't match");


    NSString *base64Signature = @"H7N+ScH/K4BXcTk5pVE+bnEacc/y5RfmIk33JO11Cu8bf5rZ7GErSnJQIy4eQA2nGKlQHh2aVWVSbksf9owCh2M=";

    DSFundsDerivationPath *derivationPath = (DSFundsDerivationPath *)[collateralAccount derivationPathContainingAddress:collateralAddress];

    NSIndexPath *indexPath = [derivationPath indexPathForKnownAddress:collateralAddress];
    
    NSData *signatureData = [DSKeyManager compactSign:derivationPath fromSeed:seed atIndexPath:indexPath digest:messageDigest];
    NSString *signature = [signatureData base64EncodedStringWithOptions:0];

    XCTAssertEqualObjects(signature, base64Signature, @"Signatures don't match up");


    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.payloadSignature, signatureData, @"Signatures don't match up");

    DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:wallet];
    if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
        [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:wallet];
    if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
        [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }

    OpaqueKey *ownerKey = [providerOwnerKeysDerivationPath privateKeyAtIndex:0 fromSeed:seed];
    UInt160 votingKeyHash = [providerVotingKeysDerivationPath publicKeyDataAtIndex:0].hash160;
    UInt384 operatorKey = [providerOperatorKeysDerivationPath publicKeyDataAtIndex:0].UInt384;
    uint16_t operatorKeyVersion = 1; // BLS legacy
    NSData *scriptPayout = [DSKeyManager scriptPubKeyForAddress:payoutAddress forChain:chain];

    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
    struct in_addr addrV4;
    if (inet_aton([@"1.2.5.6" UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
    }

    NSData *inputScript = [DSKeyManager scriptPubKeyForAddress:inputAddress0 forChain:chain];

    DSProviderRegistrationTransaction *providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:@[inputTransactionHashValue] inputIndexes:@[@1] inputScripts:@[inputScript] inputSequences:@[@(TXIN_SEQUENCE)] outputAddresses:@[outputAddress0] outputAmounts:@[@40777037710] providerRegistrationTransactionVersion:1 type:0 mode:0 collateralOutpoint:reversedCollateral ipAddress:ipAddress port:19999 ownerKeyHash:[DSKeyManager publicKeyData:ownerKey].hash160 operatorKey:operatorKey operatorKeyVersion:operatorKeyVersion votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:chain];


    providerRegistrationTransaction.payloadSignature = signatureData;

    [providerRegistrationTransaction signWithPrivateKeys:@[[NSValue valueWithPointer:inputPrivateKey]]];

    [providerRegistrationTransactionFromMessage setInputAddress:inputAddress0 atIndex:0];

    XCTAssertEqualObjects(providerRegistrationTransaction.payloadData, providerRegistrationTransactionFromMessage.payloadData, @"Provider payload data doesn't match up");

    XCTAssertEqualObjects(providerRegistrationTransaction.payloadCollateralString, providerRegistrationTransactionFromMessage.payloadCollateralString, @"Provider payload collateral strings don't match up");

    XCTAssertEqual(providerRegistrationTransaction.port, providerRegistrationTransactionFromMessage.port, @"Provider transaction port doesn't match up");

    XCTAssertEqualObjects(providerRegistrationTransaction.inputs, providerRegistrationTransactionFromMessage.inputs, @"Provider transaction inputs are having an issue");
    XCTAssertEqualObjects(providerRegistrationTransaction.outputs, providerRegistrationTransactionFromMessage.outputs, @"Provider transaction outputs are having an issue");

    XCTAssertEqualObjects(uint384_hex(providerRegistrationTransaction.operatorKey), uint384_hex(providerRegistrationTransactionFromMessage.operatorKey), @"Provider transaction operator key is having an issue");

    XCTAssertEqual(providerRegistrationTransaction.operatorReward, providerRegistrationTransactionFromMessage.operatorReward, @"Provider transaction operator Address is having an issue");

    XCTAssertEqualObjects(providerRegistrationTransaction.ownerAddress, providerRegistrationTransactionFromMessage.ownerAddress, @"Provider transaction owner Address is having an issue");

    XCTAssertEqualObjects(providerRegistrationTransaction.votingAddress, providerRegistrationTransactionFromMessage.votingAddress, @"Provider transaction voting Address is having an issue");

    XCTAssertEqualObjects(providerRegistrationTransaction.toData, hexData, @"Provider transaction does not match it's data");

    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.toData, hexData, @"Provider transaction does not match it's data");

    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.txHash), txIdString, @"Provider transaction hashes aren't correct");
}


- (void)testNoCollateralProviderRegistrationTransaction {
    DSChain *chain = [DSChain testnet];

    NSString *seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];

    NSData *hexData = [NSData dataFromHexString:@"030001000379efbe95cba05893d09f4ec51a71171a3852b54aa958ae35ce43276f5f8f1002000000006a473044022015df39c80ca8595cc197a0be692e9d158dc53bdbc8c6abca0d30c086f338c037022063becdb4f891436de3d2fb21cbf294e9dcb5c1a04bc0ba621867479e46d048cc0121030de5cb8989b6902d98017ab4d42b9244912006b0a1561c1d1ba0e2f3117a39adffffffff79efbe95cba05893d09f4ec51a71171a3852b54aa958ae35ce43276f5f8f1002010000006a47304402205c1bae23b459081b060de14133a20378243bebc05c8e2ed9acdabf6717ae7f9702204027ba0abbcce9ba5b2cb563cbff0190ba8f80e5f8fd6beb07c2c449f194c9be01210270b0f0b71472736a397975a84927314261be815d423006d1bcbc00cd693c3d81ffffffff9d925d6cd8e3a408f472e872d1c2849bc664efda8c7f68f1b3a3efde221bc474010000006a47304402203fa23ec33f91efa026b34e90b15a1fd64ff03242a6a92985b16a25b590e5bae002202d1429374b60b1180cd8b9bd0b432158524f5624d6c5d2d6db8c637c9961a21e0121024c0b09e261253dc40ed572c2d63d0b6cda89154583d75a5ab5a14fba81d70089ffffffff0200e87648170000001976a9143795a62df2eb953c1d08bc996d4089ee5d67e28b88ac438ca95a020000001976a91470ed8f5b5cfd4791c15b9d8a7f829cb6a98da18c88ac00000000d101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff010101014e1f3dd03f9ec192b5f275a433bfc90f468ee1a3eb4c157b10706659e25eb362b5d902d809f9160b1688e201ee6e94b40f9b5062d7074683ef05a2d5efb7793c47059c878dfad38a30fafe61575db40f05ab0a08d55119b0aad300001976a9143795a62df2eb953c1d08bc996d4089ee5d67e28b88ac14b33f2231f0df567e0dfb12899c893f5d2d05f6dcc7d9c8c27b68a71191c75400"];
    NSString *txIdString = @"717d2d4a7d583da184872f4a07e35d897a1be9dd9875b4c017c81cf772e36694";
    DSUTXO input0 = (DSUTXO){.hash = @"02108f5f6f2743ce35ae58a94ab552381a17711ac54e9fd09358a0cb95beef79".hexToData.reverse.UInt256, .n = 0};
    DSUTXO input1 = (DSUTXO){.hash = @"02108f5f6f2743ce35ae58a94ab552381a17711ac54e9fd09358a0cb95beef79".hexToData.reverse.UInt256, .n = 1};
    DSUTXO input2 = (DSUTXO){.hash = @"74c41b22deefa3b3f1687f8cdaef64c69b84c2d172e872f408a4e3d86c5d929d".hexToData.reverse.UInt256, .n = 1};
    NSString *inputAddress0 = @"yRdHYt6nG1ooGaXK7GEbwVMteLY3m4FbVT";
    NSString *inputAddress1 = @"yWJqVcT5ot5GEcB8oYkHnnYcFG5pLiVVtd";
    NSString *inputAddress2 = @"ygQ8tG3tboQ7oZEhtDBBYtquTmVyiDe6d5";
    NSString *outputAddress0 = @"yRPMHZKviaWgqPaNP7XURemxtf7EyXNN1k";
    NSString *outputAddress1 = @"yWcZ7ePLX3yLkC3Aj9KaZvxRQkkZC6VPL8";
    NSString *payoutAddress = @"yRPMHZKviaWgqPaNP7XURemxtf7EyXNN1k";
    OpaqueKey *inputPrivateKey0 = [wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
    OpaqueKey *inputPrivateKey1 = [wallet privateKeyForAddress:inputAddress1 fromSeed:seed];
    OpaqueKey *inputPrivateKey2 = [wallet privateKeyForAddress:inputAddress2 fromSeed:seed];
    NSString *checkInputAddress0 = [DSKeyManager addressForKey:inputPrivateKey0 forChainType:chain.chainType];
    NSString *checkInputAddress1 = [DSKeyManager addressForKey:inputPrivateKey1 forChainType:chain.chainType];
    NSString *checkInputAddress2 = [DSKeyManager addressForKey:inputPrivateKey2 forChainType:chain.chainType];
    XCTAssertEqualObjects(checkInputAddress0, inputAddress0, @"Private key does not match input address");
    XCTAssertEqualObjects(checkInputAddress1, inputAddress1, @"Private key does not match input address");
    XCTAssertEqualObjects(checkInputAddress2, inputAddress2, @"Private key does not match input address");

    DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:wallet];
    if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
        [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:wallet];
    if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
        [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }

    OpaqueKey *ownerKey = [providerOwnerKeysDerivationPath privateKeyAtIndex:0 fromSeed:seed];
    UInt160 votingKeyHash = [providerVotingKeysDerivationPath publicKeyDataAtIndex:0].hash160;
    UInt384 operatorKey = [providerOperatorKeysDerivationPath publicKeyDataAtIndex:0].UInt384;

    uint16_t operatorKeyVersion = 1; // BLS legacy
    DSProviderRegistrationTransaction *providerRegistrationTransactionFromMessage = [[DSProviderRegistrationTransaction alloc] initWithMessage:hexData onChain:chain];

    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.toData, hexData, @"Provider transaction does not match it's data");

    NSData *scriptPayout = [DSKeyManager scriptPubKeyForAddress:payoutAddress forChain:chain];

    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
    struct in_addr addrV4;
    if (inet_aton([@"1.1.1.1" UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
    }

    NSArray *inputHashes = @[uint256_obj(input0.hash), uint256_obj(input1.hash), uint256_obj(input2.hash)];
    NSArray *inputIndexes = @[@(input0.n), @(input1.n), @(input2.n)];
    NSArray *inputScripts = @[
        [DSKeyManager scriptPubKeyForAddress:inputAddress0 forChain:chain],
        [DSKeyManager scriptPubKeyForAddress:inputAddress1 forChain:chain],
        [DSKeyManager scriptPubKeyForAddress:inputAddress2 forChain:chain]
    ];

    DSProviderRegistrationTransaction *providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts inputSequences:@[@(TXIN_SEQUENCE), @(TXIN_SEQUENCE), @(TXIN_SEQUENCE)] outputAddresses:@[outputAddress0, outputAddress1] outputAmounts:@[@100000000000, @10110995523] providerRegistrationTransactionVersion:1 type:0 mode:0 collateralOutpoint:DSUTXO_ZERO ipAddress:ipAddress port:19999 ownerKeyHash:[DSKeyManager publicKeyData:ownerKey].hash160 operatorKey:operatorKey operatorKeyVersion:operatorKeyVersion votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:wallet.chain];


    [providerRegistrationTransaction updateInputsHash];
    [providerRegistrationTransaction signWithPrivateKeys:@[
        [NSValue valueWithPointer:inputPrivateKey0],
        [NSValue valueWithPointer:inputPrivateKey1],
        [NSValue valueWithPointer:inputPrivateKey2]
    ]];

    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.toData.hexString, providerRegistrationTransaction.toData.hexString, @"Provider transaction does not match it's data");

    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.txHash), txIdString, @"Provider transaction hashes aren't correct");

    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransaction.txHash), txIdString, @"Provider transaction hashes aren't correct");
}


- (void)testProviderUpdateServiceTransaction {
    DSChain *chain = [DSChain testnet];

    NSString *seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";

    NSData *seed = [[DSBIP39Mnemonic sharedInstance]
        deriveKeyFromPhrase:seedPhrase
             withPassphrase:nil];

    DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];

    NSData *hexData = [NSData dataFromHexString:@"03000200018f3fe6683e36326669b6e34876fb2a2264e8327e822f6fec304b66f47d61b3e1010000006b48304502210082af6727408f0f2ec16c7da1c42ccf0a026abea6a3a422776272b03c8f4e262a022033b406e556f6de980b2d728e6812b3ae18ee1c863ae573ece1cbdf777ca3e56101210351036c1192eaf763cd8345b44137482ad24b12003f23e9022ce46752edf47e6effffffff0180220e43000000001976a914123cbc06289e768ca7d743c8174b1e6eeb610f1488ac00000000b501003a72099db84b1c1158568eec863bea1b64f90eccee3304209cebe1df5e7539fd00000000000000000000ffff342440944e1f00e6725f799ea20480f06fb105ebe27e7c4845ab84155e4c2adf2d6e5b73a998b1174f9621bbeda5009c5a6487bdf75edcf602b67fe0da15c275cc91777cb25f5fd4bb94e84fd42cb2bb547c83792e57c80d196acd47020e4054895a0640b7861b3729c41dd681d4996090d5750f65c4b649a5cd5b2bdf55c880459821e53d91c9"];
    DSUTXO input0 = (DSUTXO){.hash = @"e1b3617df4664b30ec6f2f827e32e864222afb7648e3b6696632363e68e63f8f".hexToData.reverse.UInt256, .n = 1};
    NSString *inputAddress0 = @"yhmDZGmiwjCPJrTFFiBFZJw31PhvJFJAwq";
    OpaqueKey *inputPrivateKey0 = [wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
    NSString *outputAddress0 = @"yMysmZV5ftuBzuvDMHWn3tMpWg7BJownRE";
    UInt256 providerTransactionHash = @"fd39755edfe1eb9c200433eecc0ef9641bea3b86ec8e5658111c4bb89d09723a".hexToData.reverse.UInt256;
    NSString *checkInputAddress0 = [DSKeyManager addressForKey:inputPrivateKey0 forChainType:chain.chainType];
    XCTAssertEqualObjects(checkInputAddress0, inputAddress0, @"Private key does not match input address");
    DSProviderUpdateServiceTransaction *providerUpdateServiceTransactionFromMessage = [[DSProviderUpdateServiceTransaction alloc] initWithMessage:hexData onChain:chain];
    XCTAssertEqualObjects(providerUpdateServiceTransactionFromMessage.toData, hexData, @"Provider update service transaction does not match it's data");
    DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:wallet.uniqueIDString];
    }
    UInt384 operatorKeyNeeded = [NSData dataFromHexString:@"157b10706659e25eb362b5d902d809f9160b1688e201ee6e94b40f9b5062d7074683ef05a2d5efb7793c47059c878dfa"].UInt384;
    OpaqueKey *privateKey = [providerOperatorKeysDerivationPath privateKeyAtIndex:0 fromSeed:seed]; // BLS
    NSData *operatorKeyData = [providerOperatorKeysDerivationPath publicKeyDataAtIndex:0];
    XCTAssertEqualObjects(operatorKeyData.hexString, [NSData dataWithUInt384:operatorKeyNeeded].hexString, @"operator keys don't match");
    OpaqueKey *operatorBLSKey = [DSKeyManager keyWithPublicKeyData:operatorKeyData ofType:KeyKind_BLS];
    UInt256 payloadHash = providerUpdateServiceTransactionFromMessage.payloadDataForHash.SHA256_2;
    UInt768 signatureFromDigest = [DSKeyManager signMesasageDigest:privateKey digest:payloadHash].UInt768;
    NSData *txPayloadForHash = providerUpdateServiceTransactionFromMessage.payloadDataForHash;
    BLSKey *bls;
    if (privateKey->tag == OpaqueKey_BLSBasic)
        bls = privateKey->bls_basic;
    else
        bls = privateKey->bls_legacy;
    NSData *signatureFromData = [DSKeyManager NSDataFrom:key_bls_sign_data(bls, txPayloadForHash.bytes, txPayloadForHash.length)];
    XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], signatureFromData, @"payload signature doesn't match");
    XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], providerUpdateServiceTransactionFromMessage.payloadSignature, @"payload signature doesn't match");
    BOOL verified = [DSKeyManager verifyMessageDigest:privateKey digest:payloadHash signature:signatureFromData];
    XCTAssertTrue(verified, @"The signature is not signed correctly");
    XCTAssertTrue([providerUpdateServiceTransactionFromMessage checkPayloadSignature:operatorBLSKey], @"The payload is not signed correctly");
    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
    struct in_addr addrV4;
    if (inet_aton([@"52.36.64.148" UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
    }
    NSArray *inputHashes = @[uint256_obj(input0.hash)];
    NSArray *inputIndexes = @[@(input0.n)];
    NSArray *inputScripts = @[[DSKeyManager scriptPubKeyForAddress:inputAddress0 forChain:chain]];
    DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = [[DSProviderUpdateServiceTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts inputSequences:@[@(TXIN_SEQUENCE)] outputAddresses:@[outputAddress0] outputAmounts:@[@(1124999808)] providerUpdateServiceTransactionVersion:1 providerTransactionHash:providerTransactionHash ipAddress:ipAddress port:19999 scriptPayout:[NSData data] onChain:chain];
    [providerUpdateServiceTransaction updateInputsHash];
    [providerUpdateServiceTransaction signPayloadWithKey:privateKey];
    [providerUpdateServiceTransaction signWithPrivateKeys:@[[NSValue valueWithPointer:inputPrivateKey0]]];
    XCTAssertEqualObjects(providerUpdateServiceTransaction.toData, hexData, @"Provider transaction does not match it's data");
}


- (void)testProviderUpdateRegistrarTransaction {
    DSChain *chain = [DSChain testnet];

    NSData *providerRegistrationTransactionData = [NSData dataFromHexString:@"030001000183208ad8994250a0eb0ae35a2b072b65b8db87fadd2463df3464fc7341adcddc000000006b483045022100a6deda2a6dd5cafacfa893982ee3a45ec7e74a6324101af20d1fb19660f0300902205ae115609890fa2a0215f1ecbb2126b6aaf77a999c3d4bcbd08530dba716efeb012103ef6556ae33ffab22d1937e9bf03f3f5cf895e0f96005f6f0f92799a13cae2948ffffffff01ed4970d0060000001976a9145e2bc4c4222f99928f6d1957340ab090cc3a00b888ac00000000fd1201010000000000b23e38fe428255d0068cc218c2c831e3bfc87c8249f3cba941e126053fd73b8a0100000000000000000000000000ffffcff665d84e1fecb1486be55e4301c45b87cbad94daa8c5d17fdd139b654f0b1c031e1cf2b934c2d895178875cfe7c6a4f6758f02bc66eea7fc292d0040701acbe31f5e14a911cb061a2f062da2ee9f1c9682a398b97a4a31199a5aaa32ab00001976a91456bcf3cac49235537d6ce0fb3214d8850a6db77788ac43f6b45e1c6b23fa7fbeb7e21478b95718e0558b0a0d1b566d34bb85c2b397ee411f6bbb5bcc2174185a5b0529c57e346d75f7f4fbed3999ea75a1cd9af2cb4eaf7344c485c70f34c91a753e97e6454dc0bff127f79af5a6fd724195446bea181b0a"];


    DSProviderRegistrationTransaction *providerRegistrationTransactionFromMessage = [[DSProviderRegistrationTransaction alloc] initWithMessage:providerRegistrationTransactionData onChain:chain];

    NSData *hexData = [NSData dataFromHexString:@"0300030001c7de76dac8dd96f9b49b12a06fe39c8caf0cad12d23ad6026094d9b11b2b260d000000006b483045022100b31895e8cea95a965c82d842eadd6eef3c7b29e677c62a5c8e2b5dce05b4ddfc02206c7b5a9ea8b71983c3b21f4ff75ac1aa44090d28af8b2d9b93e794e6eb5835e20121032ea8be689184f329dce575776bc956cd52230f4c04755d5753d9491ea5bf8f2affffffff01c94670d0060000001976a914345f07bc7ebaf9f82f273be249b6066d2d5c236688ac00000000e4010049aa692330179f95c1342715102e37777df91cc0f3a4ae7e8f9e214ee97dbb3d0000139b654f0b1c031e1cf2b934c2d895178875cfe7c6a4f6758f02bc66eea7fc292d0040701acbe31f5e14a911cb061a2f6cc4a7bb877a80c11ae06b988d98305773f93b981976a91456bcf3cac49235537d6ce0fb3214d8850a6db77788ac2d7f857a2f15eb9340a0cfbce3ff8cf09b40e582d05b1f98c7468caa0f942bcf411ff69c9cb072660cc10048332c14c08621e7461f1f4f54b448baedc0e3434d9a7c3a1780885aaef4dd44c597b49b97595e02ad54728f572967d3ce0c2c0ceac174"];
    NSString *txIdString = @"bd98378ca37d3ae6f4850b82e77be675feb3c9bc6e33cb0c23de1b38a08034c7";
    DSUTXO input0 = (DSUTXO){.hash = @"0d262b1bb1d9946002d63ad212ad0caf8c9ce36fa0129bb4f996ddc8da76dec7".hexToData.reverse.UInt256, .n = 0};
    NSString *inputAddress0 = @"yabJKtPXkYc8ZXQNYjdKxwG7TcpdyJN1Ns";
//    key_create
//    ECDSAKey *inputPrivateKey = [DSKeyManager ecdsaKeyWithPrivateKey:@"cRfAz5ZmPN9eGSkXrGk3VYjJWt8gWffLCKTy7BtAgpQZj8YPvXwU" forChainType:chain.chainType];
    OpaqueKey *inputPrivateKey = [DSKeyManager keyWithPrivateKeyString:@"cRfAz5ZmPN9eGSkXrGk3VYjJWt8gWffLCKTy7BtAgpQZj8YPvXwU" ofKeyType:KeyKind_ECDSA forChainType:chain.chainType];
    NSString *outputAddress0 = @"yR6MpzaykeioS25qZWrTWx2ruHCecYjMwa";
    NSString *votingAddress = @"yWEZQmGADmdSk6xCai7TPcmiSZuY65hBmo";
    NSString *payoutAddress = @"yUE5KLX1HNA4BkjN1Zgtwq6hQ16Cvo7hrX";
    NSString *privateOwnerKeyString = @"cQpV2b9hNQd5Xs7REcrkPXmuCNDVvx6mSndr2ZgXKhfAhWDUUznB";
    NSString *privateOperatorKey = @"0fc63f4e6d7572a6c33465525b5c3323f57036873dd37c98c393267c58b50533";
    OpaqueKey *operatorKey = [DSKeyManager keyWithPrivateKeyString:privateOperatorKey ofKeyType:KeyKind_BLS forChainType:chain.chainType];
    UInt256 providerTransactionHash = @"3dbb7de94e219e8f7eaea4f3c01cf97d77372e10152734c1959f17302369aa49".hexToData.reverse.UInt256;
    DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransactionFromMessage = [[DSProviderUpdateRegistrarTransaction alloc] initWithMessage:hexData registrationTransaction:providerRegistrationTransactionFromMessage onChain:chain];
    XCTAssertEqualObjects(providerUpdateRegistrarTransactionFromMessage.toData, hexData, @"Provider update registrar transaction does not match it's data");
    OpaqueKey *privateKey = [DSKeyManager keyWithPrivateKeyString:privateOwnerKeyString ofKeyType:KeyKind_ECDSA forChainType:chain.chainType];
    UInt256 payloadHash = providerUpdateRegistrarTransactionFromMessage.payloadHash;
    NSData *compactSignature = [DSKeyManager NSDataFrom:key_ecdsa_compact_sign(privateKey->ecdsa, payloadHash.u8)];

    XCTAssertEqualObjects(compactSignature.hexString, providerUpdateRegistrarTransactionFromMessage.payloadSignature.hexString, @"payload signature doesn't match");

    BOOL verified = [DSKeyManager verifyMessageDigest:privateKey digest:payloadHash signature:compactSignature];

    XCTAssertTrue(verified, @"The signature is not signed correctly");
    XCTAssertTrue([providerUpdateRegistrarTransactionFromMessage checkPayloadSignature:privateKey], @"The payload is not signed correctly");

    NSArray *inputHashes = @[uint256_obj(input0.hash)];
    NSArray *inputIndexes = @[@(input0.n)];
    NSArray *inputScripts = @[[DSKeyManager scriptPubKeyForAddress:inputAddress0 forChain:chain]];
    NSData *scriptPayout = [DSKeyManager scriptPubKeyForAddress:payoutAddress forChain:chain];
    NSData *operatorPublicKey = [DSKeyManager NSDataFrom:key_bls_public_key(operatorKey->bls_legacy)];

    DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = [[DSProviderUpdateRegistrarTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts inputSequences:@[@(TXIN_SEQUENCE)] outputAddresses:@[outputAddress0] outputAmounts:@[@(29266822857)] providerUpdateRegistrarTransactionVersion:1 providerTransactionHash:providerTransactionHash mode:0 operatorKey:operatorPublicKey.UInt384 votingKeyHash:votingAddress.addressToHash160.UInt160 scriptPayout:scriptPayout onChain:chain];
    [providerUpdateRegistrarTransaction updateInputsHash];
    [providerUpdateRegistrarTransaction signPayloadWithKey:privateKey];
    [providerUpdateRegistrarTransaction signWithPrivateKeys:@[[NSValue valueWithPointer:inputPrivateKey]]];

    XCTAssertEqualObjects(providerUpdateRegistrarTransaction.toData.hexString, hexData.hexString, @"Provider transaction does not match it's data");
    XCTAssertEqualObjects(uint256_reverse_hex(providerUpdateRegistrarTransaction.txHash), txIdString, @"Provider transaction hashes aren't correct");
}

- (void)testCollectionOperations {
    UInt256 h0 = @"02108f5f6f2743ce35ae58a94ab552381a17711ac54e9fd09358a0cb95beef79".hexToData.UInt256;
    UInt256 h1 = @"02108f5f6f2743ce35ae58a94ab552381a17711ac54e9fd09358a0cb95beef80".hexToData.UInt256;
    UInt256 h2 = @"74c41b22deefa3b3f1687f8cdaef64c69b84c2d172e872f408a4e3d86c5d929d".hexToData.UInt256;
    UInt256 h3 = @"74c41b22deefa3b3f1687f8cdaef64c69b84c2d172e872f408a4e3d86c5d929e".hexToData.UInt256;
    UInt256 h4 = @"74c41b22deefa3b3f1687f8cdaef64c69b84c2d172e872f408a4e3d86c5d929f".hexToData.UInt256;
    UInt256 h5 = @"84c41b22deefa3b3f1687f8cdaef64c69b84c2d172e872f408a4e3d86c5d929f".hexToData.UInt256;
    NSMutableOrderedSet *txHashes = [NSMutableOrderedSet orderedSetWithArray:@[
        uint256_obj(h0),
        uint256_obj(h1),
        uint256_obj(h5),
    ]];
    NSMutableOrderedSet *knownTxHashes = [NSMutableOrderedSet orderedSetWithArray:@[
        uint256_obj(h0),
        uint256_obj(h1),
        uint256_obj(h2),
        uint256_obj(h3),
        uint256_obj(h4),
    ]];
    NSLog(@"start: tx_hashes: %@", txHashes);
    NSLog(@"start: known_tx_hashes: %@", knownTxHashes);
    if ([txHashes intersectsOrderedSet:knownTxHashes]) {
        [txHashes minusOrderedSet:knownTxHashes];
    }
    [knownTxHashes unionOrderedSet:txHashes];
    NSLog(@"finish: tx_hashes: %@", txHashes);
    NSLog(@"finish: known_tx_hashes: %@", knownTxHashes);

}


@end
