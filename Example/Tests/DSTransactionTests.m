//
//  DSTransactionTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

@interface DSTransactionTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSTransactionTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testTransaction

- (void)testTransaction
{
    NSMutableData *script = [NSMutableData data];
    UInt256 secret = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
    DSECDSAKey *k = [DSECDSAKey keyWithSecret:secret compressed:YES];
    NSValue *hash = uint256_obj(UINT256_ZERO);
    
    [script appendScriptPubKeyForAddress:[k addressForChain:self.chain] forChain:self.chain];
    
    DSTransaction *tx = [[DSTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@0] inputScripts:@[script]
                                                   outputAddresses:@[[k addressForChain:self.chain], [k addressForChain:self.chain]] outputAmounts:@[@100000000, @4900000000]
                                                           onChain:self.chain];
    
    [tx signWithPrivateKeys:@[[k privateKeyStringForChain:self.chain]]];
    
    XCTAssertTrue([tx isSigned], @"[DSTransaction signWithPrivateKeys:]");
    
    NSData *d = tx.data;
    
    tx = [DSTransaction transactionWithMessage:d onChain:self.chain];
    
    XCTAssertEqualObjects(d, tx.data, @"[DSTransaction transactionWithMessage:]");
    
    NSString *address = [k addressForChain:self.chain];
    
    tx = [[DSTransaction alloc] initWithInputHashes:@[hash, hash, hash, hash, hash, hash, hash, hash, hash, hash]
                                       inputIndexes:@[@0, @0,@0, @0, @0, @0, @0, @0, @0, @0]
                                       inputScripts:@[script, script, script, script, script, script, script, script, script, script]
                                    outputAddresses:@[address, address, address, address, address, address, address, address,
                                                      address, address]
                                      outputAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                                                      @1000000]
                                            onChain:self.chain];
    
    [tx signWithPrivateKeys:@[[k privateKeyStringForChain:self.chain]]];
    
    XCTAssertTrue([tx isSigned], @"[DSTransaction signWithPrivateKeys:]");
    
    d = tx.data;
    tx = [DSTransaction transactionWithMessage:d onChain:self.chain];
    
    XCTAssertEqualObjects(d, tx.data, @"[DSTransaction transactionWithMessage:]");
}

- (void)testBlockchainUserTransactionPayload {
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    DSECDSAKey * key = [DSECDSAKey keyWithPrivateKey:@"cTu5paPRRZ1bby6XPR9oLmJ8XsasXm699xVCMGJuEVFu7qaU8uS5" onChain:devnetDRA];
    UInt160 pubkeyHash = *(UInt160 *)@"43bfdea7363e6ea738da5059987c7232b58d2afe".hexToData.bytes;
    
    XCTAssertTrue(uint160_eq(pubkeyHash, key.publicKeyData.hash160), @"Pubkey Hash does not Pubkey");
    DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:@"crazy2" pubkeyHash:pubkeyHash onChain:devnetDRA];
    UInt256 payloadHash = blockchainUserRegistrationTransaction.payloadHash;
    NSData * payloadHashDataToConfirm = @"b29e4bc3dd4e0a02d163599e3be5a315781d1ef9e25ec9767eabbe3bfc250af5".hexToData.reverse;
    XCTAssertEqualObjects([NSData dataWithUInt256:payloadHash],payloadHashDataToConfirm,@"Pubkey Hash does not match Pubkey Reverse");
}

- (void)testClassicalTransactionInputs {
    //this is for v2 transaction versions
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    NSData * hexData = [NSData dataFromHexString:@"02000000017d2e890a1edf2a9d44f188f4240b47ba582544b633f910da586e3db119695ece010000006b483045022100f14abf17d7888547aaf2d933b3af58c1ef9a9d9bc740e75b4cd1ba675acbbe59022061a60a1a3051627dc26ab7da64d42cb9fe3c67c1429b91b404dc0a283f8381e0012103c7d6b1387a94de54004904ba39f41e8722984256a7e26f9e1285724e12fa259afeffffff0200e87648170000001976a914dcf5b8abf6e222dea0219f4e3b539fa9b6addcfa88ac1e477835a30200001976a914f2ef7a87a09aadd215be821ddfcb922fa099f64f88acb5060000"];
    UInt256 txId = *(UInt256 *)@"e8754d7ce9575d123ad6e130c3a4a14b36b5585c5caa82f929b4b2527d265a2d".hexToData.reverse.bytes;
    UInt256 inputId = *(UInt256 *)@"ce5e6919b13d6e58da10f933b6442558ba470b24f488f1449d2adf1e0a892e7d".hexToData.reverse.bytes;
    NSString * inputAddress = @"yaMmAV9Fmx4St7xPH9eHCLcYJZdGYd8vD8";
    NSString * inputPrivateKey = @"cNeRqjZpEEowdxMjiBa7S5uBgqweng19F1EZRFWcqE2XTpDy1Vzt";
    DSECDSAKey * privateKey = [DSECDSAKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];
    NSString * checkInputAddress = [privateKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkInputAddress,inputAddress,@"Private key does not match input address");
    NSString * outputAddress0 = @"ygTmsRfjDQ8c8UDny2uU8gafAeFAKP6G1g";
    NSString * outputAddress1 = @"yiTyFtkZVCrEvmANHoj9rJQ2VA9HBnYTgp";
    NSMutableData *script = [NSMutableData data];
    
    NSValue *hash = uint256_obj(inputId);
    
    [script appendScriptPubKeyForAddress:inputAddress forChain:devnetDRA];
    
    DSTransaction *tx = [[DSTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@1] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0, outputAddress1] outputAmounts:@[@100000000000, @2899999999774]
                                                           onChain:devnetDRA];
    tx.version = 2;
    tx.lockTime = 1717;
    [tx signWithPrivateKeys:@[inputPrivateKey]];
    XCTAssertEqualObjects(tx.data,hexData,@"The transaction data does not match it's expected values");
    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:tx.txHash],@"The transaction does not match it's desired private key");
}

-(void)testCoinbaseTransaction {
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
        NSData * hexData = [NSData dataFromHexString:@"03000500010000000000000000000000000000000000000000000000000000000000000000ffffffff0502f6050105ffffffff0200c11a3d050000002321038df098a36af5f1b7271e32ad52947f64c1ad70c16a8a1a987105eaab5daa7ad2ac00c11a3d050000001976a914bfb885c89c83cd44992a8ade29b610e6ddf00c5788ac00000000260100f6050000aaaec8d6a8535a01bd844817dea1faed66f6c397b1dcaec5fe8c5af025023c35"];
    NSData * txIdData = @"5b4e5e99e967e01e27627621df00c44525507a31201ceb7b96c6e1a452e82bef".hexToData.reverse;
    DSCoinbaseTransaction * coinbaseTransaction = [[DSCoinbaseTransaction alloc] initWithMessage:hexData onChain:devnetDRA];
    XCTAssertEqualObjects(coinbaseTransaction.toData,hexData,@"Coinbase transaction does not match it's data");
    XCTAssertEqualObjects([NSData dataWithUInt256:coinbaseTransaction.txHash],txIdData,@"Coinbase transaction hash does not match it's data dash");
}

- (void)testCreateBlockchainUserTransactionInputs {
    //this is for v3 transaction versions
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    NSData * hexData = [NSData dataFromHexString:@"03000800013f39fe95e37ce75bf7de2a89496e8c485f75f808b597c7c11fe9f023ec8726d3010000006a473044022033bafeac5704355c7855a6ad099bd6834cbcf3b052e42ed83945c58aae904aa4022073e747d376a8dcd2b5eb89fef274b01c0194ee9a13963ebbc657963417f0acf3012102393c140e7b53f3117fd038581ae66187c4be33f49e33a4c16ffbf2db1255e985feffffff0240420f0000000000016a9421be1d000000001976a9145f461d2cdae3e8244c6dbc6de58ad06ccd22890388ac000000006101000873616d697366756ec3bfec8ca49279bb1375ad3461f654ff1a277d464120f19af9563ef387fef19c82bc4027152ef5642fe8158ffeb3b8a411d9a967b6af0104b95659106c8a9d7451478010abe042e58afc9cdaf006f77cab16edcb6f84"];
    UInt256 txId = *(UInt256 *)@"8f3368ceb332bdb8587fbeb540ad3bbf6f1c6c5a3f85c4e49f5f93351e4979e0".hexToData.reverse.bytes;
    UInt256 inputId = *(UInt256 *)@"d32687ec23f0e91fc1c797b508f8755f488c6e49892adef75be77ce395fe393f".hexToData.reverse.bytes;
    NSString * inputAddress = @"yeXaNd6esFX83gNsqVW7y43SVMqtvygcRT";
    NSString * inputPrivateKey = @"cQv3B1Ww5GkTDEAmA4KaZ7buGXsoUKTBmLLc79PVM5J6qLQc4wqj";
    DSECDSAKey * privateKey = [DSECDSAKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];

    NSString * checkInputAddress = [privateKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkInputAddress,inputAddress,@"Private key does not match input address");
    
    DSECDSAKey * payloadKey = [DSECDSAKey keyWithPrivateKey:@"cVBJqSygvC7hHQVuarUZQv868NgHUavceAfeqgo32LYiBYYswTv6" onChain:devnetDRA];
    NSString * payloadAddress = @"yeAUXizK9bD6iuxaArDsh7XGX3Q75ZgE3Y";
    UInt160 pubkeyHash = *(UInt160 *)@"467d271aff54f66134ad7513bb7992a48cecbfc3".hexToData.reverse.bytes;
    NSString * checkPayloadAddress = [payloadKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkPayloadAddress,payloadAddress,@"Payload key does not match input address");
    
    NSString * outputAddress0 = @"yV1D32jV3duqeBGqWtjjevQk7ikHuitzK4";
    NSMutableData *script = [NSMutableData data];
    
    NSValue *hash = uint256_obj(inputId);
    
    [script appendScriptPubKeyForAddress:inputAddress forChain:devnetDRA];
    
    DSBlockchainUserRegistrationTransaction *blockchainUserRegistrationTransactionFromMessage = [[DSBlockchainUserRegistrationTransaction alloc] initWithMessage:hexData onChain:devnetDRA];
    
    XCTAssertEqualObjects(blockchainUserRegistrationTransactionFromMessage.toData,hexData,@"Blockchain user transaction does not match it's data");
    
    DSBlockchainUserRegistrationTransaction *blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@1] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0] outputAmounts:@[@498999700] blockchainUserRegistrationTransactionVersion:1 username:@"samisfun" pubkeyHash:pubkeyHash topupAmount:1000000 topupIndex:0 onChain:devnetDRA];
    [blockchainUserRegistrationTransaction signPayloadWithKey:payloadKey];
    NSData * payloadDataToConfirm = @"01000873616d697366756ec3bfec8ca49279bb1375ad3461f654ff1a277d464120f19af9563ef387fef19c82bc4027152ef5642fe8158ffeb3b8a411d9a967b6af0104b95659106c8a9d7451478010abe042e58afc9cdaf006f77cab16edcb6f84".hexToData;
    NSData * payloadData = blockchainUserRegistrationTransaction.payloadData;
    XCTAssertEqualObjects(payloadData,payloadDataToConfirm,@"Payload Data does not match, signing payload does not work");
    
    [blockchainUserRegistrationTransaction signWithPrivateKeys:@[inputPrivateKey]];
    NSData * inputSignature = @"473044022033bafeac5704355c7855a6ad099bd6834cbcf3b052e42ed83945c58aae904aa4022073e747d376a8dcd2b5eb89fef274b01c0194ee9a13963ebbc657963417f0acf3012102393c140e7b53f3117fd038581ae66187c4be33f49e33a4c16ffbf2db1255e985".hexToData;
    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.inputSignatures[0],inputSignature,@"The transaction input signature isn't signing correctly");

    
    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.data,hexData,@"The transaction data does not match it's expected values");
    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:blockchainUserRegistrationTransaction.txHash],@"The transaction does not match it's desired private key");
}

