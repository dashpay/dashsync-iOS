//
//  DSProviderTransactionsTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 3/8/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSECDSAKey.h"
#import "DSChain.h"
#import "NSString+Bitcoin.h"
#import "DSTransaction.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSTransactionFactory.h"
#import "DSChainManager.h"
#import "NSData+Dash.h"
#import "DSTransactionLockVote.h"
#import "DSTransactionManager.h"
#import "DSMasternodeManager.h"
#import "DSSporkManager.h"
#import "DSChainsManager.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSDerivationPath.h"
#import "DSFundsDerivationPath.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
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

-(void)testCollateralProviderRegistrationTransaction {
    DSChain * chain = [DSChain testnet];
    
    NSString * seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
    
    NSData * hexData = [NSData dataFromHexString:@"0300010001ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab58010000006b483045022100fe8fec0b3880bcac29614348887769b0b589908e3f5ec55a6cf478a6652e736502202f30430806a6690524e4dd599ba498e5ff100dea6a872ebb89c2fd651caa71ed012103d85b25d6886f0b3b8ce1eef63b720b518fad0b8e103eba4e85b6980bfdda2dfdffffffff018e37807e090000001976a9144ee1d4e5d61ac40a13b357ac6e368997079678c888ac00000000fd1201010000000000ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab580000000000000000000000000000ffff010205064e1f3dd03f9ec192b5f275a433bfc90f468ee1a3eb4c157b10706659e25eb362b5d902d809f9160b1688e201ee6e94b40f9b5062d7074683ef05a2d5efb7793c47059c878dfad38a30fafe61575db40f05ab0a08d55119b0aad300001976a9144fbc8fb6e11e253d77e5a9c987418e89cf4a63d288ac3477990b757387cb0406168c2720acf55f83603736a314a37d01b135b873a27b411fb37e49c1ff2b8057713939a5513e6e711a71cff2e517e6224df724ed750aef1b7f9ad9ec612b4a7250232e1e400da718a9501e1d9a5565526e4b1ff68c028763"];
    
    
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
    
    NSString * txIdString = @"e65f550356250100513aa9c260400562ac8ee1b93ae1cc1214cc9f6830227b51";
    NSValue * inputTransactionHashValue = uint256_obj(@"ca9a43051750da7c5f858008f2ff7732d15691e48eb7f845c791e5dca78bab58".hexToData.UInt256);
    NSString * inputAddress0 = @"yQxPwSSicYgXiU22k4Ysq464VxRtgbnvpJ";
    NSString * outputAddress0 = @"yTWY6DsS4HBGs2JwDtnvVcpykLkbvtjUte";
    NSString * collateralAddress = @"yeNVS6tFeQNXJVkjv6nm6gb7PtTERV5dGh";
    NSString * collateralHash = @"58ab8ba7dce591c745f8b78ee49156d13277fff20880855f7cda501705439aca";
    uint32_t collateralIndex = 0;
    DSUTXO reversedCollateral = (DSUTXO) { .hash = collateralHash.hexToData.reverse.UInt256, .n = collateralIndex};
    NSString * payoutAddress = @"yTb47qEBpNmgXvYYsHEN4nh8yJwa5iC4Cs";
    DSECDSAKey * inputPrivateKey0 = (DSECDSAKey *)[wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
    
    NSString * checkInputAddress0 = [inputPrivateKey0 addressForChain:chain];
    XCTAssertEqualObjects(checkInputAddress0,inputAddress0,@"Private key does not match input address");
    
    DSAccount * collateralAccount = [providerRegistrationTransactionFromMessage.chain accountContainingAddress:collateralAddress];
    
    DSAccount * inputAccount = [providerRegistrationTransactionFromMessage.chain accountContainingAddress:inputAddress0];
    DSFundsDerivationPath * inputDerivationPath = [inputAccount derivationPathContainingAddress:inputAddress0];
    
    DSKey * inputPrivateKey = [inputDerivationPath privateKeyForKnownAddress:inputAddress0 fromSeed:seed];
    
    NSMutableData * stringMessageData = [NSMutableData data];
    [stringMessageData appendString:DASH_MESSAGE_MAGIC];
    [stringMessageData appendString:providerRegistrationTransactionFromMessage.payloadCollateralString];
    UInt256 messageDigest = stringMessageData.SHA256_2;
    
    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.inputsHash), @"7ba273b835b1017da314a3363760835ff5ac20278c160604cb8773750b997734", @"Payload hash calculation has issues");
    
    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.payloadHash), @"71e973f79003accd202b9a2ab2613ac6ced601b26684e82f561f6684fef2f102", @"Payload hash calculation has issues");
    
    XCTAssertEqualObjects(@"yTb47qEBpNmgXvYYsHEN4nh8yJwa5iC4Cs|0|yRxHYGLf9G4UVYdtAoB2iAzR3sxxVaZB6y|yfbxyP4ctRJR1rs3A8C3PdXA4Wtcrw7zTi|71e973f79003accd202b9a2ab2613ac6ced601b26684e82f561f6684fef2f102",providerRegistrationTransactionFromMessage.payloadCollateralString,@"Provider transaction collateral string doesn't match");
    
    
    NSString * base64Signature = @"H7N+ScH/K4BXcTk5pVE+bnEacc/y5RfmIk33JO11Cu8bf5rZ7GErSnJQIy4eQA2nGKlQHh2aVWVSbksf9owCh2M=";
    
    DSFundsDerivationPath * derivationPath = [collateralAccount derivationPathContainingAddress:collateralAddress];
    
    NSIndexPath * indexPath = [derivationPath indexPathForKnownAddress:collateralAddress];
    DSECDSAKey* key = (DSECDSAKey*)[derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
    NSData * signatureData = [key compactSign:messageDigest];
    NSString * signature = [signatureData base64EncodedStringWithOptions:0];
    
    XCTAssertEqualObjects(signature,base64Signature,@"Signatures don't match up");
    
    
    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.payloadSignature, signatureData,@"Signatures don't match up");
    
    DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:wallet];
    if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
        [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:wallet];
    if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
        [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    
    DSECDSAKey * ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyAtIndex:0 fromSeed:seed];
    UInt160 votingKeyHash = [providerVotingKeysDerivationPath publicKeyDataAtIndex:0].hash160;
    UInt384 operatorKey = [providerOperatorKeysDerivationPath publicKeyDataAtIndex:0].UInt384;

    NSMutableData * scriptPayout = [NSMutableData data];
    [scriptPayout appendScriptPubKeyForAddress:payoutAddress forChain:wallet.chain];
    
    UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
    struct in_addr addrV4;
    if (inet_aton([@"1.2.5.6" UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
    }
    
    NSMutableData *inputScript = [NSMutableData data];
    
    [inputScript appendScriptPubKeyForAddress:inputAddress0 forChain:chain];
    
    DSProviderRegistrationTransaction *providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:@[inputTransactionHashValue] inputIndexes:@[@1] inputScripts:@[inputScript] inputSequences:@[@(TXIN_SEQUENCE)] outputAddresses:@[outputAddress0] outputAmounts:@[@40777037710] providerRegistrationTransactionVersion:1 type:0 mode:0 collateralOutpoint:reversedCollateral ipAddress:ipAddress port:19999 ownerKeyHash:ownerKey.publicKeyData.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:chain];
    
    
    providerRegistrationTransaction.payloadSignature = signatureData;
    
    [providerRegistrationTransaction signWithPrivateKeys:@[inputPrivateKey]];
    
    
    XCTAssertEqualObjects(providerRegistrationTransaction.payloadData,providerRegistrationTransactionFromMessage.payloadData,@"Provider payload data doesn't match up");
    
        XCTAssertEqualObjects(providerRegistrationTransaction.payloadCollateralString, providerRegistrationTransactionFromMessage.payloadCollateralString,@"Provider payload collateral strings don't match up");
    
    XCTAssertEqual(providerRegistrationTransaction.port,providerRegistrationTransactionFromMessage.port,@"Provider transaction port doesn't match up");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.inputHashes,providerRegistrationTransactionFromMessage.inputHashes,@"Provider transaction input hashes are having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.inputIndexes,providerRegistrationTransactionFromMessage.inputIndexes,@"Provider transaction input indexes are having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.inputSequences,providerRegistrationTransactionFromMessage.inputSequences,@"Provider transaction input sequences are having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.outputAddresses,providerRegistrationTransactionFromMessage.outputAddresses,@"Provider transaction output addresses are having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.outputAmounts,providerRegistrationTransactionFromMessage.outputAmounts,@"Provider transaction output amounts are having an issue");
    
    XCTAssertEqualObjects(uint384_hex(providerRegistrationTransaction.operatorKey), uint384_hex(providerRegistrationTransactionFromMessage.operatorKey),@"Provider transaction operator key is having an issue");
    
    XCTAssertEqual(providerRegistrationTransaction.operatorReward,providerRegistrationTransactionFromMessage.operatorReward,@"Provider transaction operator Address is having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.ownerAddress,providerRegistrationTransactionFromMessage.ownerAddress,@"Provider transaction owner Address is having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.votingAddress,providerRegistrationTransactionFromMessage.votingAddress,@"Provider transaction voting Address is having an issue");
    
    XCTAssertEqualObjects(providerRegistrationTransaction.toData,hexData,@"Provider transaction does not match it's data");
    
    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.toData,hexData,@"Provider transaction does not match it's data");
    
    XCTAssertEqualObjects(uint256_reverse_hex(providerRegistrationTransactionFromMessage.txHash),txIdString,@"Provider transaction hashes aren't correct");
    
}


