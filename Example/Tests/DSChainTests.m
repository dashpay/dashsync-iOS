//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>

#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSBlock+Protected.h"
#import "DSChain+Protected.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSCheckpoint.h"
#import "DSFullBlock.h"
#import "DSMerkleBlock.h"
#import "DSQuorumCommitmentTransaction.h"
#import "DSWallet+Protected.h"
#import "DashSync.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"

@interface DSChainTests : XCTestCase

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSWallet *wallet;

@end

@implementation DSChainTests

- (void)setUp {
    self.chain = [DSChain setUpDevnetWithIdentifier:@"devnet-mobile-2" version:1 protocolVersion:PROTOCOL_VERSION_DEVNET minProtocolVersion:DEFAULT_MIN_PROTOCOL_VERSION_DEVNET withCheckpoints:nil withMinimumDifficultyBlocks:UINT32_MAX withDefaultPort:3000 withDefaultDapiJRPCPort:3000 withDefaultDapiGRPCPort:3010 dpnsContractID:UINT256_ZERO dashpayContractID:UINT256_ZERO ISLockQuorumType:DSLLMQType_50_60 ISDLockQuorumType:DSLLMQType_60_75 chainLockQuorumType:DSLLMQType_50_60 platformQuorumType:DSLLMQType_100_67 masternodeSyncMode:DSMasternodeSyncMode_Mixed isTransient:YES];
    for (DSWallet *wallet in [self.chain.wallets copy]) {
        if ([wallet.transientDerivedKeyData isEqualToData:@"000102030405060708090a0b0c0d0e0f".hexToData]) {
            [self.chain unregisterWallet:wallet];
        }
    }
    self.wallet = [DSWallet transientWalletWithDerivedKeyData:@"000102030405060708090a0b0c0d0e0f".hexToData forChain:self.chain];
    [self.chain addWallet:self.wallet];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBEAdding {
    UInt256 chainWork1 = @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 numberToAdd = @"0000000000000000000000000000000000000000000000000000000000000111".hexToData.UInt256;
    UInt256 addition = uInt256AddBE(chainWork1, numberToAdd);
    XCTAssertEqualObjects(uint256_hex(addition), @"00000000000000000000000000000000000000000000336e9ee70cf4694c040a");
}

- (void)testBESubstraction1 {
    UInt256 chainWork1 = @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 numberToSubstract = @"0000000000000000000000000000000000000000000000000000000000000311".hexToData.UInt256;
    UInt256 substraction = uInt256SubtractBE(chainWork1, numberToSubstract);
    XCTAssertEqualObjects(uint256_hex(substraction), @"00000000000000000000000000000000000000000000336e9ee70cf4694bffe8");
}

- (void)testBESubstraction2 {
    UInt256 chainWork1 = @"00000000000000000000000000000000000000000000336ea946ab063dcd3016".hexToData.UInt256;
    UInt256 numberToSubstract = @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 substraction = uInt256SubtractBE(chainWork1, numberToSubstract);
    XCTAssertEqualObjects(uint256_hex(substraction), @"0000000000000000000000000000000000000000000000000a5f9e11d4812d1d");
}

- (void)testChainWork {
    //    block 1283540
    //    chainwork 00000000000000000000000000000000000000000000336e9ee70cf4694c02f9
    //    target 19180f4a
    //    block 1283541
    //    chainwork 00000000000000000000000000000000000000000000336ea946ab063dcd3016
    //    target 1918ada2
    UInt256 chainWork1 = @"00000000000000000000000000000000000000000000336ea946ab063dcd3016".hexToData.UInt256;
    UInt256 chainWork2 = @"00000000000000000000000000000000000000000000336e9ee70cf4694c02f9".hexToData.UInt256;
    UInt256 diffChainWork = @"0000000000000000000000000000000000000000000000000a5f9e11d4812d1d".hexToData.UInt256;
    UInt256 diffChainWorkToVerify = uInt256SubtractBE(chainWork1, chainWork2);
    XCTAssertEqualObjects(uint256_hex(diffChainWorkToVerify), uint256_hex(diffChainWork));
    UInt256 target = setCompactLE(0x1918ada2);
    UInt256 work = uInt256AddOneLE(uInt256DivideLE(uint256_inverse(target), uInt256AddOneLE(target)));
    XCTAssertEqualObjects(uint256_hex(target), @"00000000000000000000000000000000000000000000a2ad1800000000000000");
    XCTAssertEqualObjects(uint256_hex(work), @"1d2d81d4119e5f0a000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(uint256_reverse_hex(work), uint256_hex(diffChainWork));
}

- (void)testSimpleReorg {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    XCTAssertEqual(self.chain.estimatedBlockHeight, 150);
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *headerData = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    DSMerkleBlock *merkleBlockFork = [DSMerkleBlock merkleBlockWithMessage:headerData onChain:self.chain];
    [self.chain addBlock:merkleBlockFork receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 106);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    DSFullBlock *blockFork = [DSFullBlock fullBlockWithMessage:blockData onChain:self.chain];

    for (DSTransaction *transaction in blockFork.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }

    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10000000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);
}

- (void)testComplexReorg {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *header106Data = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    NSData *header107Data = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f2000000000".hexToData;

    NSData *header108Data = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f2001000000".hexToData;

    NSData *header109Data = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f2004000000".hexToData;

    NSData *header110Data = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f2002000000".hexToData;

    DSMerkleBlock *merkleBlockFork106 = [DSMerkleBlock merkleBlockWithMessage:header106Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork106 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork107 = [DSMerkleBlock merkleBlockWithMessage:header107Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork107 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork108 = [DSMerkleBlock merkleBlockWithMessage:header108Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork108 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork109 = [DSMerkleBlock merkleBlockWithMessage:header109Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork109 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork110 = [DSMerkleBlock merkleBlockWithMessage:header110Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork110 receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
        XCTAssertEqual(self.chain.lastTerminalBlockHeight, MAX(110, merkleBlock.height));
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData106 = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    NSData *blockData107 = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f20000000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016b0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006b000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006b000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData108 = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f20010000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016c0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006c000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006c000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData109 = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f20040000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016d0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006d000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006d000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData110 = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016e0101ffffffff01e288526a740000002321031cb7f55495e8dcfd985114bd870cc4d3b8ed53d4b43bfab75beea36676a352a5ac000000002601006e000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006e000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b32000000000000003200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000017f38ad14ba2fd1edfb3cba5dbc99b30844c3ddfbad35129e858433f46ec8d34e010000006a47304402204972e37e8b7ae4aeb30388b79dfb6067fe6a2d3fd751e1031b924b857bfe483c02200c58de282b10dc536a161b34a606890779d552ba618738018ad1f21f669912540121038d18456ebe83c1650166a1d5145c9a9456b35f9258338b54d98257b968b765dafeffffff0200e1f505000000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac3cc15010720000001976a914dc8f9ddbe48e754d371e5866b80dad846805fe2f88ac6d000000".hexToData;

    NSData *blockData106Extra = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c971b6d49c7f53e91b0ebc14c2ac7803217d495f7ea918961491fc360769438f31e9f275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a7400000023210331f1f3f109cc50326387fd31411cb5ee224a75493fa173a41b66c8a9ebb2398eac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    DSFullBlock *blockFork106 = [DSFullBlock fullBlockWithMessage:blockData106 onChain:self.chain];
    DSFullBlock *blockFork107 = [DSFullBlock fullBlockWithMessage:blockData107 onChain:self.chain];
    DSFullBlock *blockFork108 = [DSFullBlock fullBlockWithMessage:blockData108 onChain:self.chain];
    DSFullBlock *blockFork109 = [DSFullBlock fullBlockWithMessage:blockData109 onChain:self.chain];
    DSFullBlock *blockFork110 = [DSFullBlock fullBlockWithMessage:blockData110 onChain:self.chain];
    DSFullBlock *blockFork106Extra = [DSFullBlock fullBlockWithMessage:blockData106Extra onChain:self.chain];

    for (DSTransaction *transaction in blockFork106.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork106 receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }


    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    [self.chain addBlock:blockFork107 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork108 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork109 receivedAsHeader:NO fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork110];
    }

    [self.chain addBlock:blockFork110
        receivedAsHeader:NO
                fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106Extra.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106Extra];
    }

    [self.chain addBlock:blockFork106Extra
        receivedAsHeader:NO
                fromPeer:nil];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);
}

- (void)testComplexReorgWithChainLock {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *header106Data = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    NSData *header107Data = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f2000000000".hexToData;

    NSData *header108Data = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f2001000000".hexToData;

    NSData *header109Data = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f2004000000".hexToData;

    NSData *header110Data = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f2002000000".hexToData;

    DSMerkleBlock *merkleBlockFork106 = [DSMerkleBlock merkleBlockWithMessage:header106Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork106 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork107 = [DSMerkleBlock merkleBlockWithMessage:header107Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork107 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork108 = [DSMerkleBlock merkleBlockWithMessage:header108Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork108 receivedAsHeader:YES fromPeer:nil];

    DSChainLock *chainLock = [[DSChainLock alloc] initWithBlockHash:merkleBlockFork108.blockHash signature:UINT768_ZERO signatureVerified:YES quorumVerified:YES onChain:self.chain];

    [self.chain addChainLock:chainLock];

    DSMerkleBlock *merkleBlockFork109 = [DSMerkleBlock merkleBlockWithMessage:header109Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork109 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork110 = [DSMerkleBlock merkleBlockWithMessage:header110Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork110 receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
        XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData106 = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    NSData *blockData107 = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f20000000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016b0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006b000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006b000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData108 = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f20010000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016c0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006c000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006c000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData109 = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f20040000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016d0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006d000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006d000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData110 = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016e0101ffffffff01e288526a740000002321031cb7f55495e8dcfd985114bd870cc4d3b8ed53d4b43bfab75beea36676a352a5ac000000002601006e000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006e000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b32000000000000003200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000017f38ad14ba2fd1edfb3cba5dbc99b30844c3ddfbad35129e858433f46ec8d34e010000006a47304402204972e37e8b7ae4aeb30388b79dfb6067fe6a2d3fd751e1031b924b857bfe483c02200c58de282b10dc536a161b34a606890779d552ba618738018ad1f21f669912540121038d18456ebe83c1650166a1d5145c9a9456b35f9258338b54d98257b968b765dafeffffff0200e1f505000000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac3cc15010720000001976a914dc8f9ddbe48e754d371e5866b80dad846805fe2f88ac6d000000".hexToData;

    NSData *blockData106Extra = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c971b6d49c7f53e91b0ebc14c2ac7803217d495f7ea918961491fc360769438f31e9f275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a7400000023210331f1f3f109cc50326387fd31411cb5ee224a75493fa173a41b66c8a9ebb2398eac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    DSFullBlock *blockFork106 = [DSFullBlock fullBlockWithMessage:blockData106 onChain:self.chain];
    DSFullBlock *blockFork107 = [DSFullBlock fullBlockWithMessage:blockData107 onChain:self.chain];
    DSFullBlock *blockFork108 = [DSFullBlock fullBlockWithMessage:blockData108 onChain:self.chain];
    DSFullBlock *blockFork109 = [DSFullBlock fullBlockWithMessage:blockData109 onChain:self.chain];
    DSFullBlock *blockFork110 = [DSFullBlock fullBlockWithMessage:blockData110 onChain:self.chain];
    DSFullBlock *blockFork106Extra = [DSFullBlock fullBlockWithMessage:blockData106Extra onChain:self.chain];

    for (DSTransaction *transaction in blockFork106.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork106 receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }


    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    [self.chain addBlock:blockFork107 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork108 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork109 receivedAsHeader:NO fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork110];
    }

    [self.chain addBlock:blockFork110
        receivedAsHeader:NO
                fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106Extra.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106Extra];
    }

    [self.chain addBlock:blockFork106Extra
        receivedAsHeader:NO
                fromPeer:nil];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);
}

- (void)testComplexReorgThenChainLockOnDiscardedFork {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *header106Data = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    NSData *header107Data = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f2000000000".hexToData;

    NSData *header108Data = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f2001000000".hexToData;

    NSData *header109Data = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f2004000000".hexToData;

    NSData *header110Data = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f2002000000".hexToData;

    DSMerkleBlock *merkleBlockFork106 = [DSMerkleBlock merkleBlockWithMessage:header106Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork106 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork107 = [DSMerkleBlock merkleBlockWithMessage:header107Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork107 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork108 = [DSMerkleBlock merkleBlockWithMessage:header108Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork108 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork109 = [DSMerkleBlock merkleBlockWithMessage:header109Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork109 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork110 = [DSMerkleBlock merkleBlockWithMessage:header110Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork110 receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
        XCTAssertEqual(self.chain.lastTerminalBlockHeight, MAX(110, merkleBlock.height));
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData106 = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    NSData *blockData107 = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f20000000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016b0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006b000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006b000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData108 = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f20010000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016c0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006c000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006c000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData109 = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f20040000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016d0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006d000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006d000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData110 = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016e0101ffffffff01e288526a740000002321031cb7f55495e8dcfd985114bd870cc4d3b8ed53d4b43bfab75beea36676a352a5ac000000002601006e000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006e000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b32000000000000003200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000017f38ad14ba2fd1edfb3cba5dbc99b30844c3ddfbad35129e858433f46ec8d34e010000006a47304402204972e37e8b7ae4aeb30388b79dfb6067fe6a2d3fd751e1031b924b857bfe483c02200c58de282b10dc536a161b34a606890779d552ba618738018ad1f21f669912540121038d18456ebe83c1650166a1d5145c9a9456b35f9258338b54d98257b968b765dafeffffff0200e1f505000000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac3cc15010720000001976a914dc8f9ddbe48e754d371e5866b80dad846805fe2f88ac6d000000".hexToData;

    NSData *blockData106Extra = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c971b6d49c7f53e91b0ebc14c2ac7803217d495f7ea918961491fc360769438f31e9f275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a7400000023210331f1f3f109cc50326387fd31411cb5ee224a75493fa173a41b66c8a9ebb2398eac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    DSFullBlock *blockFork106 = [DSFullBlock fullBlockWithMessage:blockData106 onChain:self.chain];
    DSFullBlock *blockFork107 = [DSFullBlock fullBlockWithMessage:blockData107 onChain:self.chain];
    DSFullBlock *blockFork108 = [DSFullBlock fullBlockWithMessage:blockData108 onChain:self.chain];
    DSFullBlock *blockFork109 = [DSFullBlock fullBlockWithMessage:blockData109 onChain:self.chain];
    DSFullBlock *blockFork110 = [DSFullBlock fullBlockWithMessage:blockData110 onChain:self.chain];
    DSFullBlock *blockFork106Extra = [DSFullBlock fullBlockWithMessage:blockData106Extra onChain:self.chain];

    for (DSTransaction *transaction in blockFork106.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork106 receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }


    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    [self.chain addBlock:blockFork107 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork108 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork109 receivedAsHeader:NO fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork110];
    }

    [self.chain addBlock:blockFork110
        receivedAsHeader:NO
                fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106Extra.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106Extra];
    }

    [self.chain addBlock:blockFork106Extra
        receivedAsHeader:NO
                fromPeer:nil];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);

    DSChainLock *chainLock = [[DSChainLock alloc] initWithBlockHash:merkleBlockFork108.blockHash signature:UINT768_ZERO signatureVerified:YES quorumVerified:YES onChain:self.chain];

    [self.chain addChainLock:chainLock];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);
}


- (void)testChaintipExtension {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);
}

- (void)testChaintipBadExtension {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        BOOL success = [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
        XCTAssertTrue(success);
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);

    UInt256 blockHash = UINT256_MAX;
    UInt256 merkleRoot = uint256_random;
    UInt256 chainWork = uInt256AddOneLE(uInt256AddOneLE(self.chain.lastTerminalBlock.chainWork)); // add 2 which is minimum work

    DSMerkleBlock *fakeBlock106 = [[DSMerkleBlock alloc] initWithVersion:1 blockHash:blockHash prevBlock:self.chain.lastTerminalBlock.blockHash timestamp:self.chain.lastTerminalBlock.timestamp + 75 merkleRoot:merkleRoot target:self.chain.lastTerminalBlock.target chainWork:chainWork height:BLOCK_UNKNOWN_HEIGHT onChain:self.chain];

    [self.chain addBlock:fakeBlock106 receivedAsHeader:NO fromPeer:nil];

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);
}

- (void)testChaintipReorg {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *header106Data = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    NSData *header107Data = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f2000000000".hexToData;

    NSData *header108Data = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f2001000000".hexToData;

    NSData *header109Data = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f2004000000".hexToData;

    NSData *header110Data = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f2002000000".hexToData;

    DSMerkleBlock *merkleBlockFork106 = [DSMerkleBlock merkleBlockWithMessage:header106Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork106 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork107 = [DSMerkleBlock merkleBlockWithMessage:header107Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork107 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork108 = [DSMerkleBlock merkleBlockWithMessage:header108Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork108 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork109 = [DSMerkleBlock merkleBlockWithMessage:header109Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork109 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork110 = [DSMerkleBlock merkleBlockWithMessage:header110Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork110 receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData106 = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    NSData *blockData107 = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f20000000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016b0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006b000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006b000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData108 = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f20010000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016c0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006c000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006c000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData109 = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f20040000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016d0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006d000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006d000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData110 = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016e0101ffffffff01e288526a740000002321031cb7f55495e8dcfd985114bd870cc4d3b8ed53d4b43bfab75beea36676a352a5ac000000002601006e000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006e000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b32000000000000003200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000017f38ad14ba2fd1edfb3cba5dbc99b30844c3ddfbad35129e858433f46ec8d34e010000006a47304402204972e37e8b7ae4aeb30388b79dfb6067fe6a2d3fd751e1031b924b857bfe483c02200c58de282b10dc536a161b34a606890779d552ba618738018ad1f21f669912540121038d18456ebe83c1650166a1d5145c9a9456b35f9258338b54d98257b968b765dafeffffff0200e1f505000000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac3cc15010720000001976a914dc8f9ddbe48e754d371e5866b80dad846805fe2f88ac6d000000".hexToData;

    DSFullBlock *blockFork106 = [DSFullBlock fullBlockWithMessage:blockData106 onChain:self.chain];
    DSFullBlock *blockFork107 = [DSFullBlock fullBlockWithMessage:blockData107 onChain:self.chain];
    DSFullBlock *blockFork108 = [DSFullBlock fullBlockWithMessage:blockData108 onChain:self.chain];
    DSFullBlock *blockFork109 = [DSFullBlock fullBlockWithMessage:blockData109 onChain:self.chain];
    DSFullBlock *blockFork110 = [DSFullBlock fullBlockWithMessage:blockData110 onChain:self.chain];

    for (DSTransaction *transaction in blockFork106.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork106 receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }


    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    [self.chain addBlock:blockFork107 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork108 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork109 receivedAsHeader:NO fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork110];
    }

    [self.chain addBlock:blockFork110
        receivedAsHeader:NO
                fromPeer:nil];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);
}

- (void)testChaintipChainLockReorg {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
    }

    XCTAssertEqualObjects(uint256_hex(self.chain.lastTerminalBlock.chainWork), @"d400000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 105);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    DSAccount *account = self.wallet.accounts[0];
    XCTAssertEqualObjects(account.receiveAddress, @"yWq16XLivcRsCLcxWKbKPxJ35XASd4r9RY", @"Not matching receive address");

    NSData *header106Data = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f2001000000".hexToData;

    NSData *header107Data = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f2000000000".hexToData;

    NSData *header108Data = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f2001000000".hexToData;

    NSData *header109Data = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f2004000000".hexToData;

    NSData *header110Data = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f2002000000".hexToData;

    DSMerkleBlock *merkleBlockFork106 = [DSMerkleBlock merkleBlockWithMessage:header106Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork106 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork107 = [DSMerkleBlock merkleBlockWithMessage:header107Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork107 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork108 = [DSMerkleBlock merkleBlockWithMessage:header108Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork108 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork109 = [DSMerkleBlock merkleBlockWithMessage:header109Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork109 receivedAsHeader:YES fromPeer:nil];

    DSMerkleBlock *merkleBlockFork110 = [DSMerkleBlock merkleBlockWithMessage:header110Data onChain:self.chain];
    [self.chain addBlock:merkleBlockFork110 receivedAsHeader:YES fromPeer:nil];


    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 1);

    self.chain.chainManager.syncPhase = DSChainSyncPhase_ChainSync;


    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil]; // test starting sync blocks with headers
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 105);


    NSData *blockData106 = @"00000020384621d0c5b5e0f84fe336d37e4cce7d9c2d56493102cf88234254721dd3f35c3da65260508ff789b65b19047cded17bf161fc64916f91365a3edab0a675099de699275fffff7f20010000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016a0101ffffffff01e288526a740000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac000000002601006a000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006a000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b3200000000000000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000001d555f3ff0a86bbe2cd9d8a2c7725935dbbfb2c747f910402e5d050a3f919cec1000000006a4730440220437f15af30180be323ca1a1e0c47de2a597abba2a57d4f76e2584ce7d3e8d40802202705342f334991c9eaa2757ea63c5bb305abf14a66a1ce727ef2689a92bcee55012103a65caff6ca4c0415a3ac182dfc2a6d3a4dceb98e8b831e71501df38aa156f2c1feffffff0200e40b54020000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac1ea34616720000001976a914965ef0941e79834ca79b291b940cc18cf516448788ac14000000".hexToData;

    NSData *blockData107 = @"00000020cfc988ba6d83e212dc73f0f46e241f90051f39e7372a796bffe2e9703fdb8d4f94419d7b35becec0f9214f0724df6399099a453e9870d828e81a302653010dfd359c275fffff7f20000000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016b0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006b000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006b000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData108 = @"000000207ec1e064a7ee15439427af2b430993112ff6f006ded8dcbac1e7893106952e47191725fce3cb5ed1fdd8722d7f85e8009fd0c43fb9dc11b54dc452da51ed30c4359c275fffff7f20010000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016c0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006c000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006c000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData109 = @"0000002058edb8e10452b08016c96f9d83f73256ce2a5284444f538e4e40c90bb7ce4e60ff9d49c738cfd1a7bc0efc7a506edb64cdd94d685f1c6f65cee103c625226e41359c275fffff7f20040000000203000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016d0101ffffffff010088526a740000002321027304c3ed545c15abb68422c0f0c739a5f74a7be556c627b56b3575bcbf74712aac000000002601006d000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006d000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b320000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000".hexToData;

    NSData *blockData110 = @"000000205b6621577fb6faf54e35bb98ff35bc5fbe9d3f8ef7c4c56d788768036bc9a14beae8d6e3fdafb72bd7e81308c99e95096797bb78ca233e5bdeebcd4d9ed07fd04d9e275fffff7f20020000000303000500010000000000000000000000000000000000000000000000000000000000000000ffffffff04016e0101ffffffff01e288526a740000002321031cb7f55495e8dcfd985114bd870cc4d3b8ed53d4b43bfab75beea36676a352a5ac000000002601006e000000000000000000000000000000000000000000000000000000000000000000000003000600000000000000fd490101006e000000010001f2efb75bd621e59c7115e5c4bdadae772d178f587687c715f88f7f414d34c66b32000000000000003200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000017f38ad14ba2fd1edfb3cba5dbc99b30844c3ddfbad35129e858433f46ec8d34e010000006a47304402204972e37e8b7ae4aeb30388b79dfb6067fe6a2d3fd751e1031b924b857bfe483c02200c58de282b10dc536a161b34a606890779d552ba618738018ad1f21f669912540121038d18456ebe83c1650166a1d5145c9a9456b35f9258338b54d98257b968b765dafeffffff0200e1f505000000001976a91473483d35610ce83e45bae64ea88714dec7d41e9588ac3cc15010720000001976a914dc8f9ddbe48e754d371e5866b80dad846805fe2f88ac6d000000".hexToData;

    DSFullBlock *blockFork106 = [DSFullBlock fullBlockWithMessage:blockData106 onChain:self.chain];
    DSFullBlock *blockFork107 = [DSFullBlock fullBlockWithMessage:blockData107 onChain:self.chain];
    DSFullBlock *blockFork108 = [DSFullBlock fullBlockWithMessage:blockData108 onChain:self.chain];
    DSFullBlock *blockFork109 = [DSFullBlock fullBlockWithMessage:blockData109 onChain:self.chain];
    DSFullBlock *blockFork110 = [DSFullBlock fullBlockWithMessage:blockData110 onChain:self.chain];

    for (DSTransaction *transaction in blockFork106.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork106];
    }
    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked
    [self.chain addBlock:blockFork106 receivedAsHeader:NO fromPeer:nil];
    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106);
        }
    }


    XCTAssertEqual(self.wallet.balance, 10000000000); // Only 1 transaction, coinbase is still locked

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 106);

    [self.chain addBlock:blockFork107 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork108 receivedAsHeader:NO fromPeer:nil];
    [self.chain addBlock:blockFork109 receivedAsHeader:NO fromPeer:nil];

    for (DSTransaction *transaction in blockFork110.transactions) {
        [self.chain.chainManager.transactionManager peer:peer relayedTransaction:transaction inBlock:blockFork110];
    }

    [self.chain addBlock:blockFork110
        receivedAsHeader:NO
                fromPeer:nil];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);

    for (NSURL *url in sortedBlocks106to150) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:NO fromPeer:nil];
    }

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, TX_UNCONFIRMED); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 150);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 150);

    DSChainLock *chainLock106 = [[DSChainLock alloc] initWithBlockHash:merkleBlockFork106.blockHash signature:UINT768_ZERO signatureVerified:YES quorumVerified:YES onChain:self.chain];

    [self.chain addChainLock:chainLock106];

    DSChainLock *chainLock110 = [[DSChainLock alloc] initWithBlockHash:merkleBlockFork110.blockHash signature:UINT768_ZERO signatureVerified:YES quorumVerified:YES onChain:self.chain];

    [self.chain addChainLock:chainLock110];

    DSChainLock *chainLock109 = [[DSChainLock alloc] initWithBlockHash:merkleBlockFork109.blockHash signature:UINT768_ZERO signatureVerified:YES quorumVerified:YES onChain:self.chain];

    [self.chain addChainLock:chainLock109];

    XCTAssertEqual(self.wallet.balance, 10100000000); // The previous transaction should have been reverted but should still appear in balance

    for (DSTransaction *transaction in blockFork106.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 106); // The previous transactions should not have a block height
        }
    }

    for (DSTransaction *transaction in blockFork110.transactions) {
        if (![transaction isMemberOfClass:[DSQuorumCommitmentTransaction class]] && ![transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
            XCTAssertEqual(transaction.blockHeight, 110); // The previous transactions should not have a block height
        }
    }

    XCTAssertEqual(self.chain.lastTerminalBlockHeight, 110);
    XCTAssertEqual(self.chain.lastSyncBlockHeight, 110);
}

