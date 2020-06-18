//
//  DSWalletTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 20/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSChain.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "DSAccount.h"
#import "DSWallet+Protected.h"
#import "DSECDSAKey.h"
#import "DSTransaction.h"
#import "DSPriceManager.h"

@interface DSWalletTests : XCTestCase

@end

@implementation DSWalletTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

// MARK: - testWallet

//TODO: test standard free transaction no change
//TODO: test free transaction who's inputs are too new to hit min free priority
//TODO: test transaction with change below min allowable output
//TODO: test gap limit with gaps in address chain less than the limit
//TODO: test removing a transaction that other transansactions depend on
//TODO: test tx ordering for multiple tx with same block height
//TODO: port all applicable tests from dashj and dashcore

//- (void)testWallet
//{
//    NSMutableData *script = [NSMutableData data];
//    UInt256 secret = *(UInt256 *)@"0000000000000000000000000000000000000000000000000000000000000001".hexToData.bytes;
//    DSKey *k = [DSKey keyWithSecret:secret compressed:YES];
//    NSValue *hash = uint256_obj(UINT256_ZERO);
//    DSBIP32Sequence * sequence = [DSBIP32Sequence new];
//    NSData * emptyData = [NSData data];
//    NSData * master32Pub = [sequence extendedPublicKeyForAccount:0 fromSeed:emptyData purpose:BIP32_PURPOSE];
//    NSData * master44Pub = [sequence extendedPublicKeyForAccount:0 fromSeed:emptyData purpose:BIP44_PURPOSE];
//    DSWallet *w = [[DSWallet alloc] initWithContext:nil sequence:sequence masterBIP44PublicKey:master44Pub masterBIP32PublicKey:master32Pub requestSeedBlock:^(NSString * _Nullable authprompt, uint64_t amount, SeedCompletionBlock  _Nullable seedCompletion) {
//        //this happens when we request the seed
//        seedCompletion([NSData data]);
//    }];
//
//    [script appendScriptPubKeyForAddress:k.address];
//
//    NSArray * inputHashes = @[hash];
//    NSArray * inputIndexes = @[@(0)];
//    NSArray * inputScripts = @[script];
//    NSArray * outputAddresses = @[w.receiveAddress];
//    NSArray * outputAmounts = @[@(DUFFS)];
//    DSTransaction *tx = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                   outputAddresses:outputAddresses outputAmounts:outputAmounts];
//
//    [tx signWithSerializedPrivateKeys:@[k.privateKey]];
//    [w registerTransaction:tx];
//
//    XCTAssertEqual(w.balance, DUFFS, @"[DSWallet registerTransaction]");
//
//    tx = [DSTransaction new];
//    [tx addInputHash:UINT256_ZERO index:2 script:script signature:NULL sequence:UINT32_MAX - 1];
//    [tx addOutputAddress:w.receiveAddress amount:DUFFS];
//    tx.lockTime = 1000;
//    tx.blockHeight = TX_UNCONFIRMED;
//    [tx signWithSerializedPrivateKeys:@[k.privateKey]];
//    [w registerTransaction:tx]; // test pending tx with future lockTime
//
//    XCTAssertEqual(w.balance, DUFFS, @"[DSWallet registerTransaction]");
//
//    [w setBlockHeight:1000 andTimestamp:1 forTransactionHashes:@[uint256_obj(tx.txHash)]];
//    XCTAssertEqual(w.balance, DUFFS*2, @"[DSWallet registerTransaction]");
//
//    tx = [w transactionFor:DUFFS/2 to:k.address withFee:NO];
//
//    XCTAssertNotNil(tx, @"[DSWallet transactionFor:to:withFee:]");
//
//    [w signTransaction:tx withPrompt:@"" completion:^(BOOL signedTransaction) {
//        XCTAssertTrue(tx.isSigned, @"[DSWallet signTransaction]");
//    }];
//
//
//
//    [w registerTransaction:tx];
//
//    XCTAssertEqual(w.balance, DUFFS*3/2, @"[DSWallet balance]");
//
//    w = [[DSWallet alloc] initWithContext:nil sequence:sequence masterBIP44PublicKey:master44Pub masterBIP32PublicKey:master32Pub
//                         requestSeedBlock:^(NSString * _Nullable authprompt, uint64_t amount, SeedCompletionBlock  _Nullable seedCompletion) {
//                             seedCompletion([NSData data]);
//                         }];
//
//    // hack to make the following transactions belong to the wallet
//    NSMutableSet *allAddresses = [(id)w performSelector:@selector(allAddresses)];
//
//    [allAddresses addObject:@"XnsafFUbkcPBi9KEa3cQgE7EMMTTYaNS3h"];
//
//    DSTransaction *tx1 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XnsafFUbkcPBi9KEa3cQgE7EMMTTYaNS3h", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XgrsfVaLgXKimVwhekNNNQzFrykrbDmz6J"];
//
//    DSTransaction *tx2 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XgrsfVaLgXKimVwhekNNNQzFrykrbDmz6J", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XoJVWknX7R6gBKRSGMCG8U4vPKwGihCgHq"];
//
//    DSTransaction *tx3 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XoJVWknX7R6gBKRSGMCG8U4vPKwGihCgHq", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XjSZL2LeJ1Un8r7Lz9rHWLggKkvT5mc1pV"];
//
//    DSTransaction *tx4 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XjSZL2LeJ1Un8r7Lz9rHWLggKkvT5mc1pV", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XrLVS73GdwMbGQxJWqdboq5QQmZ6ePLzpH"];
//
//    DSTransaction *tx5 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XrLVS73GdwMbGQxJWqdboq5QQmZ6ePLzpH", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XkZRnRwg6oFSVTG4P8VUeaM5EGmzxQGx2T"];
//
//    DSTransaction *tx6 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XkZRnRwg6oFSVTG4P8VUeaM5EGmzxQGx2T", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [allAddresses addObject:@"XvJvi4gShPzadCLUownkEtFRRedrUFw8j6"];
//
//    DSTransaction *tx7 = [[DSTransaction alloc] initWithInputHashes:inputHashes inputIndexes:inputIndexes inputScripts:inputScripts
//                                                    outputAddresses:@[@"XvJvi4gShPzadCLUownkEtFRRedrUFw8j6", @"Xs3gc64pedMWPz5gLvmZQQbJi4uYzPUxct"] outputAmounts:@[@100000000, @4900000000]];
//
//    [tx1 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx2 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx3 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx4 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx5 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx6 signWithSerializedPrivateKeys:@[k.privateKey]];
//    [tx7 signWithSerializedPrivateKeys:@[k.privateKey]];
//
//    [w registerTransaction:tx1];
//    [w registerTransaction:tx2];
//    [w registerTransaction:tx3];
//    [w registerTransaction:tx4];
//    [w registerTransaction:tx5];
//    [w registerTransaction:tx6];
//    [w registerTransaction:tx7];
//
//    // larger than 1k transaction
//    tx = [w transactionFor:25000000 to:@"XvQbGBRz8fokqot7BnnjjSLWWi41BgwujN" withFee:YES];
//    NSLog(@"fee: %llu, should be %llu", [w feeForTransaction:tx], [w feeForTxSize:tx.size isInstant:FALSE inputCount:0]);
//
//    int64_t amount = [w amountReceivedFromTransaction:tx] - [w amountSentByTransaction:tx],
//    fee = [w feeForTxSize:tx.size isInstant:FALSE inputCount:0] + ((w.balance - 25000000) % 100);
//
//    XCTAssertEqual([w feeForTransaction:tx], fee, @"[DSWallet transactionFor:to:withFee:]");
//    XCTAssertEqual(amount, -25000000 - fee);
//
//    XCTAssertEqual([w feeForTxSize:tx.size isInstant:FALSE inputCount:0], tx.standardFee, @"[DSWallet feeForTxSize:]");
//}