-(void)testNoCollateralProviderRegistrationTransaction {
    DSChain * chain = [DSChain testnet];
    
    NSString * seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
    
    NSData * hexData = [NSData dataFromHexString:@"030001000379efbe95cba05893d09f4ec51a71171a3852b54aa958ae35ce43276f5f8f1002000000006b4830450221008d31ca87f95f976b645b9b1eecfdbbe32173e3c338e05aff70011069be9002da02206c20b6df83ce54e4abe56cece05823baf341ebb8ec88347a7770f8fdd3d1b3930121030de5cb8989b6902d98017ab4d42b9244912006b0a1561c1d1ba0e2f3117a39adffffffff79efbe95cba05893d09f4ec51a71171a3852b54aa958ae35ce43276f5f8f1002010000006a47304402200d047e24bf72cc350e6e753309f93781676ed836584addb3540023b2db1d0e3802202fe648482ee79c002655cd9d467c4a94126478d4867ff96e98bfbd6222e7261101210270b0f0b71472736a397975a84927314261be815d423006d1bcbc00cd693c3d81ffffffff9d925d6cd8e3a408f472e872d1c2849bc664efda8c7f68f1b3a3efde221bc474010000006a4730440220793f9c111af2539c92da947b1deae3d15ee3932c1df8dcb8c1beba9ebf7f825f02204cda7b969f0947f1ad20f35737add0f4fc2540f4e38b6dbe56810ac0a22834cd0121024c0b09e261253dc40ed572c2d63d0b6cda89154583d75a5ab5a14fba81d70089ffffffff0200e87648170000001976a9143795a62df2eb953c1d08bc996d4089ee5d67e28b88ac438ca95a020000001976a91470ed8f5b5cfd4791c15b9d8a7f829cb6a98da18c88ac00000000d101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff010101011f4e1d7fe8b4f16bda38d98cb208b6be4c8f3abb4c8b859bdc161a8a246a572cbc0c1928faacecbc12133b64f18480a32938eec081129016e99929caea89f317a33adfe8211196a96067672ba9cb7accd0ae90523ba60aba861500001976a9143795a62df2eb953c1d08bc996d4089ee5d67e28b88ac14b33f2231f0df567e0dfb12899c893f5d2d05f6dcc7d9c8c27b68a71191c75400"];
    UInt256 txId = *(UInt256 *)@"8f3368ceb332bdb8587fbeb540ad3bbf6f1c6c5a3f85c4e49f5f93351e4979e0".hexToData.reverse.bytes;
    UInt256 inputId = *(UInt256 *)@"d32687ec23f0e91fc1c797b508f8755f488c6e49892adef75be77ce395fe393f".hexToData.reverse.bytes;
    NSString * inputAddress0 = @"yRdHYt6nG1ooGaXK7GEbwVMteLY3m4FbVT";
    NSString * inputAddress1 = @"yWJqVcT5ot5GEcB8oYkHnnYcFG5pLiVVtd";
    NSString * inputAddress2 = @"ygQ8tG3tboQ7oZEhtDBBYtquTmVyiDe6d5";
    DSECDSAKey * inputPrivateKey0 = [wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
    DSECDSAKey * inputPrivateKey1 = [wallet privateKeyForAddress:inputAddress1 fromSeed:seed];
    DSECDSAKey * inputPrivateKey2 = [wallet privateKeyForAddress:inputAddress2 fromSeed:seed];
    
    NSString * checkInputAddress0 = [inputPrivateKey0 addressForChain:chain];
    XCTAssertEqualObjects(checkInputAddress0,inputAddress0,@"Private key does not match input address");
    
    NSString * checkInputAddress1 = [inputPrivateKey1 addressForChain:chain];
    XCTAssertEqualObjects(checkInputAddress1,inputAddress1,@"Private key does not match input address");
    
    NSString * checkInputAddress2 = [inputPrivateKey2 addressForChain:chain];
    XCTAssertEqualObjects(checkInputAddress2,inputAddress2,@"Private key does not match input address");
    
    DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:wallet];
    if (!providerFundsDerivationPath.hasExtendedPublicKey) {
        [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:wallet];
    if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
        [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:wallet];
    if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
        [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:nil];
    }
    
    NSString * holdingAddress = [providerFundsDerivationPath receiveAddress];
    
    DSECDSAKey * ownerKey = [providerOwnerKeysDerivationPath firstUnusedPrivateKeyFromSeed:seed];
    UInt160 votingKeyHash = providerVotingKeysDerivationPath.firstUnusedPublicKey.hash160;
    UInt384 operatorKey = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
    
    DSProviderRegistrationTransaction *providerRegistrationTransactionFromMessage = [[DSProviderRegistrationTransaction alloc] initWithMessage:hexData onChain:chain];
    
    XCTAssertEqualObjects(providerRegistrationTransactionFromMessage.toData,hexData,@"Provider transaction does not match it's data");
    
    //    NSMutableData * scriptPayout = [NSMutableData data];
    //    [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:wallet.chain];
    //
    //    UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
    //    struct in_addr addrV4;
    //    if (inet_aton([@"1.1.1.1" UTF8String], &addrV4) != 0) {
    //        uint32_t ip = ntohl(addrV4.s_addr);
    //        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
    //    }
    //
    //    DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@1] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0] outputAmounts:@[@498999700] providerRegistrationTransactionVersion:1 type:0 mode:0 ipAddress:ipAddress port:19999 ownerKeyHash:ownerKey.publicKey.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:wallet.chain];
    //
    //    NSMutableData *script = [NSMutableData data];
    //
    //    [script appendScriptPubKeyForAddress:holdingAddress forChain:fundingAccount.wallet.chain];
    //    [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[script] withFee:YES isInstant:NO toShapeshiftAddress:nil shuffleOutputOrder:NO];
    //
    //
    //    [providerRegistrationTransaction updateInputsHash];
    //
    //    [providerRegistrationTransaction signPayloadWithKey:ownerKey];
    //
    //    XCTAssertEqualObjects(providerRegistrationTransaction.toData,hexData,@"Provider transaction does not match it's data");
    
    //    DSProviderRegistrationTransaction *blockchainUserRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@1] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0] outputAmounts:@[@498999700] blockchainUserRegistrationTransactionVersion:1 username:@"samisfun" pubkeyHash:pubkeyHash topupAmount:1000000 topupIndex:0 onChain:devnetDRA];
    //    [blockchainUserRegistrationTransaction signPayloadWithKey:payloadKey];
    //    NSData * payloadDataToConfirm = @"01000873616d697366756ec3bfec8ca49279bb1375ad3461f654ff1a277d464120f19af9563ef387fef19c82bc4027152ef5642fe8158ffeb3b8a411d9a967b6af0104b95659106c8a9d7451478010abe042e58afc9cdaf006f77cab16edcb6f84".hexToData;
    //    NSData * payloadData = blockchainUserRegistrationTransaction.payloadData;
    //    XCTAssertEqualObjects(payloadData,payloadDataToConfirm,@"Payload Data does not match, signing payload does not work");
    //
    //    [blockchainUserRegistrationTransaction signWithSerializedPrivateKeys:@[inputPrivateKey]];
    //    NSData * inputSignature = @"473044022033bafeac5704355c7855a6ad099bd6834cbcf3b052e42ed83945c58aae904aa4022073e747d376a8dcd2b5eb89fef274b01c0194ee9a13963ebbc657963417f0acf3012102393c140e7b53f3117fd038581ae66187c4be33f49e33a4c16ffbf2db1255e985".hexToData;
    //    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.inputSignatures[0],inputSignature,@"The transaction input signature isn't signing correctly");
    //
    //
    //    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.data,hexData,@"The transaction data does not match it's expected values");
    //    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:blockchainUserRegistrationTransaction.txHash],@"The transaction does not match it's desired private key");
}