- (void)testTopupBlockchainUserTransactionInputs {
    //this is for v3 transaction versions
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    NSData * hexData = [NSData dataFromHexString:@"0300090001d4ad073ec40da120d28a47164753f4f5ad80d0dc3b918b39223d36ebdfacdef6000000006b483045022100a65429d4f2ab2df58cafdaaffe874ef260f610e068e89a4455fbf92261156bb7022015733ae5aef3006fd5781b91f97ca1102edf09e9383ca761e407c619d13db7660121034c1f31446c5971558b9027499c3678483b0deb06af5b5ccd41e1f536af1e34cafeffffff0200e1f50500000000016ad2d327cc050000001976a9141eccbe2508c7741d2e4c517f87565e7d477cfbbc88ac000000002201002369fced72076b33e25c5ca31efb605037e3377c8e1989eb9ec968224d5e22b4"];
    UInt256 txId = *(UInt256 *)@"715f96a80e0e4feb8a94f2e9f4f6821dd4502f0ae6c43013ec6e77985d059b55".hexToData.reverse.bytes;
    UInt256 blockchainUserRegistrationTransactionHash = *(UInt256 *)@"b4225e4d2268c99eeb89198e7c37e3375060fb1ea35c5ce2336b0772edfc6923".hexToData.reverse.bytes;
    UInt256 inputId = *(UInt256 *)@"f6deacdfeb363d22398b913bdcd080adf5f4534716478ad220a10dc43e07add4".hexToData.reverse.bytes;
    NSString * inputAddress = @"yYZqfmQhqMSF1PL7xeNHzQM3q9rktXFPLN";
    NSString * inputPrivateKey = @"cNYPkC4hGoE11ieBr2GgwyUct8zY1HLi5S5K2LLPMewtQGJsbu9H";
    DSECDSAKey * privateKey = [DSECDSAKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];
    
    NSString * checkInputAddress = [privateKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkInputAddress,inputAddress,@"Private key does not match input address");
    
    NSString * outputAddress0 = @"yP8JPjWoc2u8rSN6F4eE5FQn3nQiQJ9jDs";
    NSMutableData *script = [NSMutableData data];
    
    NSValue *hash = uint256_obj(inputId);
    
    [script appendScriptPubKeyForAddress:inputAddress forChain:devnetDRA];
    
    DSBlockchainUserTopupTransaction *blockchainUserTopupTransactionFromMessage = [[DSBlockchainUserTopupTransaction alloc] initWithMessage:hexData onChain:devnetDRA];
    
    XCTAssertEqualObjects(blockchainUserTopupTransactionFromMessage.toData,hexData,@"Blockchain user topup transaction does not match it's data");
    
    DSBlockchainUserTopupTransaction *blockchainUserTopupTransaction = [[DSBlockchainUserTopupTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@0] inputScripts:@[script] inputSequences:@[@(TXIN_SEQUENCE - 1)] outputAddresses:@[outputAddress0] outputAmounts:@[@24899998674] blockchainUserTopupTransactionVersion:1 registrationTransactionHash:blockchainUserRegistrationTransactionHash topupAmount:100000000 topupIndex:0 onChain:devnetDRA];
    
    [blockchainUserTopupTransaction signWithPrivateKeys:@[inputPrivateKey]];

    NSData * inputSignature = @"483045022100a65429d4f2ab2df58cafdaaffe874ef260f610e068e89a4455fbf92261156bb7022015733ae5aef3006fd5781b91f97ca1102edf09e9383ca761e407c619d13db7660121034c1f31446c5971558b9027499c3678483b0deb06af5b5ccd41e1f536af1e34ca".hexToData;
    XCTAssertEqualObjects(blockchainUserTopupTransaction.inputSignatures[0],inputSignature,@"The transaction input signature isn't signing correctly");
    
    
    XCTAssertEqualObjects(blockchainUserTopupTransaction.data,hexData,@"The transaction data does not match it's expected values");
    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:blockchainUserTopupTransaction.txHash],@"The transaction does not match it's desired private key");
}

- (void)testResetBlockchainUserTransactionInputs {
    //this is for v3 transaction versions
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    NSData * hexData = [NSData dataFromHexString:@"03000a00000000000000a00100659c3243efcab7813a06664582300960844dc291988b1510afac99efa001370d659c3243efcab7813a06664582300960844dc291988b1510afac99efa001370de803000000000000f6f5abf4ba75c554b9ef001a78c35ce5edb3ccb1411fd442ee3bb6dac571f432e56def3d06f64a15cc74f382184ca4d5d4cad781ced01ae4e8109411f548da5c5fa6bfce5a23a8d620104e6953600539728b95077e19"];
    UInt256 txId = *(UInt256 *)@"251961000a115bafbb7bdb6e1baf23d88e37ecf2fe6af5d9572884cabaecdcc0".hexToData.reverse.bytes;
    UInt256 blockchainUserRegistrationTransactionHash = *(UInt256 *)@"0d3701a0ef99acaf10158b9891c24d84600930824566063a81b7caef43329c65".hexToData.reverse.bytes;
    UInt256 blockchainUserPreviousTransactionHash = *(UInt256 *)@"0d3701a0ef99acaf10158b9891c24d84600930824566063a81b7caef43329c65".hexToData.reverse.bytes;
    
    DSECDSAKey * payloadKey = [DSECDSAKey keyWithPrivateKey:@"cVxAzue29NemggDqJyUwMsZ7KJsm4y9ntoW5UeCaTfQdruH2BKQR" onChain:devnetDRA];
    NSString * payloadAddress = @"yfguWspuwx7ceKthnqqDc8CiZGZGRN7eFp";
    NSString * checkPayloadAddress = [payloadKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkPayloadAddress,payloadAddress,@"Payload key does not match input address");
    
    DSECDSAKey * replacementPayloadKey = [DSECDSAKey keyWithPrivateKey:@"cPG7GuByFnYkGvkrZqw8chGNfJYmKYnXt6TBjHruaApC42CPwwTE" onChain:devnetDRA];
    NSString * replacementPayloadAddress = @"yiqFNxn9kbWEKj7B87aEnoyChBL8rMFymt";
    UInt160 replacementPubkeyHash = *(UInt160 *)@"b1ccb3ede55cc3781a00efb954c575baf4abf5f6".hexToData.reverse.bytes;
    NSString * replacementCheckPayloadAddress = [replacementPayloadKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(replacementCheckPayloadAddress,replacementPayloadAddress,@"Replacement payload key does not match input address");
    
    DSBlockchainUserResetTransaction *blockchainUserResetTransactionFromMessage = [[DSBlockchainUserResetTransaction alloc] initWithMessage:hexData onChain:devnetDRA];
    
    XCTAssertEqualObjects(blockchainUserResetTransactionFromMessage.toData,hexData,@"Blockchain user reset transaction does not match it's data");
    
    DSBlockchainUserResetTransaction *blockchainUserResetTransaction = [[DSBlockchainUserResetTransaction alloc] initWithInputHashes:@[] inputIndexes:@[] inputScripts:@[] inputSequences:@[] outputAddresses:@[] outputAmounts:@[] blockchainUserResetTransactionVersion:1 registrationTransactionHash:blockchainUserRegistrationTransactionHash previousBlockchainUserTransactionHash:blockchainUserPreviousTransactionHash replacementPublicKeyHash:replacementPubkeyHash creditFee:1000 onChain:devnetDRA];

    [blockchainUserResetTransaction signPayloadWithKey:payloadKey];
    NSData * payloadDataToConfirm = @"0100659c3243efcab7813a06664582300960844dc291988b1510afac99efa001370d659c3243efcab7813a06664582300960844dc291988b1510afac99efa001370de803000000000000f6f5abf4ba75c554b9ef001a78c35ce5edb3ccb1411fd442ee3bb6dac571f432e56def3d06f64a15cc74f382184ca4d5d4cad781ced01ae4e8109411f548da5c5fa6bfce5a23a8d620104e6953600539728b95077e19".hexToData;
    NSData * payloadData = blockchainUserResetTransaction.payloadData;
    XCTAssertEqualObjects(payloadData,payloadDataToConfirm,@"Payload Data does not match, signing payload does not work");


    XCTAssertEqualObjects(blockchainUserResetTransaction.data,hexData,@"The transaction data does not match it's expected values");
    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:blockchainUserResetTransaction.txHash],@"The transaction does not match it's desired private key");
}