-(void)testChainSynchronizationFingerprintFixedData {
    NSArray * randomBlockZones = @[@(7),@(68),@(91),@(130),@(132),@(135),@(137),@(154)];
    NSOrderedSet * blockZones = [NSOrderedSet orderedSetWithArray:randomBlockZones];
    NSData * chainSynchronizationFingerprint = [DSWallet chainSynchronizationFingerprintForBlockZones:blockZones forChainHeight:1000000];
    XCTAssertEqualObjects(chainSynchronizationFingerprint.hexString,@"0107d000070044005b0082a5008040",@"Error with ChainSynchronizationFingerprint");
    NSOrderedSet * rblockZones = [DSWallet blockZonesFromChainSynchronizationFingerprint:chainSynchronizationFingerprint];
    XCTAssertEqualObjects(blockZones,rblockZones,@"Error with ChainSynchronizationFingerprint");
}

-(void)testChainSynchronizationFingerprint {
    NSMutableArray * randomBlockZones = [NSMutableArray array];
    //create 2 zones, zone 1 (<50000) is twice as less populated
    for (uint16_t i = 0; i< 50;i++) {
        [randomBlockZones addObject:@(arc4random_uniform(1000))];
        [randomBlockZones addObject:@(500 + arc4random_uniform(500))];
    }
    [randomBlockZones sortUsingSelector:@selector(compare:)];
    NSOrderedSet * blockZones = [NSOrderedSet orderedSetWithArray:randomBlockZones];
    NSData * chainSynchronizationFingerprint = [DSWallet chainSynchronizationFingerprintForBlockZones:blockZones forChainHeight:1000000];
    NSOrderedSet * rblockZones = [DSWallet blockZonesFromChainSynchronizationFingerprint:chainSynchronizationFingerprint];
    XCTAssertEqualObjects(blockZones,rblockZones,@"Error with ChainSynchronizationFingerprint");
}

// MARK: - testWalletManager

- (void)testWalletManager
{
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    NSString *s;
    
    XCTAssertEqual([manager amountForDashString:@""], 0, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:0];
    XCTAssertEqual([manager amountForDashString:s], 0, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:100000000];
    XCTAssertEqual([manager amountForDashString:s], 100000000, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:1];
    XCTAssertEqual([manager amountForDashString:s], 1, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:2100000000000000];
    XCTAssertEqual([manager amountForDashString:s], 2100000000000000, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:2099999999999999];
    XCTAssertEqual([manager amountForDashString:s], 2099999999999999, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:2099999999999995];
    XCTAssertEqual([manager amountForDashString:s], 2099999999999995, @"[DSPriceManager amountForDashString:]");
    
    s = [manager stringForDashAmount:2099999999999990];
    XCTAssertEqual([manager amountForDashString:s], 2099999999999990, @"[DSPriceManager amountForDashString:]");
}

@end
