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

- (void)testBlockchainUserTransaction {
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    DSKey * key = [DSKey keyWithPrivateKey:@"cTu5paPRRZ1bby6XPR9oLmJ8XsasXm699xVCMGJuEVFu7qaU8uS5" onChain:devnetDRA];
    UInt160 pubkeyHash = *(UInt160 *)@"43bfdea7363e6ea738da5059987c7232b58d2afe".hexToData.bytes;
    
    XCTAssertTrue(uint160_eq(pubkeyHash, key.publicKey.hash160), @"Pubkey Hash does not Pubkey");
    DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:@"crazy1" pubkeyHash:pubkeyHash onChain:devnetDRA];
    UInt256 payloadHash = blockchainUserRegistrationTransaction.payloadHash;
    NSData * payloadHashDataToConfirm = @"912956c5cbf77a5c3b7cb9ae928bcccd5f7780c48a56d9ffd9ad3a2cb1ad60ce".hexToData;
    NSData * payloadHashDataToConfirmReverse = @"912956c5cbf77a5c3b7cb9ae928bcccd5f7780c48a56d9ffd9ad3a2cb1ad60ce".hexToData.reverse;
    XCTAssertEqualObjects([NSData dataWithUInt256:payloadHash],payloadHashDataToConfirm,@"Pubkey Hash does not match Pubkey");
    XCTAssertEqualObjects([NSData dataWithUInt256:payloadHash],payloadHashDataToConfirmReverse,@"Pubkey Hash does not match Pubkey Reverse");
}


@end