- (void)testInstantSendReceiveTransaction {
    DSChain * chain = [DSChain testnet];
    DSChainManager * chainManager = [[DSChainsManager sharedInstance] testnetManager];
    NSMutableArray * lockVotes = [NSMutableArray array];
    
    //set up wallet
    [DSWallet standardWalletWithSeedPhrase:@"pigeon social employ east owner purpose buddy proof soul suit pumpkin punch" setCreationDate:1548241200 forChain:chain storeSeedPhrase:YES isTransient:NO]; //block 30000 creation date, needed to be 
    
    DSPeer * peer = [DSPeer peerWithHost:@"0.0.0.0:19999" onChain:chain];
    
    [chainManager.transactionManager transactionsBloomFilterForPeer:peer];
    
    [chainManager.transactionManager peer:peer relayedBlock:[[DSMerkleBlock alloc] initWithMessage:@"00000020df8e487cd0f6ec7faca45eff3e2eb0285e1d796cbe8f94a51bc435070000000098284ae3f308a1509f41bc3f14aa01a65d9194ab9caa4c5cb5da158fc6d3ca0a4c5b325cd788001d44212611020000000198284ae3f308a1509f41bc3f14aa01a65d9194ab9caa4c5cb5da158fc6d3ca0a0100".hexToData onChain:chain]];
    
    //this sets up the masternodes
    [chainManager.masternodeManager peer:peer relayedMasternodeDiffMessage:@"000000000000000000000000000000000000000000000000000000000000000022d5bf67e30bb3c7f497d6ead9f7e8803ae864a94b2d9f764f18bd6c0000000002000000026f8f95ad8722b2ec5b74ed1a9c59809e880e784e812a965d4e06ff8060c149854746bf8d4b01d6381894f474441cc809fdc56b0547da13edaaebfa6db8d9e901010303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff4b022d4c044c5b325c08fabe6d6d6849584ead174973736170747365743a7265737574736574bff442981ec682dd010000000000000010000015830200000d2f6e6f64655374726174756d2f000000000240eff0db000000001976a914cb594917ad4e5849688ec63f29a0f7f3badb5da688ac36eff0db000000001976a914a3c5284d3cd896815ac815f2dd76a3a71cb3d8e688ac000000002601002d4c0000c641f22365820780103ede43304a645b6424c31f6399c78c48cb5737a86f3b95007442911ec289c2b1559009f988cbfa48a36f606c0aa37c4c6e6b536ab0a9d9eca178ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff3f21ee554e4e08b32c435d28b26ea4c42089edacadaf8016651931f22a8273feedc3f535592f2ea709aa3bf87f9e751073cf05b82aac3cf9e251ef3f1147f64a3af6c29319eb326385bf01d8fdcb15669878b5acccb5eca394ff513908ed5fc3cf44bb1648552cb0b287f424a70b898084eb8f9a1b6f4b0e93f4736f6866f1c4e5c2b8bf861f040000000000000000000000000000ffffad3d1ee74a3f07f818e5c2330ac4e7f0ef820f337addf8ab28b07c9d451304d807feda1d764c7074bccbbd941284b0d0276a96cf5e7f4410220b95991383f29942bb02510c07de9c58c00120ba3f10dc821c8a929aeb9a32e98339fc2f7a3d64b705129777c9a39780a01e3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3f21ee554e26983c80e3e31fea6f3d56d54059e8c95a467285f33914182f1e274616cdbe2f1e1c6c0c7dce13710480ec4658208e9392fdf9ff7c06cbf660a2c93d466d5379492eb7334201a01b70e913df11ee62bc4d21eeeea6a540fa5c2cf975952c728be8eed09623733554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e258dfa69a96f23bd77e72c1a00984bb0df5ce93a76ca1d20694e8ad20b1dfea530cb6ee0b964b78ebb2bc8bfac22f61647e19574f5e7b2fa793c90eaed6bda49d7559e95d30121958ba1693c76e70a81c354111cc48a50579587329978c563e2e5655991a2a35a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e380a9117edbb85963c1c5fdbcdcaf33483ee37676e8a34c3f8d298418df77bbdf16791821a75354f0a4f2114c090a4798c318a716eb1abea572d94e176aa2df977f73b05ab0141e985aec00b41aac2d42a5c2cca1fd333fb42dea7465930666df9179e341d2b5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e2b8fd425f945936b02a97c8807d20272742d351356bff653f9467ab29b4bdb6f19bdf863ad5a325f63a0080b9dd80037a9b619e80a88b324974c98c90f8c2289c3ca916580010106207e0dbdce8e18a97328eb9e2de99c87477cd0b2ad1b34b4231327fea08b3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e298348757a2ed830f3a40f0e52ca4823f48c1ab5017dc424ee68c1e8fad27c0ab008bc974866db18bc76bc7d2bebb2997695ca25c4c132186aabbf5c7bfa331119a01969f9018167aa267eb42b78d112b3600358ea7679328be8ceecec2cd68148985b6654405a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e3a07e472824512fd8004e7c81c3dff74c72f898c2a25f71246de316f6dbc976fe4e54d103e6276e457c415f53ba867e1d7ce2eeb1be671205ee68db332dd0f4871f549baf101a1d700ddb67ae80c1cb4fdb76dac6484dc1dc2741334ad5e48f78fd08713a13478ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff3432d0354e4d88a5857ea0eb8a5fe369bb672144867c4908300089472108afb9d54a70f7d6e4b339d01509dd9231da90b14cb401df2f007aec84e8af1b8f2da40a74b4d3beeaa8b4734801419aa9fed4f35fcb986c50fbaa0c7555c68f8a9876968c63c6f92064ff06f1fe7b34629e1f9f156e4e3720ed76745a9966adb50fb513f1285263d5050000000000000000000000000000ffff2d30b1de4e1f842476e8d82327adfb9b617a7ac3f62868946c0c4b6b0e365747cfb8825b8b79ba0eb1fa62e8583ae7102f59bf70c7c7ce2342a602ce6bd150809591377ecf31971558ca014172e5a561e36ae49358bc4c6c37ff688f54a05ae8842b496b86feb71f06b886bbaf9ff7a4ffcf3931de9233fa8e151f187bf30235000e3b5fb102b01200000000000000000000000000ffff6deb47384e1f8d1412ff39045ef39c2e19a75cb3ad986afc14c3139ed0a3392b41d471558676029a8137f95b0ba0e7315bf11c497f0fc8270f9d208c75006659cedd927f04ccf829242c012354b77c0f261f3d5b8424cbe67c2f27130f01c531732a08b8ae3f28aaa1b1fbb04a8e207d15ce5d20436e1caa792d46d9dffde499917d6b958f98102900000000000000000000000000ffffad3d1ee74a4496a9d730b5800ad10d2fb52b0067b5145d763b227fccb90f37f14f94afd9a9927776f9af8cfcd271f9ce9d06b97af01aad66a452e506399c18cf8ec93ee72ba9e09c5dab01e3845dbdaf3aac0f0f1997815ad9084c97f7d5788355a5d3ed2971f98dde1c2178ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff12ca34aa4e500a10b1fec64669c47086bc0f1d48ea6b37045f7e46c73c5ec41f7576653d7a6d7c79bd1215f16675bb31a59a7137241b7e6c97ede36a4ec13198d841ac5495b463df8ab90163cd3bf06404d78f80163afeb4b13e187dc1c1d04997ef04f1a2ecb3166dd00479521b08e5ad66c2fd6c2f514abe8416cd412dd2794d0f40d353fdd70500000000000000000000000000ffff2d20ed4c4e1f02a2e2673109a5e204f8a82baf628bb5f09a8dfc671859e84d2661cae03e6c6e198a037e968253e94cd099d07b98e94e0b3c7481f9b39efdcf96260c5e8b0f85ff3f646f0183ba23283a9b9dfda9cda5c3ee7e16881425506e976d60a39876a46ce82f38af5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e3c9446b87f833f500e114d024d50024278f22d773111e8e5601e05178005298e5fc2933e400e235c0a51417872f68cc20d773bddc2720f67dd88bfcc61a857d8d9b2d92aae0103df73261636cb60d11484684c25e652217aad6f7f07862c324964cc87b1a7f45a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e2f067ad7a999ad2dc7f41c735a3dff1d50068f0fc0fde50a7da1c472728ff33f9dd6b20385aaf3c34d9a259dcef975c48b9bd06acb04e2cf63daee7da0c65ce68715d5299b01045480c439ccaf9f38afff4a07e8a212735cdea7e7e8f2511c0883e2583e2b68ef6d852f7e1d547e18f881e4cb053d531b046c0750a8c620553524c81800000000000000000000000000ffff40c13ece4e1f05f2269374676476f00068b7cb168d124b7b780a92e8564e18edf45d77497abd9debf186ee98001a0c9a6dfccbab7a0af4aa6fd6b27d9649267b4ae48e3be5399c89d63a00c4842fe854e91a7b01fc1a1ec923e9f287da74f53a510e60b4b0bbb5433bf1dcdd41a1bf278f9d1b78622dca0d9533ab2dc65d71d7225975fadca9fa1f00000000000000000000000000ffff9f41e9344e1f15e97fb8029420a71f7125cbf963696c3fbf9636f6d2fa8997d35d37416e2c837182f2e7b7623498736253e5469eb894b2d4f9828fb06df1afb28683314ea5f84faf83f900a49e8534a2d427ef3a94d3ddaf2b05702e87e99d148739e949b64a7c1ebf695f78ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff22ff0f144e4f9155ae06f2e689f4fa68d5ff89e0d95feeacb431cce7065615d2de64095024e1b60bdfe740e5da5facf13cbbe9d06960265fa2c8a28b6abd1b22272a2cc52d2d84373175012507422a27822ce0fafa7847828eced46309ff30968980ab12d74d8c751507306645fce7c379f7dc790472e00b2e4c9595c0a8932ec0102ac2e63fd00000000000000000000000000000ffffad3d1ee74a498bb67827af87431673e737c49312c5a16fd284daf1c4050e530b604ec4f85f217080503f978a6bec89d1ad4bca089c322583b4b7628ef1186853ff1166818d69d3aeaa4201c5192f9396c9cdd34005cf129d71833f1b56e857b9d578c2b7afef862c1de0722514d561f31f9b08319ff74ebe1f38307764a84a1f1d1d3f5bcfe6040000000000000000000000000000ffff8c523b3327138e21a1a12d5638afbe0cc50b2d61e0deb6553dcd12b84dfd0606a61b2475031f814207f613debe5791798d77f1ea47087ac95522eff7ec28cecab0b6ec79ede11da1416b01c551d5597cc4f8ab6921af4f896ab68e6e71d15bfa8a1bec00769f6894157f075a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e3689fd3e2cc5690053c4252a2a95fccde944b141a3ac8e6b8c36c6b61e71d076f5cc4f9ba0f191d8051ea9b5c51cc5848059c75118444f9a31b03b4285c5dfb26da4f136b10186d4f4152d96ff46c1f8ff948d11923899d2459f4656d5419682d8e16a41c7df3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e218312e0ba7e4ace816595ade43d2293d70c3dce6b3e7e0ce9e99016f99177277bb42e6d3c2d687ab3e8bed13fb0d3489011dd36c51a435a18af6d4b28b7bc23e706953df401461dc135037403e79929e97099d82532e48cc3f877f8d243bda0673cc73198755a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e2d8c8c7a5b96ed96dd5dbc40db042c301a9d70d5cb98ec073d41cc6a3c68d73ef0d6524cfa210ae1496a880e50fca3fcd15c5002882d6407c275f8850cafd70467a539a86301862677231ca31abd98e260e0678fe63d8580bf7a142a1afa68542aa7185409435a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e428077763a1a91d7595a05b06f805430cac72fc6737a0c0161624dadac33b21868d903d85bed5fc491be49f0653b8779bb40df4e10076edb905b93a9026c68d39aefb1883c0127847c25d2cde5ff46975adea87a4c6822f573ee66ac940d16ae205d9f6e88830c30771d54f702cdcc27c59ed99b19a36f0fae289fe666a5c51e43601900000000000000000000000000ffff5fb73392752f9426621a0df5cd8a4432c4050f39163a76ab39b2682aa3ea2064993265d66324be3d45ab22d5f9910c8ad09b96bbc952d8c76e6f482f2a7f933386eb007e514cbbd947fe0167964c4cdb2589996ddf706e1141b14c8bd3f293a3a9020dc6ece012a05827395a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e408e74c08f84a93b8831dd42e76537e8a17964123293de69c1cb24097035e0803822eac311434638fc73a5ad43739475425a3df63bd03dd223defa3c05f2de19deb9fc99aa0128f89142530ec3f0832aba5d71d14ac1ff284cfb8c7ac1b59df6c5c41750cf71f1652828ff41af6e504bb2081165b27cf520ea3381f716bb1a105e261d00000000000000000000000000ffff5fb73511271710d647e3107b77440e2e9957092aeadbba86d02eb95ec23e490c023936bbd4eda6cf8850f98d01bddf4db0a405bc6a373f86e46dd739b18399d05b219de3217e751b201a01685ce50d7f351dae246ab6d23033b1fb7ad8368467fb348086822fe6ce77d8a4398f99dae01aee02f174c49075e3e92422227fd6a57d4a44d7419c060000000000000000000000000000ffff5350e5d54e1f16415af54406658be9ea44d82b6b502bb90d93e32997484533a8a71a4ed98d12cea3709d84a5835b6ad8ed48d3101633d0669e929f06ac80c05365d9558ad79cbb78f2c00149106aa9cb4165261f6af3c21680cc16effd3449f9f73ac5e765c2e2380587eef9841b27bda0e868229f0bf8e285036dc967d5a8f83e7ca9b432a70c0000000000000000000000000000ffff2be54d2e4e1f8de69524dd60930aacf252a19e34e5928dbb20144d1f336a45dd4248acdcbcafa929619913980156defa1113d148113959be053dd3345010e52748f8e5c8fa0a00fb80e800a9d8b58154cbc573203f183f012ed3c037f6ca26a8c2c05c85551d8382ef72565a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e4910a2c0d103b24425b2359eac65b6997d2207c43700eed6371616a796c0a333e7401ad3a51b565a58bd7d0e604a0c80e04b4c9c61319479726a46b6dba6c1938ecf660c310189297ff6ca18ff71f1ba41b90026d5f0412b7757b7846dad8cb817fde20cd54108b67352e68db8b168f1143de5617edbb721fb971c84fbba86db8f120000000000000000000000000000ffffd93ddd094e2205e4d38cc8f31076eef71fe3bdbcf5bc8e956188603e53a12943476fba7a40d6909b75510cff435314a39e3605ed108211ff4b4a20754d2625f4850aa5c5fbc61895672101c9ab494d5c6fa05c87f689f9de3ef0da18b397a07361e436e5a2f2d4697056f0f87168d853c9859f79e28b08e7339456b5ea19a053c3a1edb0ddbe111500000000000000000000000000ffff5fb735112719865d6f26ed3f5309e4aed19583cf179bc779e21c967485f355b214ffb6ba461a01b575a9c62b3a02d08a37d01817af832e54ec3e1b5bb6fb8de073c9451760b2127c09a601ca485207dc1a501f9a694d7cd0f007846c40e7af8d148116c647923cdf7b9d996645fce7c379f7dc790472e00b2e4c9595c0a8932ec0102ac2e63fd00000000000000000000000000000ffffad3d1ee74a48101d302d6c69d9ecb9e13e755947f3af22f63ed4ecbf466ff64bd35c3d86bf2e4d8455ab736715d8f064c8c8e4d3c585b6a6ecf5eefa2ac295cc6103d1e42c7276e72172016a59f9b585d75f1b2cb43b7c0fb90a294fa45e0c1f7a432f82139a3ddfbecd3ed2b9c32684bce2de8afb2ba9bc9f7547d3a43fc88bf0a33ae2dddf6e3700000000000000000000000000ffff6c3dc02f4e1f0634f8b926631cb2b14c81720c6130b3f6f5429da1c9dc9c33918b2474b7ffff239caa9b59c7b1a782565052232d052a1bba3b56ededb76c1834f3b3e02c159aba4777a6014acaabcb7ee31149510138a0b11b087cc5a2ff0a24225bd52b52e1c2c58a113d5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff8c523b33271197e409f5889b8c033c412a939d2419824a2b0321e29c357a43bcc74644d1945c6a5fe7f8977edeb6210cb038039bc30f84a5d378f42cbf6b07b826f192cf691480e7070f01ea721d7420a9b58025894d08f9fecc73b7b87ed09277fa99dad5aa028ea357e176f5ce05c6c2a6de5d8a69c23a56f19dfc8f5f357c9457adf560f0f60b00000000000000000000000000ffffad3d1ee74a46983ca9ab507b3eb4e7b0d31ccef3f4553493ee5334116a3f79689f9b808a201ead332a26f7052fd17123cf142f96d85fc59f2dfb9d43f7570319c048b73a3b2e33f60778018a9a7d61d25db8904a3409468d81d49c3c190ec1f41371b036abf720e0a431fbd75782917293040170ddb8557a0c4dc1577d621f3269fe65409fddb40600000000000000000000000000ffff8c523b334e1f8b0c48578e5bfe77be25aec9e2745c8e699a6069411b3d9f90703a9f4dcce37bd62b511f3ff089422a7ba29d46e2b61675748f3aa899da653297380853319a3844e16e36018a3e98538662189dfebf2af3e9d22950256af8da8508d69ddbe4b247e846377c5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e4a86f43bc634d21567e456fea9ff6556e361d00da0ee46955244009847e492402c8dc82b4247330fab96ac9f0c538496b2cbea42ed3362203f066b29126deb6d1758cb16c3016bf850444b40d517c148f79bab13778e464815829a8a0cea7391c6d0c0e636bc8cd6c3d98dfa6e65171d7050963c7f9fa87ed1fadd04e028b49681492400000000000000000000000000ffff5fb7358027110077eb37d4559f880e21dbc3840a1a8ec8c32787fab07bd12e7fde1ad5f94ae95d6e4694f3533799d14e18c6832497428f95e1e0c681187eb1950ecdce67096ed6f5bd71018bc18fff3bc302051c51b545677173c459ae62e7cde27b31aa843193d870eb255a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e2e1393265406093dc6bda557446b9808a40f13896a683bd9801511c75752812f4a1ad4ecd3d9e9cf4c3afc62bb6cacdfe3867f01fcfb84d68804ff6f24f02b7e6d9a888e07018b3ba1e49dd244741546eb6f2a68c82d4990c55999bf385a070d27cc7534c4784e275f599b8886b49daa3285f5d4780d103b0475ce0123a2ae3dcb232f00000000000000000000000000ffffad3d1ee74a401828028671209b5196d2204d5bc3ce3ecd554dee9ff231883f04e67bea856fcae19d7a6154039140e9e3a6c6cf3fad4d3ee3c4a4a092ba275cdff0c03b912eb1d83c5e8c012cae9e9e4e356b719de38866f5a4b3727728a2a3d6a00a5f44075a015d0f9a0d5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e309179babbf6ca397dc089cbe29eaffb58ffc0afda1d6c7678ab3739d5b63c7f90428cbb4c4079823a3a71a25bf89f56b3c938bffbf5480f6f019e4aae7651450a8894b4bb010c67b8d2c4ab23820d89d82cb5f841b3b3734edda30f10aaa2c2bfe53a4c96645a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e4390a7a1f6b509e1f13c56262b8ebce0129cb751b16d8cd681634e62714553bc4dd773a88adf16184b9f951a9b8f0d1d54b85bcda0e2d5fe1e4b122a8d39e1ba860e451b61018de9f50be6536ed7f22ecd23bb19447387dca77f2d67024a97ce394d0d538b163554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff22ff0f144e238e5e237e8bc750e5237f3c63bdd80034be58f6698ea1a696c29ff7f81cc251dabc5f925b65289e428461e2c74ba894ef0b5468254e500cb9881f73567c545b5ddfc51f50012dca894a2b5af0bf82abf0cfba978555f41a669278b6e91ca14c0593beaf220076f5ce05c6c2a6de5d8a69c23a56f19dfc8f5f357c9457adf560f0f60b00000000000000000000000000ffffad3d1ee74a4794b7723262031b6cd2e79b07f36a794d3e684c538a6f2418fff01c027fab1ca4663ab0b92670ee1797fa71d8676362a0ed8648ca7d2813a5bf93338e12d05db2e07d4d8c010ed18ce6df1e9a7a957852f65486a0eb17c70b8d51a24faf4a0a2e047100bb7b5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e390bb7f50754a1fcd59d9d13bb7487060a7e6c9226af162de0d173b132e033e8da6e0f53eff5a1fe3a3d63e853217611a434762055a745abc52735a1fab5b7c509f873a64001ae4a298a414e8a8470e8c5b911a3c6f9200a806fa1dac65bf0e317c32ebcec8e84c09dfa353c83ce072c6a67d2081e80418db10e7dd8260b5acdd5f92400000000000000000000000000ffff5fb73392c34f92f5e861ac88ddd95e3829afc45f9358ea0973e19da8e42eabbfe8f2d9e5fa32204e7f1de5e20c7e45ee51ab262cf7dd70238a568f0ed035de6210a002f65fbd549ba8e1018f248bfe318e4c9a889569491d58aa249a66a25716f09a1395e77229d1c14a94f56f0efbeaf436e98631e20bc7649afaa481cd62daee03f3af120daf2b00000000000000000000000000ffff8c523b3327159685ef9d056c2497dbdbe95e605f09e6b7fb0475051cdca625b53e3f761f20ce7353949e6e433f5cdb9cfca7ea0805699409bbb382053d51256b9622b11bf08e9919088a012f6dd2089625cd550f968418db3aa3aa7ec2c82b9936ea1b64ae3e49a9448ac45bda13c71a8effac4181b4f818da0cee9311c1e93a15787dfef825772300000000000000000000000000ffffad3d1ee74a458700add55a28ef22ec042a2f28e25fb4ef04b3024a7c56ad7eed4aebc736f312d18f355370dfb6a5fec9258f464b227e4d1eaa54b66e968265bdc5c88ce521e5608cb2fd016f8a813df204873df003d6efc44e1906eaf6180a762513b1c91252826ce0591679d19f6d32541bcc31a3aaef426e8e50c8253c7461b32708853ea90c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595d9f40d00a7ea5cca2502a1c5bc47706688c4200afbbb769dc2c57794ce684821642ada3253eba9dd86db233fc1a700fa728f474f5a34aa25efb245ea50e885e479abd9c71d32abc11a4e73882221b3f3700000000000000000000000000ffffad3d1ee74a41925d20af1a6d0ccd3890f0aead4a05a59be22e005b6d732f855311915b351a9153b2c83d84611b2c9958f806c93f7b5fa7ad30eadd503811c7f7dac3397e2544669e43d50190f28100e7b321ea2aa4e8eac6c21fa51757af4ed00fa835175f253da89a5b1b5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e3782dd9b3523f18f7cb1eb08ada48b7940eaf46aa9ed6cd1d79fe702d5d5689cbb552da3fa27a5f07efcbbb05cae2d5585dae0a3ff4070d41b6e0a13e0bdbd0af040d71c4101d023a6c0acc1b2847b50c93d64060c0d2a5a36778fb175c08d9567c537f7ffe95a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e321266fc3da4ce754a1c26d4f5656a5f9a3217cfdf70d2595c75b5e191041b3224c55a3542248a63a94b0ca059012aa7f66d61b96d1624f7a203d2b698b7ac446cd6cdbbbf01f000645cfc9a7d31dec37de64a6d6fefc0025e3882108240424650097cd4580e99c5d4cafe1844368f515708d3f8664ccf1f0c4644d9a08c3c80bab80c00000000000000000000000000ffff23a165234e1f995d3388b0289eccbaccfb505ebf86c8186507b5fe4b6f137ecdd7769340eda6cf44355b51493e35a722a40809cc42238bd206d0ac79c8f268227cc8308b27da055b239501f0308e1b7599190a2245435455e21d1dab86345f59f7ebd5931c93d96cd6723d3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff22ff0f144e279470f54b992d3359b3a1deeb973a9ae4dbd0aa139b713448cd04547138f5855dca3065bcc61b1f1ff3390fe040f5833708c2ac3f1a099b745f17800a346a1c4bc920050001f15834be4b99fad17cf5857e8689241deb9f01ae1319d4e30f26fbc2a5a2a67218133ea3f6c6aa4a4c9ffb1927e68b99d93231412190deb9059a72662600000000000000000000000000ffff5fb733924e1f987d8b49e8aca918aead0d50b28fd0f61ed166f28b6365acef6a9aaee144a692f5b3cce00a40719917a042d16d1849b810c42881c057bf486a77dbb2926437523da4adb60111211081e2169c2294e986c881c1ba10a72acdfab62d9c7fed7d7aa1239194475a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e3e8260a3c57731ad90a95499e04802e094e4daad6a2ccd242761c1849342bd8cad744dcc5ebc3301fb9513c30ae82e8923e42fb7cd831ca6d386fbb8f945acf6eb146e2b0b01d19a8662b3614ccdffc199e6956eebce58855abe56cdd3a92d1de03a436a4d585a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e46873c0707fc70cc07e162664bc5bd0d61de2d8f2af0d0bf543c1411bf7a713360435923cfadaabc994de9156cabfd352ec33d99f91bbe4f3701c3684b0960c583a2f07b610111c3e585b5067a6d4cc6fd0690e66f8154d075598186be2bf04a39721ebcea118eebc867becf636c1871a8935b2a1a5e58f11c65dfcb36af325c30d41f00000000000000000000000000ffff5fb73511271414926e7ba179612df5cb1cc4ebbe311cfa9679e41f14ed7b35d12cc33d419073f013bf751be85f2b50e28910df33246349a36b7e56a5229ee2226219e8c4d1395626b92e0131af341643a35547531ab7f33f933b4bfac24661881e129b696516c8149e2ec3fc1d3f3a2e3f3459a2b5ffb6e67830f03ad7f3803bbf7ba5d32887a80c00000000000000000000000000ffff5fb73511271209f87f98c0ad49811131a31e94d875bb6c88f64226727a508094ea8e5f25f8f6cba8d2fb27f0f7e662233c565c1cf114eb3a40e2f4b4ac2cbcce12d71041f31b051d86840132459c9915a685f4faf1d86d621b29bec83a5a784b40a4c1e0329d0a5ea0bcea275dd42348f33a30f058fc67f555033eacc5ee1e205fc9ddc4930fd72600000000000000000000000000ffffb23ecbf94e1f905caab51ff07a2f8d69972fd6ec09f6f9893cf6dfc49775f5a2db2ea7a8a525bbaf4e7e369d06590f6f2e8e4658d4dc1341a33990289395b5659a4cb30cc07ba002b505015235f5a493f0e83df8e088935262a1acb600073f8dd1e2215421a0f265a999455a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e44172cbd28e4bd100792c4455d761c523eacb2fedc49b6b20c67952e2ae5446d11931815254756a37d21d553131ce4a09e13bd7869b809fb31fb781f22948b498568289f0601b287610a92abd2251682e838175d2a742694dd64db25c22e794a3e0642dca689b90fe5000497348c6edb4c1c607ffb22b9ced8d6cf6551dca7c5380f3800000000000000000000000000ffffad3d1ee74a4307ffa44583c9908f4aaca8dd97990c56043e475723f90940ef5fd7d493152540f25f58fb8c965ee5e1be4f850a661476c1ad3af209f75deaeb9216fc8339fd48d376f9b001f22b5b0872698c28c6c5672aa0e62efacaa2664f9a79e49822fb61b7315ef1905a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e34071be08369f71e4b4b4e587ff64eeff402dba0e9c6dbecfe3b3f80bcd2bbbb433c01e42191eb0f5e3a95e56d8cb4a085a0d68a5ded90c01f23c7e86acc5deebfdc9fa4cd0153f0c4708822c49befd55035b66d379c8c7fff44b614e1913d26e7658fe6405d94e291aac54ed1cb7e337a8c7cc4f883e89e6a95c55c607310d07b070000000000000000000000000000ffffad3d1ee74a3a98b26368c5f73198500cae0d7e1108833489e7f8bc5d7fa507014fdd0ad2b6a082012883a8acdbcf688423419bff7e24c8ba5bca416a7f4be90a534d11677811684d7e3e01735b425b8ae3330507aa1fb4c5c679578bc15c814582d1e9c41cf0e11fa3cbd1dd41a1bf278f9d1b78622dca0d9533ab2dc65d71d7225975fadca9fa1f00000000000000000000000000ffff5fb73511271c0f9764003b7ede1d0d01f2cf16fc0f706f5394d2da1bacda404615c60d5bcb0b22a76776fd9be00f1d4a4a668ff3fa223cfbfddad5b5ad0644feead52e00560717eba6e9017480487c2ce567ebf6d3603dbae12a6015ce33e532dee9f0c7a4a9706a27d2f584c09dfa353c83ce072c6a67d2081e80418db10e7dd8260b5acdd5f92400000000000000000000000000ffff5fb73392ea5f95d5badff945693fd24158932b41e311e6fb3cca1e1e551eeed72cddba2e3b04abe86547a265fb7ee958875f9c33134db268e95c7ce631c89b56ffe1c3929423c1750d4b0174495e022ba898fe7753c55fb07ab876d087da453156b8585478d942adf1c47e5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e4181d241a9f83b7dcd577fa215b1b2745cffff34d26290139bfbe30e8884b1e34fad596de7555797429029cda262f3c40625f547a7694aff98b19a7e9d4e344b4c1f7545840154ea82ebdb6b0eff568bf917ad5d0b8334ce294af9ec8268b37385d354714cb25a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e4c19c7b27ba7332cf4641137836b3a7ea78b9a53672a28d2ae5a4507dca234e5cf9a64406c98d96f120f3398075a23b0a645092ea3f00922937321d82aeb43f9df3c307dab01f402c2d2b46d474055b5c9c27f1e03b26fdc1be7b4f2bdd9cdb84294b708006ded87ce92ccc0bbdc609bc0357d3fbb42646ba69a8894b9a65e9ff26b0d00000000000000000000000000ffff2d3f78964e1f95fea099d4a11d784125af21a4f837c4dc0cb626f48a756c0426baff1687d3aa63a1f0cd3e1c5dc7040dbe3c8cf003280a01b0d41c4217b600fddf5cdfde21f9f13f6a0a01d509859a3a70d4f6c9c6430ba5a5c6ecd6f375d05dd1dd02cbbe22350d3b3bfab90fe5000497348c6edb4c1c607ffb22b9ced8d6cf6551dca7c5380f3800000000000000000000000000ffffad3d1ee74a4289e308c9d2d8a3cb35f9d7bb7220b1eca82c952b82111119670dacae18a509628c775287e4e796128cd6379b80dffd7d8d3433cb6b9a1a29fdf07613172bbfdab744889601d5673d1de3c45b85128b7e4e3f36706f7ca7ae424b377ea4693eded49e44c44a5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e4587203a9163f2c3d296dbb8af5d7faec7b1fd204a8b1a5ec29a1c1c420d35dc88dc681b8752dd3fc5337dda715bfbc29aa85be0b3232261a9d146a884a53102964bcf37af01f592d892b27d10896c76bd13221870d9013e7c7a8b13c72e33a393c9c4e857dbf1652828ff41af6e504bb2081165b27cf520ea3381f716bb1a105e261d00000000000000000000000000ffff5fb7351127160dee44e338280a8e534c9e8bea9cb9d73163070d90d511e5c83859c384790e12da189e791404126eb2fe080593ad9a73ef664b6f476a958bcc490d4f170eb0ba926bfbdb01f52a17a6e5325b40485807bbe147bb3fda1aefa770505a71c71d7af3ba63ecd55a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e3384d8be6b408c129aabee53bac357bddd9eab338cd6cd96333a797d7fdeed36d7dbea5166b67b2cd160d46ac1bea832571aed89d64b9fb55bc49fa788c9b9c743c865505901358b1a766d3e8b71f90d3fe85231f2aa3c6504cbf2be7194d65f3a4517f459d93554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff12ca34aa4e24110e94442ed21e4bd3fe5b2e9726c3df4993fc61a10f1a5f37b6504b5d64b6e02e4f3177a6786876a1b5f756681000091a4b8c06d7f55bf4b036ce47ee75f675a715da4a0135372ba93701b380bd9df59538bdd426d2d995f257e90a63e88179ec87dd43f4f1652828ff41af6e504bb2081165b27cf520ea3381f716bb1a105e261d00000000000000000000000000ffff5fb7351127189809c680a8b7852279f00438526b2d940e65a0e746725adf2bf00ffc054ad2601b9011cf1edbd391426afd1b204d696f73f00a974aec5cfbcc3a34823f5736f0b7c8a4600156446d367c54618b42c90e54dfde45fbd07116dfa21425fa6db009a425bfcd3fc381e621c33b448e2d7bce9d631a2697a91f1916525b99937117daef2200000000000000000000000000ffff8c523b3327128a84f0696ae42026a72b89f066a4a55d3ee12545c672d0de9dfcd62ef63e8e0bd15d8febf1817ce2c76af812dbb9ab9af423ffc0afa8294451b9352ebc5a4ae45c6291bb0196d443c4f55c6f02d67fbb8c918f22571f83bd547f654bd490618c182fffa62794e291aac54ed1cb7e337a8c7cc4f883e89e6a95c55c607310d07b070000000000000000000000000000ffffad3d1ee74a3b110bdff9037c3e3926082ff9e9e9de9cd0a0dd416ac6d60a61781f1b3832a4bd068e92343be400fc31db6eb4404d0701fe4f653429e4b1a0aaefa221b9191f4deb20355d01168147b72bd50c225608f2cd65ce90cf930c725b95b82e40e279b01b34e0a1c7dd41a1bf278f9d1b78622dca0d9533ab2dc65d71d7225975fadca9fa1f00000000000000000000000000ffff5fb73511271b802913fa3cc02a35fb8e1b26b644f8a2395078818f9bb3be8ad08fc8cb175f16c43e2b0aa2fc12a7f8dda3914946f702ce357534f97142aa704c8be0924950a7873b557501d6410cd8bb11cba290e20c9b183f0739cb630628994b66aa72c40b32ac38e2085a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e3d10c0a1cc322597069f80ea22c04c4e5a442fff97ae4ec952a91eff9d8d9787760f20a227b1ada2025a6e9d74146e446752966d0882633324adcd18d1c4d9dd741e141e8e01b607b7d015fa271ccae5740685b3fea4be2b856da2e4f06838ed23038638873a84c09dfa353c83ce072c6a67d2081e80418db10e7dd8260b5acdd5f92400000000000000000000000000ffff5fb73392ea608851d988149766aaaafca285ded50de031ce42036033e3239f4f903abda26740ba235e22d26a693136a5ac27555f3de8fdf5e400b3daea8fe42716a8784d1033ba15665e01975c1fdcf549fec88dba2714f9536c0fd5ab0bd0cd5149eae9c1d578266a4776bc20451b8a05c6cba10970aac3cdafc549a8b40d7c23b9481a6187100000000000000000000000000000ffff34dc3d584e1f10142d44041c90621d111283fe46fd8b2450d4b9bebad194290fce09ba080679c748b1ba70e3959623f127af0d2bc9c46dddbc8e0c2bf0803d236fcba6cc32a8123ef43e01d79c543b826e0254c6c8aab06dd8b1445677df23d93f228798535d3030ea4ac2bbaf9ff7a4ffcf3931de9233fa8e151f187bf30235000e3b5fb102b01200000000000000000000000000ffff5fb735112711845e9bf2879d98ece4aa8b78ca074e32f968bd93bac973a1abafd61f900b70e7178b6352d830d0fecc2653d0f04a915189842a43e2868f4e5451c2051466a8d6b1bfc2bb01f78fa11b3c1abace87b38e3a07095b1f6f990c0c384016c904de654e24ff04755614266b33c018e9b66f0f7c25652bc97c50483f5bdc1a9ae17117060000000000000000000000000000ffffad3d1ee74a3c1249d9527e8ccf8d237e828500cf7f8946963d45264460586ffd8fb1b76e16a541c54695089fbcf4b1b8e1ec79e93a708677bcd0255c7660249af2fd710a73d2e961ab99013987a05e9b1fb72cd13eb1ff70a20ea8fe5835e6f9ecacab48e0538c77b0a75a8eebc867becf636c1871a8935b2a1a5e58f11c65dfcb36af325c30d41f00000000000000000000000000ffff5fb735112713940c2271fbfbe83cd9dadaf03da32e840466cd4eb0e358749d5f22da2ca22610c6cdcb664b1c082b84cd4516d73ce5d56be7a3a831cac698f630a281ad80e7e343aced960159c38b8d6a0664411f92a6326e8ef0707ecf185405252854ddb477d89127a32d3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffffad3d1ee74a4b932f6fc90c9dcaacdf9d836a2a7e60d090fe5e55b0b02f5a4f608a4b8235ba5aa7abc4e05f9387d1d942adc57c87f5b7c9fe0e7daab67759c331e39d4b9c05174e852f0701f9aa14a66c5edcabbf6857ab16b02e1b725ff23f6fce8e9d174d87b00c1f496742d70ea01c8e792ea8f75df86a9c408511b21172b45a53c1f6c0251f0000000000000000000000000000ffff5bbe7d854e1f91e633b72726091f58e3bd1ede3a21de66abb2456c2f669be8bdcf76f3ab76aa2d75f7d03cf2f7d5761ab15e62e00613de6d2589b9cd1d134c8aee733d9ecf70a21d334701f92e1162ab0190dc924727897bf4d27eca18a3ebde01c67e2fb82c9205452f8decd2cf880d6b648eca3984400156eeed9443f809d23488d4b7ffbe621600000000000000000000000000ffff5fb73511271a8c01a1351c0f42892d6b68c106ba584f91dcc2869f384830c968688d09becfd0f7468e7ac7f02983724a6e95a887a1483cfbfddad5b5ad0644feead52e00560717eba6e901fa18d6f63ae9d791cd65d7cc1cc646bfcbb8706e2a6357364d5d58ea7696eaf65a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e3b18c60c196da02ae838b5cdddff0b84ffeaa5c72e2fae933d3a173914695f9d3f2f13a12567cf8a6445e1fd2472aad3a05f2dc45127038c872951c469596ae2f1b600437c01ba5136a927bdf3b74c279b277b3fb5dfcbf7773475cd770758c071ed882f186e5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e2c95758d8a2466f990857e8d1db8761463d8537f3c2cc59b94db7017e6d51f47075657c5ea8d1f801c9c71b34f3cf8b57bd1c5eea17a8f6a3f8d7155e76ae9581f6e518831015a5a77fa5422d4fd9fd45a991fd186106c6e0fa4cd151051067ab2a8624aff0b5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e35919f8cf51ccd17f119db6f0bac1a37ad10e0b634c1a0cb76fab44b881fde5170247695275f0e7c10286fe58fff4a97ce2d3a1f4839a73715992e9c4ac586fad7eeab356a01ba26fb851daf4a571f2e58a0ee53443f99907fc0e5f3ec422820148d39d110525a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e4783bb6205d6d010166f99a1f6f671492210caceb92271b1ea21695f8831545f0f51a80beb06b054b558aca09e49e1b1d172d83737bf5ebc4ef9578ee806f253eec6c655e2011a3f5ec38a74ee8799405e7aad8bf265244f1e9d4226fb1099f6431a4a6170b478ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff3432d0354e5193fcd68988f82faf350938dd57cc7449a669eb9b0d5095c24b0c6e61a04dc7408acc1909d79809da0a909f7f15d24411227283c70c84ccd7853235d8e58496e23b0846b4017a0ffbd06f4d0fd6c118d084498132e551513870740f801af2354c5c616d0f480a7d2665fdbb1825a1f1af4dc4a8c0d924eba1198078f731c4a8370f0000000000000000000000000000ffff8c523b33271411ffd9151f27ae5aa8f396270af2365903951a74b7b16a9e404b4c69e0ba84e1d5ba2a3259c4e7069d9bbf0bcfde73a6b3701491e9550750948da59bd08e8b95c2f7c937017b88a1cdf40dcdefbd47b1a96bf88be1580bea00597d3b99a3f8e690897f0c40f3e8069958306c30252ce3b2566cbabcee61f8bbd6a0c5d219ea13060000000000000000000000000000ffff5911296a4e1f848bfbe1bf50debe1322e14c9115adb3b96e5b8a3ae96beb7e2161281d9e56c30e43478d6f39835e3533a1c54377258b724befff5e89d92cbad3cb0cc8281020b0243bd8019bdc261b20c6697097a0693ccc5d8e08342196ceee3c67b2f3f703af03638cc98eebc867becf636c1871a8935b2a1a5e58f11c65dfcb36af325c30d41f00000000000000000000000000ffff5fb7351127158a209b5083c2b601ea18a04f0e92ee5befecf765486deb9643dc3b3fd193080c2659bba166f3873364964d5e8f7e4b9344ba46c120c527424de6a08ce3ce2b7c9dc81083011baf6cc0d348c45bd7826fd085fa3a0bdcfa7441542bc94396e131da11e91dea3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff12ca34aa4e2800381a3116667c251265178d35698c8a7c801a9765714c793d2dc03fbba5e9bcc9899a3b8fbbce3f07be22a36d0a4448fdc40895465e75cab40053a076bd3ea0a20c1194015bf7a008043994cdb799392bda7b5bbbd714ac2c9b2846a3ac7589be18ad357d5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e4b0872f496d7ca93e1e7e0e2aafac36c5a45e86b0780de1a8c5ec665343e7204538f116c5a4ace4fa9cec823ebb8f04af14dd387f5bcec1e45ee7dc221baae1095411402aa017bc7a2be984b24d7405b3b1cee1aed3e2dd2bda92c2530e9ea34c3d683fe673605d602cc97294b000cdcd55680eace9570cb846d0f05ba55feca82080000000000000000000000000000ffffad3d1ee74a3e8b6159beec3c3c1ba223fa988b5806a02edebcd16869a2e053b41b7db3e28f12136636974f5333317fc67a22d2b9b3db888f308cd9a0e463e61c1a53659dac28885b523e019c2c3394fb96bcacc80d596968520098d63797fe0ddf067036d09de0c648e09505d602cc97294b000cdcd55680eace9570cb846d0f05ba55feca82080000000000000000000000000000ffffad3d1ee74a3d182ece65d7aef6b0d0a92c0e3451609607717f9cdb6d11cc6e31a2d625c7f40a8cace522b036481daf4e4425c41880a545a9bc3e418bf0be93c4f1ce2cc001253601cbbf019c8dc7c74d6b97310a44dfd37ae62492c2a615bb660ede1e2adac449c52398b25a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e3f1243421c72eb76a1d3058de901007b28211ca225466fd7fb046ecc0fbedb3d8ff59c144a46f720712e4525dae6bed584b600745efd3dc74652cfc4f9c6d99f9ccadf0350019c4e2fe4c34ab54bcdbf5fb8d3305e4e2c1499b789ef7bc90ec106ed62f236813554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3f21ee554e22902c12f4e752167465dfaa1cb88b45878c3602a0543bfb36be2ace7bd9725f7c4fd76446dabe9948f251adb808ac3ad42dff4926d431871ca8f78fb6b623c0e9ed113e7e01dc670576c36fd5a92e8e580ab4f898a228d6f9f66b19fcb3df185b66870577fb5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e4880f5458a1d7ae69cb8dbc6b7d69ac112e008bf34a985eb86cd973824023d8705cd02e2392f3c7682c3a9fac2a6c4ef48438f76f99f51d8f671f6872302cb9728e12cd7f1017db41143e8d6e3ca290a69a44797ee967e02f4297186fec08a8a0272f864369d3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffffad3d1ee74a4a862599b105fae8d252fef9707d02988e9f302ce6ffa7d1566908979816af6752e1470dab2f6bbed45ca65e64e4b74a3fec4308c6a9bb3109cf662b0f427cb183bc70f93e011d09e6c4660596a0cb7a714a044d41f208b514ee79147f9d73d5bcec839f4f9f83f4a966a456d795192b83bd2c866dbefee9dc9435dc3fdb42882e1c2c00000000000000000000000000ffff2d20d39b4e1f08e37b3fcba972fe0c2c0ea15f8285c8bfb262ad4d8a6741a530154f1abc4edd367a22abd0cb1934647f033913cca58aa2dbf2c2b6149412562f306841959b9cac234b73013de971af0ebc17861419d05f0250c7f4f073d444df1404914c5afe0afd65ffb45a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e318cbd9ea64deb7cdff20eb3895473799d89c6cd11b5929934bcf5e28b04961be6398f4030f66ba12c13d1b749dcbfc4d361a091feea151cb4c9aff33d0c35b73226dc8a7f01bd45d61cf59378df157917ec8a19d62ea3234d7be8624800b91149036edc232515784d2f4129fd29916fd727094482c69714921bec4df0a0458af70a0000000000000000000000000000ffff8c523b3327168ce516fa5d72f29e08d842812ef5cf72de3672c23d6dc88f4b13f0a50c2b8050d0cee348b6d542ceb569a45504e734997d1203d2452d273b2f4545a105eb7f2f2bc6cad1017d1ae31c1be20466c400285a293f88badafaad90fa8bc5b77d8da36631cf4e71677e5cc06119499c3f65458f202ed9ef3ce17d98ade4a6574fce0a653200000000000000000000000000ffff365b82aa4e1f08a37fd91db686b551ab91b86ab073c2c44e1d0bab4f99c1edfbc2b12abafd1e9a96715afd16173ab749db890276929ff1b9b7fc7bcfd49a904edeb77cafc68844897e91011dfbc526d3abe5490752532a2f305df97432c482c0404fd236f8bf8f0e4cc6555a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e2a9625089978a7d330992669359de9168b481fa76ca0725ce4f55bd7561618109c9a8035f608723f68458ebeff4dba5eade27f552b67828b408a673ac6e30c11a054f25ba201bd27495194b6933f075412be4c301511eea1e0f75c1d8e3274cf89941a63f3b6dd41a1bf278f9d1b78622dca0d9533ab2dc65d71d7225975fadca9fa1f00000000000000000000000000ffff332650224e1f820710bf028cf0f81d0e8115f0654dffcdd83e598ddfdfd91bac653dbc534a3177844fe8c87e991727d581bcf775432e73787fcf2171e8644ea78cfcde314393bc66bdb0015ea0f69d283e319d068e52dfa9a5cc8b2598b986d85e7639114630843b73a55094e291aac54ed1cb7e337a8c7cc4f883e89e6a95c55c607310d07b070000000000000000000000000000ffffad3d1ee74a390418bfc9d8225bae5a889f1f74d47d539e9e7a8d441cb2b743b176e9d3a7ea4915fb40844cdb53a6faebdb4e826f9f7820c3d21ea834c65e7584f4d3a9270c70297f04d900fe85d7358334177035e982db8388fd37b752325df17a53717b78e2b0c91b299f3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff12ca34aa4e20157eff76f9632db9536c8af64a2283f3da7f91db86dacdfbf193ada958f69980e18d8d1f44d225fddcffc7176a941a26715baed3fbb275664b20a5c0f525568e609ab0c2019f5c63c41c148ef09e4c82471db0500b6c2246d77a93c0387330201e6124d91414d2cbd1740e5481ffc9f710c053a114ca488996af9bf9edea3f1f0a0000000000000000000000000000ffffb23ecbf9752f12e0312b6ee98f2ef8b3ceceacb9af3ca00346d2f6bf5b710ee06f51a0bce5b7caf5f76bd867b95c10b4279dff9aa74e0b626266e5e5da8a8b8918e967987dfb1661e18a001f21e71597ffa891c91c1f24c4aa7925cef68f86ae9603c13b2b018e05651fae6cd6b4af357f054a9b9ae6257b20c9936034256118e06a3048c68f934c00000000000000000000000000ffff6deb45144e1f84175e1361b4f718341f496e3ad40644a99c292f184f7bf31ab2a711c6d3b63ad14fe4df227974fee5a8d4ba45fcf52118cd93dfee4f5f9aa9563d595f3fb4cf0f2cd8db00bfddb9d5eb05ffc2fa5573d09549f23ea9e1cd7ecb650f3eb16ea0f95cade5320c30771d54f702cdcc27c59ed99b19a36f0fae289fe666a5c51e43601900000000000000000000000000ffff5fb733929c3f1326ddac1044e0219dba7dccf6b43d1deed3e897717ca06757243b02516cfa67e24026f7a317cf575b40c10e7f6bf7f087da2642cf967c493f126137d4f15e9de36b976801".hexToData];
    
    //hash 9b1b013f5618e58283526930e8f6aec05fd7facc7ca85b21764d53349baf2aa3
    
    NSLog(@"normal %@",[NSData dataWithUInt256: @"0000004c7bba7e46b583731f0930c9a3b0033e268f87bccf9a5e44793d634a5a47949123a17a7ded7f9c2db6facd2aa710bac181c886e994229c16e281102111".hexToData.SHA256].hexString);
    
    DSSimplifiedMasternodeEntry * masternode = [chainManager.masternodeManager masternodeHavingProviderRegistrationTransactionHash:@"47949123a17a7ded7f9c2db6facd2aa710bac181c886e994229c16e281102111".hexToData];
    XCTAssertEqualObjects([NSData dataWithUInt256:masternode.confirmedHashHashedWithProviderRegistrationTransactionHash], @"a79f53b4414f7415b89b25d092d653557f2b2d2af32904b808b769315502bf39".hexToData);
    UInt256 score = [chainManager.masternodeManager masternodeScore:masternode quorumHash:[@"3b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000".hexToData UInt256]];
    XCTAssertEqualObjects([NSData dataWithUInt256:score], @"7125cd3de730475accb2cad7d0f09e4258b7fec5f7e5fa0ae3ca7f1d373a910c".hexToData);
    NSLog(@"Score %@",[NSData dataWithUInt256:score].hexString);
    
    NSArray * quorum = [chainManager.masternodeManager masternodesForQuorumHash:@"3b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000".hexToData.UInt256 quorumCount:10];
    
    NSArray * desiredQuorum = @[@"35.161.101.35:19999",@"52.50.208.53:20049",@"52.50.208.53:20021",@"52.50.208.53:20017",@"140.82.59.51:10003",@"63.33.238.85:20006",@"173.61.30.231:19018",@"18.202.52.170:20016",@"173.61.30.231:19012",@"18.202.52.170:20004"];
    
        BOOL allGood = TRUE;
    NSUInteger goodCount = 0;
    for (DSSimplifiedMasternodeEntry * entry in quorum) {
        NSString * location = [NSString stringWithFormat:@"%@:%d",entry.host,entry.port];
        if (![desiredQuorum containsObject:location]) allGood = FALSE;
        else goodCount++;
    }
    XCTAssertTrue(allGood,@"quorum is wrong");
    
    NSData * transactionData = @"010000000175b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000006b483045022100fe7775f739df986e0f4537425e3366943073102919933865d869abec9bb6428e022041119b3c6cce65aae5d938deb5e491d57c3f584af52b55fad5c2cfa489699c050121028bffb9f06248f14aa6557dd934f3134be316fea33735f5a2b4ea849c4bc74067ffffffff0220120a00000000001976a91465d45dfc066c7ae364c6e2da6e8cf3dd212e1ef488aca0860100000000001976a9146a06f7175a32eeeb87d40ccca8fd131ddf8d543588ac00000000".hexToData;
    DSTransaction * transaction = [DSTransaction transactionWithMessage:transactionData onChain:chain];
    [chainManager.transactionManager peer:peer relayedTransaction:transaction transactionIsRequestingInstantSendLock:TRUE];
    
    //we need to make sure the spork is set to true.
    [chainManager.sporkManager peer:peer relayedSpork:[DSSpork sporkWithMessage:@"1e270000841c0000000000000eba185c00000000411c6a20fbbbd45cab4c696e5d840f3c7b3510a35f2004422b7a1c1b7dcea64686fc1a2fc73f223e7c36c8e54c6f36a9bffde7635b01dbcc2f019839a2e0ea1456dd".hexToData onChain:chain]];
    
    //check lock votes
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009836b147e3e2608dcef4b82a0b19d165bc59e64ad61645c72e9b229611741bbd010000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000f000645cfc9a7d31dec37de64a6d6fefc0025e3882108240424650097cd4580e6011adbc673a8394e24f975de8c4436c09871e66d2fe9dd102c73ec524d6622a005514aac9960a8318cd82cb15040b7a341361da279096d9e4bf61bdd5eb7093fb77885c087b88b7181a484079380e3e32bc5642468cd8478816c8492adaeffbaa".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d00000000a383a2489aedccfab4bb41368d1c8ee310d9ee90cb3d181880ce4e0cdb36ecb71a0000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000001a3f5ec38a74ee8799405e7aad8bf265244f1e9d4226fb1099f6431a4a6170b46010e9d3077b13f04fa0e1f7af007ca1d7dc91ee0ecaf7861e54bb9c1c4fda63f471b0d02e59656f2fc0546f16d5343094147f1ae00e0f68d7fdc49b0f1b32d8dcb88dcf178eb814ec7ca64bf530415793e77da028627acf31271c88778576b049".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009be2bcf0919d50377245ca6c251b582577f5ef2e910fd731837fbe2dbb35ce87060000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000005a5a77fa5422d4fd9fd45a991fd186106c6e0fa4cd151051067ab2a8624aff0b601733b5a61cf8699646cffbabdade8ef9e63dbe837b56ad04e0962d03577259dd3dfa3161277bc4be6d02bd852cd0ab13040ecf4282fd2b9d7690fc590f3dbe61a8019051182ba872668edd426a103139870affeab5750f1cac85a6b4c15b064b".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009be2bcf0919d50377245ca6c251b582577f5ef2e910fd731837fbe2dbb35ce87020000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000003de971af0ebc17861419d05f0250c7f4f073d444df1404914c5afe0afd65ffb4600172573e316ce1509c19f327d1bb78081ba268be0a0d1ff8924436ccca488e83e71af5a6a9d882e7111deb01e363b5d2179492953fe8aa21331219a21209e68b56941dad29b0178a3d85844c680051e0816a55884b86675a6f66a6c4bbfe46e3".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d00000000b054441660f5f4f5fb1b29d3e6bbb8a48a499d94c16eb81c3f521a261b4b0944000000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000c5192f9396c9cdd34005cf129d71833f1b56e857b9d578c2b7afef862c1de0726009b7e05907bae68883c4e9ae4373244e85af47e19fe01e5fd21bc250bcde989246ff343f5b1187f103b1263379dd861712ef57af3a7943b28cc38e131381ae7bb2c8422af50872d38d569d57b20de2d9f496faf6f0e36ae5d5d5606ced2bcf5e".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009dde175afd3273d7593648c97db5de383ccb7a99e20255803d645b2581c5e84e070000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a859090000000020ba3f10dc821c8a929aeb9a32e98339fc2f7a3d64b705129777c9a39780a01e6086cf76415311b48d889f2ec97e10d9dbd751dddb4468e37975ab50fa3abaa1a4843064addbed9c169bfead30a8a05d2f0bb4dd139bd52df033c3b39056dd3eb2697747f64269ef4d1838557c054cb2d0875a6b4eafee9d90227a52b207431965".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d00000000a056be49062621290253c014de232827ac42f5b523c65f7a5d3b9d4b1d7e2dfc010000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000007db41143e8d6e3ca290a69a44797ee967e02f4297186fec08a8a0272f864369d608152ac7022000c0e57fb6b6bdc3b6c58d248dbe747b41e60b9b4506a2e0abfcebabca26cdf96984beca5595bdf6511f203b3eb7b0fbdb532e8634bf1c5865aebcce83737a52001d6dff8c3e31a45c0327b944fb582cd7366607f1b620f99aed1".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009be2bcf0919d50377245ca6c251b582577f5ef2e910fd731837fbe2dbb35ce87010000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000002cae9e9e4e356b719de38866f5a4b3727728a2a3d6a00a5f44075a015d0f9a0d600f9db982d3d07a571cbc10738d1725a2f3981c0a62c67cb6feb23f6a17c532fdc35768c384b7aece67fbea04c3113d0218de394731b6db9e9332c2b8c3478107cd1a957f750333db7862900562bedf517d2638d4ce8e891e2dd944ca6a5cfa25".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d00000000be7d6806b5c692cac6bd0822e0af879c217525302dfe96e348e88c2dc1840035000000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a85909000000002354b77c0f261f3d5b8424cbe67c2f27130f01c531732a08b8ae3f28aaa1b1fb6019fd3d18f599d6c4ae8c41be8a896773f4e75c1891330b1c3a0f94117940b3760e22befd61a0ee35d2a3538b153f3fff112eb2d8b6ff53a93331bfbed863ffc2d13ad19c09e2d7081c6e87b6c93aa1071da4535a0f67c893eeedfa6ba9815860".hexToData onChain:chain]];
    [lockVotes addObject:[DSTransactionLockVote transactionLockVoteWithMessage:@"2c3f265102cac147b55062049ceaedab67ca051177d16a374fbf042c47c2ba3375b225925624ffe3d17fee25645efb4520f429f37dba2c1483924ffeaf918e5d000000009dde175afd3273d7593648c97db5de383ccb7a99e20255803d645b2581c5e84e050000003b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000358b1a766d3e8b71f90d3fe85231f2aa3c6504cbf2be7194d65f3a4517f459d9600c0edfbad638704fb050c7220dd2f6371dbd6d25a5f49c53cb592390cb0162924467a8564118c2449ef54e95a999abe102c9d94f7a7225e39e179aca25f3dd81c3f02413409fb11f781f2a3b54cd5dfbe4b51f598f56ce6d2ff1c6f39ebc4f63".hexToData onChain:chain]];
    
    for (DSTransactionLockVote * lockVote in lockVotes) {
        [chain.chainManager.transactionManager peer:peer relayedTransactionLockVote:lockVote];
    }
    DSTransaction * transaction2 = nil;
    DSWallet * wallet = nil;
    [chain accountForTransactionHash:transaction.txHash transaction:&transaction2 wallet:&wallet];
    XCTAssertTrue(transaction2.instantSendReceived,@"Instant Send receiving not working");
}