/*
 -(void)testProviderUpdateServiceTransaction {
 DSChain * chain = [DSChain testnet];
 
 NSString * seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";
 
 NSData * seed = [[DSBIP39Mnemonic sharedInstance]
 deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
 
 DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
 
 NSData * hexData = [NSData dataFromHexString:@"03000200018f3fe6683e36326669b6e34876fb2a2264e8327e822f6fec304b66f47d61b3e1010000006b48304502210082af6727408f0f2ec16c7da1c42ccf0a026abea6a3a422776272b03c8f4e262a022033b406e556f6de980b2d728e6812b3ae18ee1c863ae573ece1cbdf777ca3e56101210351036c1192eaf763cd8345b44137482ad24b12003f23e9022ce46752edf47e6effffffff0180220e43000000001976a914123cbc06289e768ca7d743c8174b1e6eeb610f1488ac00000000b501003a72099db84b1c1158568eec863bea1b64f90eccee3304209cebe1df5e7539fd00000000000000000000ffff342440944e1f00e6725f799ea20480f06fb105ebe27e7c4845ab84155e4c2adf2d6e5b73a998b1174f9621bbeda5009c5a6487bdf75edcf602b67fe0da15c275cc91777cb25f5fd4bb94e84fd42cb2bb547c83792e57c80d196acd47020e4054895a0640b7861b3729c41dd681d4996090d5750f65c4b649a5cd5b2bdf55c880459821e53d91c9"];
 NSString * inputAddress0 = @"yhmDZGmiwjCPJrTFFiBFZJw31PhvJFJAwq";
 DSKey * inputPrivateKey0 = [wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
 
 NSString * checkInputAddress0 = [inputPrivateKey0 addressForChain:chain];
 XCTAssertEqualObjects(checkInputAddress0,inputAddress0,@"Private key does not match input address");
 
 DSProviderUpdateServiceTransaction *providerUpdateServiceTransactionFromMessage = [[DSProviderUpdateServiceTransaction alloc] initWithMessage:hexData onChain:chain];
 
 XCTAssertEqualObjects(providerUpdateServiceTransactionFromMessage.toData,hexData,@"Provider update service transaction does not match it's data");
 
 DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
 if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
 [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:wallet.uniqueID];
 }
 
 UInt256 operatorSecretKey = [NSData dataFromHexString:@"1708c6585cd2ffde4cddd742670eac14a713ae94b2c00b9b2d25fbf4d654ad12"].UInt256;
 
 DSBLSKey * privateKey = [DSBLSKey blsKeyWithPrivateKey:operatorSecretKey onChain:chain];
 
 UInt384 operatorKeyNeeded =[NSData dataFromHexString:@"8b782ebfd2f70b976b6aa149cc4437824a823d526380817614906c9f98943a8b7f0856d1552a7045ec47eefcd116894e"].UInt384;
 
 UInt384 operatorKey = privateKey.publicKey;
 
 XCTAssertTrue(uint384_eq(operatorKey, operatorKeyNeeded),@"operator keys don't match");
 
 UInt384 operatorKeyFromDerivation = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
 
 XCTAssertEqualObjects([NSData dataWithUInt384:operatorKey], [NSData dataWithUInt384:operatorKeyFromDerivation],@"operator keys don't match");
 
 XCTAssertTrue(uint384_eq(operatorKeyFromDerivation, operatorKeyNeeded),@"operator keys don't match");
 
 DSBLSKey * operatorBLSKey = [DSBLSKey blsKeyWithPublicKey:operatorKey onChain:chain];
 
 UInt256 payloadHash = providerUpdateServiceTransactionFromMessage.payloadDataForHash.SHA256_2;
 
 UInt768 signatureFromDigest = [privateKey signDigest:payloadHash];
 
 UInt768 signatureFromData = [privateKey signData:providerUpdateServiceTransactionFromMessage.payloadDataForHash];
 
 XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], [NSData dataWithUInt768:signatureFromData],@"payload signature doesn't match");
 
 XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], providerUpdateServiceTransactionFromMessage.payloadSignature,@"payload signature doesn't match");
 
 NSData * payloadSignature = providerUpdateServiceTransactionFromMessage.payloadSignature;
 
 BOOL verified = [privateKey verify:payloadHash signature:signatureFromData];
 
 XCTAssertTrue(verified,@"The signature is not signed correctly");
 
 XCTAssertTrue([providerUpdateServiceTransactionFromMessage checkPayloadSignature:operatorBLSKey],@"The payload is not signed correctly");
 
 //    NSMutableData * scriptPayout = [NSMutableData data];
 //    [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:wallet.chain];
 //
 //    UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
 //    struct in_addr addrV4;
 //    if (inet_aton([@"1.1.1.2" UTF8String], &addrV4) != 0) {
 //        uint32_t ip = ntohl(addrV4.s_addr);
 //        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
 //    }
 //
 //    DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@1] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0] outputAmounts:@[@498999700] providerRegistrationTransactionVersion:1 type:0 mode:0 ipAddress:ipAddress port:19999 ownerKeyHash:ownerKey.publicKey.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:wallet.chain];
 //
 //    NSMutableData *script = [NSMutableData data];
 //
 //    [script appendScriptPubKeyForAddress:holdingAddress forChain:fundingAccount.wallet.chain];
 //    [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[script] withFee:YES isInstant:NO toShapeshiftAddress:nil shuffleOutputOrder:NO];
 //
 //
 //    [providerRegistrationTransaction updateInputsHash];
 //
 //    [providerRegistrationTransaction signPayloadWithKey:ownerKey];
 //
 //    XCTAssertEqualObjects(providerRegistrationTransaction.toData,hexData,@"Provider transaction does not match it's data");
 }*/