- (void)testCheckpoints {
    // This is an example of a functional test case.
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:[NSManagedObjectContext chainContext]];
    DSPeer *peer = [DSPeer peerWithHost:@"0.1.2.3:3000" onChain:self.chain];
    [self.chain setEstimatedBlockHeight:150 fromPeer:peer thresholdPeerCount:0];
    NSURL *bundleRoot = [[NSBundle bundleForClass:[self class]] bundleURL];
    NSArray *directoryContents =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:bundleRoot
                                      includingPropertiesForKeys:@[]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == %@", @"block"];
    NSArray *blocks = [directoryContents filteredArrayUsingPredicate:predicate];
    XCTAssertEqual(blocks.count, 149);
    NSMutableArray *sortedBlocks105 = [NSMutableArray array];
    NSMutableArray *sortedBlocks106to150 = [NSMutableArray array];
    int i = 2;

    while (i <= 150) {
        for (NSURL *url in blocks) {
            NSArray *components = [url.lastPathComponent componentsSeparatedByString:@"-"];
            if ([components[3] intValue] == i) {
                if (i <= 105) {
                    [sortedBlocks105 addObject:url];
                } else {
                    [sortedBlocks106to150 addObject:url];
                }
                i++;
                break;
            }
        }
    }

    i = 105;

    NSMutableArray *checkpointsArray = [NSMutableArray array];
    NSMutableArray *checkpointsSerializedLengthsArray = [NSMutableArray array];
    NSMutableData *checkpointsData = [NSMutableData data];

    for (NSURL *url in sortedBlocks105) {
        NSData *blockData = [NSData dataWithContentsOfURL:url];
        DSMerkleBlock *merkleBlock = [DSMerkleBlock merkleBlockWithMessage:blockData onChain:self.chain];
        [self.chain addBlock:merkleBlock receivedAsHeader:YES fromPeer:nil];
        DSCheckpoint *checkpoint = [DSCheckpoint checkpointFromBlock:merkleBlock options:DSCheckpointOptions_None];
        [checkpointsArray addObject:checkpoint];
        NSData *data = [checkpoint serialize];
        [checkpointsSerializedLengthsArray addObject:@(data.length)];
        [checkpointsData appendData:data];
    }

    uint32_t off = 0;

    NSMutableArray *checkpointsArray2 = [NSMutableArray array];
    NSMutableArray *checkpointsDeserializedLengthsArray = [NSMutableArray array];
    while (off < checkpointsData.length) {
        uint32_t startingOffset = off;
        DSCheckpoint *deserializedCheckpoint = [[DSCheckpoint alloc] initWithData:checkpointsData atOffset:off finalOffset:&off];
        [checkpointsDeserializedLengthsArray addObject:@(off - startingOffset)];
        [checkpointsArray2 addObject:deserializedCheckpoint];
    }
    XCTAssertEqualObjects(checkpointsSerializedLengthsArray, checkpointsDeserializedLengthsArray);
    XCTAssertEqual(checkpointsArray.count, checkpointsArray2.count, @"Checkpoint Arrays should be same size");

    for (uint32_t i = 0; i < checkpointsArray.count; i++) {
        DSCheckpoint *a = checkpointsArray[i];
        DSCheckpoint *b = checkpointsArray2[i];
        XCTAssertEqualObjects(a, b);
    }
    XCTAssertEqualObjects(checkpointsArray, checkpointsArray2);
}


@end