-(void)testProviderRegistrationTransaction {
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
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:wallet];
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
//    [blockchainUserRegistrationTransaction signWithPrivateKeys:@[inputPrivateKey]];
//    NSData * inputSignature = @"473044022033bafeac5704355c7855a6ad099bd6834cbcf3b052e42ed83945c58aae904aa4022073e747d376a8dcd2b5eb89fef274b01c0194ee9a13963ebbc657963417f0acf3012102393c140e7b53f3117fd038581ae66187c4be33f49e33a4c16ffbf2db1255e985".hexToData;
//    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.inputSignatures[0],inputSignature,@"The transaction input signature isn't signing correctly");
//    
//    
//    XCTAssertEqualObjects(blockchainUserRegistrationTransaction.data,hexData,@"The transaction data does not match it's expected values");
//    XCTAssertEqualObjects([NSData dataWithUInt256:txId],[NSData dataWithUInt256:blockchainUserRegistrationTransaction.txHash],@"The transaction does not match it's desired private key");
}

-(void)testProviderUpdateServiceTransaction {
    DSChain * chain = [DSChain testnet];
    
    NSString * seedPhrase = @"enemy check owner stumble unaware debris suffer peanut good fabric bleak outside";
    
    NSData * seed = [[DSBIP39Mnemonic sharedInstance]
                     deriveKeyFromPhrase:seedPhrase withPassphrase:nil];
    
    DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:0 forChain:chain storeSeedPhrase:NO isTransient:YES];
    
    NSData * hexData = [NSData dataFromHexString:@"030002000151f9d127275f3f8c1947a4f1067d9a02d6f97d4969be727b533ad6ad5286e7d7010000006a473044022005abb2ae572d2c4cb844456be8f50c2b059d9930bc1aa875d7946403f1c3825b02202044de1694773749830cc5e942d19f2037d94882b618eaac3a25f86b855d406d01210261dc0b26e9a64808928a3d020565f5daa31ff0e01904254ce0a19e8ce449918affffffff01cd8aa95a020000001976a9142044e419a66b4e1bc7b4594e4722a85d469134bf88ac00000000b5010051f9d127275f3f8c1947a4f1067d9a02d6f97d4969be727b533ad6ad5286e7d700000000000000000000ffff342440944e1f002ef5cb8f99816474b9620eb266c4e7ed768586f6a4d90a71f0b3ffaaefd5427a14e7cbcfe3888a28c161bf7d4dd0e30273be7e4de0b90991a8010398630a62740b2426297ce3cae717ae9d3aa069267c046660fbce055d5922ae2fadf89a8e6d98f0d9f8db7bebc80743219de4ad7b2f20429b8bcfb428877f62265c5c10f1e6"];
    UInt256 txId = *(UInt256 *)@"fef8c6f481fd3739f2fd2b67904f8d29fb310dc23c7e536eefb05fcab0803e20".hexToData.reverse.bytes;
    UInt256 inputId = *(UInt256 *)@"51f9d127275f3f8c1947a4f1067d9a02d6f97d4969be727b533ad6ad5286e7d7".hexToData.reverse.bytes;
    NSString * inputAddress0 = @"yWcZ7ePLX3yLkC3Aj9KaZvxRQkkZC6VPL8";
    DSECDSAKey * inputPrivateKey0 = [wallet privateKeyForAddress:inputAddress0 fromSeed:seed];
    
    NSString * checkInputAddress0 = [inputPrivateKey0 addressForChain:chain];
    XCTAssertEqualObjects(checkInputAddress0,inputAddress0,@"Private key does not match input address");
    
    DSProviderUpdateServiceTransaction *providerUpdateServiceTransactionFromMessage = [[DSProviderUpdateServiceTransaction alloc] initWithMessage:hexData onChain:chain];
    
    XCTAssertEqualObjects(providerUpdateServiceTransactionFromMessage.toData,hexData,@"Provider update service transaction does not match it's data");
    
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:wallet];
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:wallet.uniqueID];
    }
    
    UInt256 operatorSecretKey = [NSData dataFromHexString:@"17b47bb0f2a3298ee8f9d07fdafc1e8552869d11cef81e13a2706e2fdbf50dc5"].UInt256;
    
    DSBLSKey * privateKey = [DSBLSKey blsKeyWithPrivateKey:operatorSecretKey onChain:chain];
    
    UInt384 operatorKeyNeeded =[NSData dataFromHexString:@"859bdc161a8a246a572cbc0c1928faacecbc12133b64f18480a32938eec081129016e99929caea89f317a33adfe82111"].UInt384;
    
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
}


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
