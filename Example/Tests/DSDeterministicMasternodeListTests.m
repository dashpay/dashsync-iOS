//
//  DSDeterministicMasternodeListTests.m
//  DashSync_Tests
//
//  Created by Sam Westrich on 7/18/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import "NSString+Bitcoin.h"
#import "DSChain.h"
#import "DSMasternodeManager.h"
#import "NSData+Bitcoin.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChainManager.h"
#import "DSCoinbaseTransaction.h"
#import "DSTransactionFactory.h"
#import "DSMerkleBlock.h"
#import <arpa/inet.h>


@interface DSDeterministicMasternodeListTests : XCTestCase
    
    @property (strong, nonatomic) DSChain *chain;
    @property (strong, nonatomic) DSChain *testnetChain;
    
    @end

@implementation DSDeterministicMasternodeListTests
    
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
    self.testnetChain = [DSChain testnet];
}

//these have to be redone
//    -(void)testIndividualSimplifiedMasternodeEntry {
//        UInt256 transactionHashData = *(UInt256*)@"2a08656c679bcf0af27a6e1b46744f2afcfe22d48eb612282919876ce1bd5e67".hexToData.reverse.bytes;
//        UInt160 keyDataInt = *(UInt160*)@"01653d4a79ac7ee88482067d9e8d67882aee8a02".hexToData.reverse.bytes;
//        DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
//        NSString * ipAddressString = @"13.250.100.254";
//        UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
//        struct in_addr addrV4;
//        if (inet_aton([ipAddressString UTF8String], &addrV4) != 0) {
//            uint32_t ip = ntohl(addrV4.s_addr);
//            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
//        } else {
//            NSLog(@"invalid address");
//        }
//        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:transactionHashData confirmedHash:<#(UInt256)#> address:<#(UInt128)#> port:<#(uint16_t)#> operatorBLSPublicKey:<#(UInt384)#> keyIDVoting:<#(UInt160)#> isValid:<#(BOOL)#> onChain:<#(DSChain *)#>sh:transactionHashData address:ipAddress port:12999 keyIDOperator:keyDataInt keyIDVoting:keyDataInt isValid:TRUE onChain:devnetDRA];
//        XCTAssertEqualObjects([NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash],@"6b8e569016e188ebd5908edc5f3ede1fc364bf55398717eaedfa30f0c6cf8b1d".hexToData,@"SMLE Hash not correct");
//
//        NSData * data = @"675ebde16c8719292812b68ed422fefc2a4f74461b6e7af20acf9b676c65082a00000000000000000000ffff0dfa64fe32c7028aee2a88678d9e7d068284e87eac794a3d6501028aee2a88678d9e7d068284e87eac794a3d650101".hexToData;
//
//        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntryFromData = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithData:data onChain:devnetDRA];
//        XCTAssertEqualObjects(simplifiedMasternodeEntry.payloadData,simplifiedMasternodeEntryFromData.payloadData,@"SMLE methods have issues");
//    }
//
//- (void)testDSMasternodeBroadcastHash {
//    {
//        NSMutableArray<DSSimplifiedMasternodeEntry*>* entries = [NSMutableArray array];
//        for (unsigned int i = 0; i < 16; i++) {
//            NSString * transactionHashString = [NSString stringWithFormat:@"%064x",i];
//            UInt256 transactionHashData = *(UInt256*)transactionHashString.hexToData.reverse.bytes;
//            NSString * keyString = [NSString stringWithFormat:@"%040x",i];
//            NSData * keyData = keyString.hexToData.reverse;
//            UInt160 keyDataInt = *(UInt160*)keyData.bytes;
//            DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:transactionHashData address:UINT128_ZERO port:i keyIDOperator:keyDataInt keyIDVoting:keyDataInt isValid:TRUE onChain:[DSChain mainnet]];
//            [entries addObject:simplifiedMasternodeEntry];
//        }
//
//        NSMutableArray * simplifiedMasternodeEntryHashes = [NSMutableArray array];
//
//        for (DSSimplifiedMasternodeEntry * entry in entries) {
//            [simplifiedMasternodeEntryHashes addObject:[NSData dataWithUInt256:entry.simplifiedMasternodeEntryHash]];
//        }
//
//        NSArray * stringHashes = @[@"6c06974f8f6d88bf30f21854836c994452e784c4f9aa2ea5c8ca6fcf10181f8b", @"90f788b6b946cced7ed765efeb9123c08bef8e025428a02ab7eedcc65c6a6cb0", @"45c2e12db6e85d0e30a460f69159a37f8a9d81e8b4949c640a64c9119dbe3f45", @"a56add792486a8c5067866609484e6d36f650da7cd4db5ca4111ecd579334a6c", @"09a0be55cebd876c1f97857c0950739dfc6e84ab62e1bb99918042d3eafb1be3", @"adb23c6a1308da95d777f88bede5576c54f52651979a3ca5e16d8a20001a7265", @"df45a56be881ab0d7812f8c43d6bb164d5abb42b37baaf3e01b82d6331a75d9b", @"5712e7a512f307aa652f15f494df1d47a082fb54a9557d54cb8fcc779bd65b48", @"58ab53be8cd4e97a48395ac8d812e684f3ab2d6be071f58055e7f6856076f1d4", @"4652b7caad564d56e106d025705ad3ee6f66e56bb8ce6ce86ac396f06f6eb75e", @"7480510e4dc4468bb23d9f3cb9fb10a170080afe270d5ba58948ebc746e24205", @"68f9e1572c626f1d946031c16c7020d8cbc565de8021869803f058308242266e", @"ca8895e0bea291d1d0e1bd8716de1369f217e7fcd0ee7969672434d71329b3cd", @"9db68eccc2dc8c80919e7507d28e38a1cd7381d2828cbe8ad19331ed94b1b550", @"42660058e883c3ea8157e36005e6941a1d1bea4ea1e9a03897c9682aa834e09f", @"55d90588e07417e7144a69fee1baea16dc647b497ee1affc2c3d91b09ad23c9c"];
//
//        NSMutableArray * verifyHashes = [NSMutableArray array];
//
//        for (NSString * stringHash in stringHashes) {
//            [verifyHashes addObject:stringHash.hexToData.reverse];
//        }
//
//        XCTAssertEqualObjects(simplifiedMasternodeEntryHashes,verifyHashes,@"Checking hashes");
//
//        NSString * root = @"ddfd8bcde9a5a58ce2a043864d8aae4998996b58f5221d4df0fd29d478807d54";
//        NSData * merkleRoot = [NSData merkleRootFromHashes:verifyHashes];
//
//        XCTAssertEqualObjects(root.hexToData.reverse,merkleRoot,
//                              @"MerkleRootEqual");
//
//    }
//
//    {
//        NSMutableArray<DSSimplifiedMasternodeEntry*>* entries = [NSMutableArray array];
//        for (unsigned int i = 0; i < 15; i++) {
//            NSString * transactionHashString = [NSString stringWithFormat:@"%064x",i];
//            UInt256 transactionHashData = *(UInt256*)transactionHashString.hexToData.reverse.bytes;
//            NSString * keyString = [NSString stringWithFormat:@"%040x",i];
//            NSData * keyData = keyString.hexToData.reverse;
//            UInt160 keyDataInt = *(UInt160*)keyData.bytes;
//            NSString * ipAddressString = [NSString stringWithFormat:@"0.0.0.%d",i];
//            UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
//            struct in_addr addrV4;
//            if (inet_aton([ipAddressString UTF8String], &addrV4) != 0) {
//                uint32_t ip = ntohl(addrV4.s_addr);
//                ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
//            } else {
//                NSLog(@"invalid address");
//            }
//
//            DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:transactionHashData address:ipAddress port:i keyIDOperator:keyDataInt keyIDVoting:keyDataInt isValid:TRUE onChain:[DSChain mainnet]];
//            [entries addObject:simplifiedMasternodeEntry];
//        }
//
//        XCTAssertEqualObjects(entries[3].payloadData,@"030000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff0000000300030300000000000000000000000000000000000000030000000000000000000000000000000000000001".hexToData,@"Value 3 did not match");
//
//        NSMutableArray * simplifiedMasternodeEntryHashes = [NSMutableArray array];
//
//        for (DSSimplifiedMasternodeEntry * entry in entries) {
//            [simplifiedMasternodeEntryHashes addObject:[NSData dataWithUInt256:entry.simplifiedMasternodeEntryHash]];
//        }
//
//        NSArray * stringHashes = @[@"aa8bfb825f433bcd6f1039f27c77ed269386e05577b0fe9afc4e16b1af0076b2",
//                                   @"686a19dba9b515f77f11027cd1e92e6a8c650448bf4616101fd5ddbe6e2629e7",
//                                   @"c2efc1b08daa791c71e1d5887be3eaa136381f783fcc5b7efdc5909db38701bb",
//                                   @"ce394197d6e1684467fbf2e1619f71ae9d1a6cf6548b2235e4289f95d4bccbbd",
//                                   @"aeeaf7b498aa7d5fa92ee0028499b4f165c31662f5e9b0a80e6e13b38fd61f8d",
//                                   @"0c1c8dc9dc82eb5432a557580e5d3d930943ce0d0db5daebc51267afb46b6d48",
//                                   @"1c4add10ea844a46734473e48c2f781059b35382219d0cf67d6432b540e0bbbe",
//                                   @"1ae1ad5ff4dd4c09469d21d569a025d467dca1e407581a2815175528e139b7da",
//                                   @"d59b231cdc80ce7eda3a3f37608abda818659c189d31a7ef42024d496e290cbc",
//                                   @"2d5e6c87e3d4e5b3fdd600f561e8dec1ea720560569398006050480232f1257c",
//                                   @"3d6af35f08efeea22f3c8fcb78038e56dac221f3173ca4e2230ea8ae3cbd3c60",
//                                   @"ecf547077c37b79da954c4ef46a3c4fb136746366bfb81192ed01de96fd66348",
//                                   @"626af5fb8192ead7bbd79ad7bfe2c3ea82714fdfd9ac49b88d7a411aa6956853",
//                                   @"6c84a4485fb2ba35b4dcd4d89cbdd3d813446514bb7a2046b6b1b9813beaac0f",
//                                   @"453ca2a83140da73a37794fe6fddd701ea5066f21c2f1df8a33b6ff6134043c3",];
//
//        NSMutableArray * verifyHashes = [NSMutableArray array];
//
//        for (NSString * stringHash in stringHashes) {
//            [verifyHashes addObject:stringHash.hexToData.reverse];
//        }
//
//        XCTAssertEqualObjects(simplifiedMasternodeEntryHashes,verifyHashes,@"Checking hashes");
//
//        NSString * root = @"926efc8dc7b5b060254b102670b918133fea67c5e1bc2703d596e49672878c22";
//        NSData * merkleRoot = [NSData merkleRootFromHashes:verifyHashes];
//
//        XCTAssertEqualObjects(root.hexToData.reverse,merkleRoot,
//                              @"MerkleRootEqual");
//
//    }
//}