//-(void)testProviderUpdateRegistrarTransaction {
//    DSChain * chain = [DSChain testnet];
//
//    NSString * seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";
//
//    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
//                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
//
//    DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
//
//    NSData * hexData = [NSData dataFromHexString:@"0300030001e2cfc5ba74b3c26d4d4e4bb010b676092a314d33fb007315ed88eb54ac37173c000000006a47304402202d588c47bf63948d3a7640e83d0aac9e7267ca630faa1dbaeddd4ee1a04f9c350220515c79165a64db6a6e501b149e1d9b5a23b1902b83eec69ff50ff28e8036c2710121029bce432130b30421ddc26b2281fa4f5acad0d3e6fa14f382e9bc031e82fd676dffffffff011f89a95a020000001976a9148bdba067dbb6ec9a74a655f91c8d6ea7c1f2a89688ac00000000e4010051f9d127275f3f8c1947a4f1067d9a02d6f97d4969be727b533ad6ad5286e7d70000859bdc161a8a246a572cbc0c1928faacecbc12133b64f18480a32938eec081129016e99929caea89f317a33adfe8211196a96067672ba9cb7accd0ae90523ba60aba86151976a914eb3a5c66df4f5a99250af6090192115a04b7414088ac1368c5e52a7e3ab0676cd61d09e1054036d9ea66f61c53c68b89ba310c7d035b411f6e5d8a86d2928ef45ea70bbf1f15b9d69690d3ee3afeec373bfae5745f816ac531239ec7c6c94f2511dd6c12d077df90dc3bbcf76576a2c8ebb3363bb4e9f094"];
//    UInt256 txId = *(UInt256 *)@"bc2056e345f921d161a167f29adec1492496968511cbd60e5139b45dd3d512f8".hexToData.reverse.bytes;
//
//    DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransactionFromMessage = [[DSProviderUpdateRegistrarTransaction alloc] initWithMessage:hexData onChain:chain];
//
//    XCTAssertEqualObjects([NSData dataWithUInt256:txId], [NSData dataWithUInt256:providerUpdateRegistrarTransactionFromMessage.txHash]);
//
//    XCTAssertEqualObjects(providerUpdateRegistrarTransactionFromMessage.toData,hexData,@"Provider update registrar transaction does not match it's data");
//
//    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
//    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
//        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:wallet.uniqueID];
//    }
//
//    UInt256 operatorSecretKey = [NSData dataFromHexString:@"17b47bb0f2a3298ee8f9d07fdafc1e8552869d11cef81e13a2706e2fdbf50dc5"].UInt256;
//
//    DSBLSKey * privateKey = [DSBLSKey blsKeyWithPrivateKey:operatorSecretKey onChain:chain];
//
//    UInt384 operatorKeyNeeded =[NSData dataFromHexString:@"859bdc161a8a246a572cbc0c1928faacecbc12133b64f18480a32938eec081129016e99929caea89f317a33adfe82111"].UInt384;
//
//    UInt384 operatorKey = privateKey.publicKey;
//
//    XCTAssertTrue(uint384_eq(operatorKey, operatorKeyNeeded),@"operator keys don't match");
//
//    UInt384 operatorKeyFromDerivation = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
//
//    XCTAssertEqualObjects([NSData dataWithUInt384:operatorKey], [NSData dataWithUInt384:operatorKeyFromDerivation],@"operator keys don't match");
//
//    XCTAssertTrue(uint384_eq(operatorKeyFromDerivation, operatorKeyNeeded),@"operator keys don't match");
//
//    DSBLSKey * operatorBLSKey = [DSBLSKey blsKeyWithPublicKey:operatorKey onChain:chain];
//
//    UInt256 payloadHash = providerUpdateRegistrarTransactionFromMessage.payloadDataForHash.SHA256_2;
//
//    UInt768 signatureFromDigest = [privateKey signDigest:payloadHash];
//
//    UInt768 signatureFromData = [privateKey signData:providerUpdateRegistrarTransactionFromMessage.payloadDataForHash];
//
//    XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], [NSData dataWithUInt768:signatureFromData],@"payload signature doesn't match");
//
//    XCTAssertEqualObjects([NSData dataWithUInt768:signatureFromDigest], providerUpdateRegistrarTransactionFromMessage.payloadSignature,@"payload signature doesn't match");
//
//    NSData * payloadSignature = providerUpdateRegistrarTransactionFromMessage.payloadSignature;
//
//    BOOL verified = [privateKey verify:payloadHash signature:signatureFromData];
//
//    XCTAssertTrue(verified,@"The signature is not signed correctly");
//
//    XCTAssertTrue([providerUpdateRegistrarTransactionFromMessage checkPayloadSignature:operatorBLSKey],@"The payload is not signed correctly");
//
//}

@end
