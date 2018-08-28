//
//  DSTransactionTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSKey.h"
#import "DSChain.h"
#import "NSString+Bitcoin.h"
#import "DSTransaction.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSTransactionFactory.h"
#import "DSChainManager.h"
#import "NSData+Dash.h"

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
    DSKey *k = [DSKey keyWithSecret:secret compressed:YES];
    NSValue *hash = uint256_obj(UINT256_ZERO);
    
    [script appendScriptPubKeyForAddress:[k addressForChain:self.chain] forChain:self.chain];
    
    DSTransaction *tx = [[DSTransaction alloc] initWithInputHashes:@[hash] inputIndexes:@[@0] inputScripts:@[script]
                                                   outputAddresses:@[[k addressForChain:self.chain], [k addressForChain:self.chain]] outputAmounts:@[@100000000, @4900000000]
                                                           onChain:self.chain];
    
    [tx signWithPrivateKeys:@[[k privateKeyStringForChain:self.chain]]];
    
    XCTAssertTrue([tx isSigned], @"[DSTransaction signWithPrivateKeys:]");
    
    NSUInteger height = [tx blockHeightUntilFreeForAmounts:@[@5000000000] withBlockHeights:@[@1]];
    uint64_t priority = [tx priorityForAmounts:@[@5000000000] withAges:@[@(height - 1)]];
    
    NSLog(@"height = %lu", (unsigned long)height);
    NSLog(@"priority = %llu", priority);
    
    XCTAssertTrue(priority >= TX_FREE_MIN_PRIORITY, @"[DSTransaction priorityForAmounts:withAges:]");
    
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
    
    height = [tx blockHeightUntilFreeForAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                                                  @1000000, @1000000, @1000000]
                               withBlockHeights:@[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10]];
    priority = [tx priorityForAmounts:@[@1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000, @1000000,
                                        @1000000, @1000000]
                             withAges:@[@(height - 1), @(height - 2), @(height - 3), @(height - 4), @(height - 5), @(height - 6),
                                        @(height - 7), @(height - 8), @(height - 9), @(height - 10)]];
    
    NSLog(@"height = %lu", (unsigned long)height);
    NSLog(@"priority = %llu", priority);
    
    XCTAssertTrue(priority >= TX_FREE_MIN_PRIORITY, @"[DSTransaction priorityForAmounts:withAges:]");
    
    d = tx.data;
    tx = [DSTransaction transactionWithMessage:d onChain:self.chain];
    
    XCTAssertEqualObjects(d, tx.data, @"[DSTransaction transactionWithMessage:]");
}

- (void)testBlockchainUserTransactionPayload {
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    DSKey * key = [DSKey keyWithPrivateKey:@"cTu5paPRRZ1bby6XPR9oLmJ8XsasXm699xVCMGJuEVFu7qaU8uS5" onChain:devnetDRA];
    UInt160 pubkeyHash = *(UInt160 *)@"43bfdea7363e6ea738da5059987c7232b58d2afe".hexToData.bytes;
    
    XCTAssertTrue(uint160_eq(pubkeyHash, key.publicKey.hash160), @"Pubkey Hash does not Pubkey");
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
    DSKey * privateKey = [DSKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];
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
    DSKey * privateKey = [DSKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];

    NSString * checkInputAddress = [privateKey addressForChain:devnetDRA];
    XCTAssertEqualObjects(checkInputAddress,inputAddress,@"Private key does not match input address");
    
    DSKey * payloadKey = [DSKey keyWithPrivateKey:@"cVBJqSygvC7hHQVuarUZQv868NgHUavceAfeqgo32LYiBYYswTv6" onChain:devnetDRA];
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
    DSKey * privateKey = [DSKey keyWithPrivateKey:inputPrivateKey onChain:devnetDRA];
    
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


@end