//- (void)testFullMasternodeListDiffMessage {
//    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
//    NSString * hexString = @"0000000000000000000000000000000000000000000000000000000000000000a022418a003b689b9b82c23473ef8df189fbb2c03b3f9cf3b53c0160fc966e190100000001ef45ec04d27938efb81184f97ceab908dbb66245c2dbffdf97b82b92bcddbd6e010103000500010000000000000000000000000000000000000000000000000000000000000000ffffffff050290070101ffffffff0200c11a3d05000000232103eead733a081b6559bbe32c3a0c55ce861614df5b5c69b65125072e59339ce547ac00c11a3d050000001976a914c490201bdda0e64e3e1d8bdd6bbf7d80686f0e8588ac0000000024900700006c45528d7b8d4e7a33614a1c3806f4faf5c463f0b313aa0ece1ce12c34154a44000e16e11b50a91d95a82f64283edd47b890baf8a74af3d408206111574cb8b32a1600000000000000000000ffff34dde84732c7827b241e43c47dbac1fb5697409a537fca3424a4827b241e43c47dbac1fb5697409a537fca3424a401368d37774de9e4694b94caff82737b72b3914e70f8d34905b644491ddf4dc42400000000000000000000ffff34ddcac432c7454921eb604faad14ab5772a1738b648c27d7b0b454921eb604faad14ab5772a1738b648c27d7b0b013c692906f231771f2e1c19a15c2863a9c04b864ff2c45bd0fd46f91231a38bad00000000000000000000ffff36a98e4832c71344d247bc20849a10e025dea103790f45addd951344d247bc20849a10e025dea103790f45addd9501451ecdfdbb5ac685f56ec547d62174fbc5cd0b268a908d8336573b34c978ab6800000000000000000000ffff344de70d32c71d33b834ffbd8a4fa1dc8cf951d4c660d9b057a81d33b834ffbd8a4fa1dc8cf951d4c660d9b057a80146cb295d8deb1ca477d0bbb714299b49cddbd13d7683adb5b45773280ed9f43100000000000000000000ffff36fb805732c73b268262cb533fa71c8d201ac95b47d7b9dc235d3b268262cb533fa71c8d201ac95b47d7b9dc235d015192c6531b6cc9acb5d39e7724c5dd45ebbafc6ad506d43db3c94f4bc5bf842c00000000000000000000ffff344ddc0932c786b1026279914cf9bf9c7e09bdf4e11e32efa81686b1026279914cf9bf9c7e09bdf4e11e32efa81601535aca9cde16ebc6d6a51914b6c524044df6d6a87ec7c23c3dc7f355ff445fb500000000000000000000ffff36ffba0132c713a15c179c1aa56bd6f7823a82adf121d26fae7113a15c179c1aa56bd6f7823a82adf121d26fae71016572053adbdc2d1ae4955b2c1574366d8b2f9e2734144632030e4c832792292900000000000000000000ffff36a9837332c706c1a2a01cabcb73328a0c1581c708e302836aaf06c1a2a01cabcb73328a0c1581c708e302836aaf01662d6de9ed5a85646ebf9e04b63537993be345ed28ebd253c8c0bda5a325ef8700000000000000000000ffff0dfa0ebf32c7def5bfceb759577766dc3029fd8080ad07baa70cdef5bfceb759577766dc3029fd8080ad07baa70c01675ebde16c8719292812b68ed422fefc2a4f74461b6e7af20acf9b676c65082a00000000000000000000ffff0dfa64fe32c7028aee2a88678d9e7d068284e87eac794a3d6501028aee2a88678d9e7d068284e87eac794a3d6501016d8fd38216a9d76492fad8e72f0ba161784bcf5f888ab66daceca75db3dabfc200000000000000000000ffff0de5e9e732c771915a515a000d0080800b735b439598d1f3c3b071915a515a000d0080800b735b439598d1f3c3b00197855159eaadf7e3d0f6fc0b2ffdaaad2a5ffeb1e858fa88d979f3c2042132cd00000000000000000000ffff0dfa2d2132c79fcc35836c2ed6b477a3323a37128eb70cb4ff039fcc35836c2ed6b477a3323a37128eb70cb4ff0301a921e6d02823147dda734f8a0bef79d2ccc94cd4e3dc06d5378cbfb051b4a12400000000000000000000ffff0de5466d32c74fab17021bd32fd24492187a1205a28247ff1f864fab17021bd32fd24492187a1205a28247ff1f8601aa0e74b6f56eebbf55849f7fc40bf2f163d57e0752a6f724554f6e12fd4ad3f300000000000000000000ffff36ffa45332c7b9d093370f55b4196374e0d83ff11a2259589abcb9d093370f55b4196374e0d83ff11a2259589abc01";
//    NSData * message = [hexString hexToData];
//    
//    NSUInteger length = message.length;
//    NSUInteger offset = 0;
//    
//    if (length - offset < 32) return;
//    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
//    offset += 32;
//    
//    XCTAssertTrue(uint256_eq(baseBlockHash, UINT256_ZERO),@"Base block hash should be empty here");
//    
//    if (length - offset < 32) return;
//    UInt256 blockHash = [message UInt256AtOffset:offset];
//    offset += 32;
//    
//    if (length - offset < 4) return;
//    uint32_t totalTransactions = [message UInt32AtOffset:offset];
//    XCTAssertTrue(totalTransactions == 1,@"There should be only 1 transaction");
//    offset += 4;
//    
//    if (length - offset < 1) return;
//    
//    NSNumber * merkleHashCountLength;
//    uint64_t merkleHashCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleHashCountLength]*sizeof(UInt256);
//    offset += [merkleHashCountLength unsignedLongValue];
//    
//    
//    NSData * merkleHashes = [message subdataWithRange:NSMakeRange(offset, merkleHashCount)];
//    offset += merkleHashCount;
//    
//    NSNumber * merkleFlagCountLength;
//    uint64_t merkleFlagCount = [message varIntAtOffset:offset length:&merkleFlagCountLength];
//    offset += [merkleFlagCountLength unsignedLongValue];
//    
//    
//    NSData * merkleFlags = [message subdataWithRange:NSMakeRange(offset, merkleFlagCount)];
//    offset += merkleFlagCount;
//    
//    NSData * leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
//    
//    DSCoinbaseTransaction *coinbaseTransaction = (DSCoinbaseTransaction*)[DSTransactionFactory transactionWithMessage:[message subdataWithRange:NSMakeRange(offset, message.length - offset)] onChain:devnetDRA];
//    
//    if (![coinbaseTransaction isMemberOfClass:[DSCoinbaseTransaction class]]) return;
//    offset += coinbaseTransaction.payloadOffset;
//    
//    if (length - offset < 1) return;
//    NSNumber * deletedMasternodeCountLength;
//    uint64_t deletedMasternodeCount = [message varIntAtOffset:offset length:&deletedMasternodeCountLength];
//    offset += [deletedMasternodeCountLength unsignedLongValue];
//    
//    NSMutableArray * deletedMasternodeHashes = [NSMutableArray array];
//    
//    while (deletedMasternodeCount >= 1) {
//        if (length - offset < 32) return;
//        [deletedMasternodeHashes addObject:[NSData dataWithUInt256:[message UInt256AtOffset:offset]]];
//        offset += 32;
//        deletedMasternodeCount--;
//    }
//    
//    if (length - offset < 1) return;
//    NSNumber * addedMasternodeCountLength;
//    uint64_t addedMasternodeCount = [message varIntAtOffset:offset length:&addedMasternodeCountLength];
//    offset += [addedMasternodeCountLength unsignedLongValue];
//    
//    leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
//    NSMutableDictionary * addedOrModifiedMasternodes = [NSMutableDictionary dictionary];
//    
//    while (addedMasternodeCount >= 1) {
//        if (length - offset < 91) return;
//        NSData * data = [message subdataWithRange:NSMakeRange(offset, 91)];
//        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithData:data onChain:devnetDRA];
//        [addedOrModifiedMasternodes setObject:simplifiedMasternodeEntry forKey:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash].reverse];
//        offset += 91;
//        addedMasternodeCount--;
//    }
//    
//    NSMutableDictionary * tentativeMasternodeList = [NSMutableDictionary dictionary];
//    
//    [tentativeMasternodeList removeObjectsForKeys:deletedMasternodeHashes];
//    [tentativeMasternodeList addEntriesFromDictionary:addedOrModifiedMasternodes];
//    
//    NSArray * proTxHashes = [tentativeMasternodeList allKeys];
//    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
//        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
//        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
//    }];
//    
//    NSArray * verifyStringHashes = @[@"368d37774de9e4694b94caff82737b72b3914e70f8d34905b644491ddf4dc424",
//                                     @"6572053adbdc2d1ae4955b2c1574366d8b2f9e2734144632030e4c8327922929",
//                                     @"46cb295d8deb1ca477d0bbb714299b49cddbd13d7683adb5b45773280ed9f431",
//                                     @"6d8fd38216a9d76492fad8e72f0ba161784bcf5f888ab66daceca75db3dabfc2",
//                                     @"5192c6531b6cc9acb5d39e7724c5dd45ebbafc6ad506d43db3c94f4bc5bf842c",
//                                     @"3c692906f231771f2e1c19a15c2863a9c04b864ff2c45bd0fd46f91231a38bad",
//                                     @"aa0e74b6f56eebbf55849f7fc40bf2f163d57e0752a6f724554f6e12fd4ad3f3",
//                                     @"16e11b50a91d95a82f64283edd47b890baf8a74af3d408206111574cb8b32a16",
//                                     @"a921e6d02823147dda734f8a0bef79d2ccc94cd4e3dc06d5378cbfb051b4a124",
//                                     @"451ecdfdbb5ac685f56ec547d62174fbc5cd0b268a908d8336573b34c978ab68",
//                                     @"97855159eaadf7e3d0f6fc0b2ffdaaad2a5ffeb1e858fa88d979f3c2042132cd",
//                                     @"675ebde16c8719292812b68ed422fefc2a4f74461b6e7af20acf9b676c65082a",
//                                     @"662d6de9ed5a85646ebf9e04b63537993be345ed28ebd253c8c0bda5a325ef87",
//                                     @"535aca9cde16ebc6d6a51914b6c524044df6d6a87ec7c23c3dc7f355ff445fb5"];
//    
//    NSMutableArray * verifyHashes = [NSMutableArray array];
//    
//    for (NSString * stringHash in verifyStringHashes) {
//        [verifyHashes addObject:stringHash.hexToData.reverse];
//    }
//    
//    verifyHashes = [[verifyHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
//        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
//        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
//    }] mutableCopy];
//    
//    
//    XCTAssertEqualObjects(verifyHashes,proTxHashes,
//                          @"Provider transaction hashes");
//    
//    NSMutableArray * simplifiedMasternodeListHashes = [NSMutableArray array];
//    for (NSData * proTxHash in proTxHashes) {
//        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [tentativeMasternodeList objectForKey:proTxHash];
//        [simplifiedMasternodeListHashes addObject:[NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash]];
//    }
//    
//    NSArray * verifyStringSMLEHashes = @[@"4090e9167892b3a452891efaf8935a3fa5ebaec7db3bffe1a4073e26a8218d56",
//                                         @"d4e7a66aeda72ab6f25e2ffd6c82da297737068fb9eb795a06a42b723b27a2f1",
//                                         @"a6b1b82aa961f74eba2f3f369bdb659bb4058f8fbca79909decf11e7ddd80f4d",
//                                         @"feaaea4f2bfeb182f9590e100040fee93ddf1ebf4134b87d59012a7d188bcb76",
//                                         @"cc5de8a7dfde4b451cb9138df76fcab8adf917bf5261bc9e2736aab73cd8d19e",
//                                         @"5912f286cc9c1c86c8bc7cf97650f7b17629a085f951c30bdbd1aae5b79bc417",
//                                         @"2c341c8badd76908aba636ee87911886417f5e506c7a0d3b556055eb4c21b6a1",
//                                         @"894d469cbafc1b15e345d32815f73dbd21e73980b5362c52d7513a04466f2bbf",
//                                         @"6067d7e815f0e14435c45775ae230736a16502fcbf0c42ba55eb0f384c1fb058",
//                                         @"6b8e569016e188ebd5908edc5f3ede1fc364bf55398717eaedfa30f0c6cf8b1d",
//                                         @"dd7b6adf37b728eb8985fff094b63f92c0a07f49f60edb629b1ff87a69a95080",
//                                         @"c341516a6e4ed54d03f2ca6e946d2a2f53dcf624c1ee1822d743c3f4d85745d6",
//                                         @"ebd859627703e030150beb7f1e080ee3742d48d8387604aadf53460debb9c2c8",
//                                         @"4f87e5bd3e24b87b6894ee59e5f42f3427f7ae03106fc83c8269db0f0c49aa1c"];
//    
//    NSMutableArray * verifySMLEHashes = [NSMutableArray array];
//    
//    for (NSString * stringHash in verifyStringSMLEHashes) {
//        [verifySMLEHashes addObject:stringHash.hexToData];
//    }
//    
//    XCTAssertEqualObjects(simplifiedMasternodeListHashes,verifySMLEHashes,
//                          @"SMLE transaction hashes");
//    
//    XCTAssertEqualObjects([NSData merkleRootFromHashes:simplifiedMasternodeListHashes],[NSData dataWithUInt256:coinbaseTransaction.merkleRootMNList],
//                          @"MerkleRootEqual");
//    
//    
//    XCTAssertEqualObjects([NSData merkleRootFromHashes:simplifiedMasternodeListHashes],@"6c45528d7b8d4e7a33614a1c3806f4faf5c463f0b313aa0ece1ce12c34154a44".hexToData,
//                          @"MerkleRootEqual Value");
//    
//    //we need to check that the coinbase is in the transaction hashes we got back
//    UInt256 coinbaseHash = coinbaseTransaction.txHash;
//    BOOL foundCoinbase = FALSE;
//    for (int i = 0;i<merkleHashes.length;i+=32) {
//        UInt256 randomTransactionHash = [merkleHashes UInt256AtOffset:i];
//        if (uint256_eq(coinbaseHash, randomTransactionHash)) {
//            foundCoinbase = TRUE;
//            break;
//        }
//    }
//    
//    XCTAssert(foundCoinbase,@"The coinbase was not part of provided hashes");
//    
//    //we need to check that the merkle tree is correct
//    NSData * merkleRoot = @"ef45ec04d27938efb81184f97ceab908dbb66245c2dbffdf97b82b92bcddbd6e".hexToData;
//    DSMerkleBlock * coinbaseVerificationMerkleBlock = [[DSMerkleBlock alloc] initWithBlockHash:blockHash merkleRoot:[merkleRoot UInt256] totalTransactions:totalTransactions hashes:merkleHashes flags:merkleFlags];
//
//    XCTAssert([coinbaseVerificationMerkleBlock isMerkleTreeValid],@"Coinbase is not part of the valid merkle tree");
//}
    
    
@end

