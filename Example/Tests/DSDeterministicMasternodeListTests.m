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
    
    __unused DSChain *devnet = [DSChain setUpDevnetWithIdentifier:@"devnet-DRA" withCheckpoints:nil withDefaultPort:20001 withDefaultDapiPort:3000];
    
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

- (void)testFullMasternodeListDiffMessage {
    DSChain * devnetDRA = [DSChain devnetWithIdentifier:@"devnet-DRA"];
    NSString * hexString = @"0000000000000000000000000000000000000000000000000000000000000000b869c16fb589e406e527f30853cb13a47817320e03f80be7e091b86efd0100000d00000005ab158c0eb014ecb69e7e6231a9a30f485874eb874ed2e013f5bbfce4310e4fb5f10f8a574eb6244b27446c54a16b163e9c362865910e004c734beacc092599a9b1594e2a20f778c6d44cc1ce2e85beba54178e4a065ec782be7640440f15b640a7bf31ded7f578af23cd233dde2f469be92a68e76239b62419a2d5ce3427b96d243ba9d455a1455b65e6a41df3e20bfc854ca1c90d3e6ef1be4d4e8e641cc8f4021f0003000500010000000000000000000000000000000000000000000000000000000000000000ffffffff0603d698000105ffffffff02c8360e43000000002321031bda148e68fda9820f16be745710decc382b04eb8bef639e37188b356fc38c03acc8360e43000000001976a914450664b0fc75db6f3f5743f2668438288a3d7fe588ac00000000260100d698000027acd2b39a564306c50729de1f88732469f951f0ee22c2ac2eef0c9850019bd5009a42911ec289c2b1559009f988cbfa48a36f606c0aa37c4c6e6b536ab0a9d9eca178ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff3f21ee554e4e08b32c435d28b26ea4c42089edacadaf8016651931f22a8273feedc3f535592f2ea709aa3bf87f9e751073cf05b82aac3cf9e251ef3f1147f64a3af6c29319eb326385bf01d8fdcb15669878b5acccb5eca394ff513908ed5fc3cf44bb1648552cb0b287f424a70b898084eb8f9a1b6f4b0e93f4736f6866f1c4e5c2b8bf861f040000000000000000000000000000ffffad3d1ee74a3f07f818e5c2330ac4e7f0ef820f337addf8ab28b07c9d451304d807feda1d764c7074bccbbd941284b0d0276a96cf5e7f4410220b95991383f29942bb02510c07de9c58c00120ba3f10dc821c8a929aeb9a32e98339fc2f7a3d64b705129777c9a39780a01e3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3f21ee554e26983c80e3e31fea6f3d56d54059e8c95a467285f33914182f1e274616cdbe2f1e1c6c0c7dce13710480ec4658208e9392fdf9ff7c06cbf660a2c93d466d5379492eb7334201a01b70e913df11ee62bc4d21eeeea6a540fa5c2cf975952c728be8eed09623733554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e258dfa69a96f23bd77e72c1a00984bb0df5ce93a76ca1d20694e8ad20b1dfea530cb6ee0b964b78ebb2bc8bfac22f61647e19574f5e7b2fa793c90eaed6bda49d7559e95d30141e985aec00b41aac2d42a5c2cca1fd333fb42dea7465930666df9179e341d2b5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e2b8fd425f945936b02a97c8807d20272742d351356bff653f9467ab29b4bdb6f19bdf863ad5a325f63a0080b9dd80037a9b619e80a88b324974c98c90f8c2289c3ca916580010106207e0dbdce8e18a97328eb9e2de99c87477cd0b2ad1b34b4231327fea08b3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e298348757a2ed830f3a40f0e52ca4823f48c1ab5017dc424ee68c1e8fad27c0ab008bc974866db18bc76bc7d2bebb2997695ca25c4c132186aabbf5c7bfa331119a01969f9018167aa267eb42b78d112b3600358ea7679328be8ceecec2cd68148985b6654405a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e3a07e472824512fd8004e7c81c3dff74c72f898c2a25f71246de316f6dbc976fe4e54d103e6276e457c415f53ba867e1d7ce2eeb1be671205ee68db332dd0f4871f549baf101a1d700ddb67ae80c1cb4fdb76dac6484dc1dc2741334ad5e48f78fd08713a13478ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff3432d0354e4d88a5857ea0eb8a5fe369bb672144867c4908300089472108afb9d54a70f7d6e4b339d01509dd9231da90b14cb401df2f007aec84e8af1b8f2da40a74b4d3beeaa8b473480121958ba1693c76e70a81c354111cc48a50579587329978c563e2e5655991a2a35a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e380a9117edbb85963c1c5fdbcdcaf33483ee37676e8a34c3f8d298418df77bbdf16791821a75354f0a4f2114c090a4798c318a716eb1abea572d94e176aa2df977f73b05ab012129b96ff3d6dfb88b0266a0958f3f7fcaef4c7947e8b54cb26d8ed31fe8eec6906648c5a900b80bc262dd7b0cc54ed958baccc95d135ab293bad9000000000000000000000000000000ffff68f8f27e4e1f050f3a743867bf78d2e9a3906d15d8400d8d58255771d12828922386e8685f8aeccb8d9d81153f9c2d7da0436a71fe5538130b3e02c119f53aba29a12de6be40f0c6596f00419aa9fed4f35fcb986c50fbaa0c7555c68f8a9876968c63c6f92064ff06f1fe7b34629e1f9f156e4e3720ed76745a9966adb50fb513f1285263d5050000000000000000000000000000ffff2d30b1de4e1f842476e8d82327adfb9b617a7ac3f62868946c0c4b6b0e365747cfb8825b8b79ba0eb1fa62e8583ae7102f59bf70c7c7ce2342a602ce6bd150809591377ecf31971558ca004172e5a561e36ae49358bc4c6c37ff688f54a05ae8842b496b86feb71f06b886bbaf9ff7a4ffcf3931de9233fa8e151f187bf30235000e3b5fb102b01200000000000000000000000000ffff6deb47384e1f8d1412ff39045ef39c2e19a75cb3ad986afc14c3139ed0a3392b41d471558676029a8137f95b0ba0e7315bf11c497f0fc8270f9d208c75006659cedd927f04ccf829242c012354b77c0f261f3d5b8424cbe67c2f27130f01c531732a08b8ae3f28aaa1b1fbb04a8e207d15ce5d20436e1caa792d46d9dffde499917d6b958f98102900000000000000000000000000ffffad3d1ee74a4496a9d730b5800ad10d2fb52b0067b5145d763b227fccb90f37f14f94afd9a9927776f9af8cfcd271f9ce9d06b97af01aad66a452e506399c18cf8ec93ee72ba9e09c5dab00e3845dbdaf3aac0f0f1997815ad9084c97f7d5788355a5d3ed2971f98dde1c2178ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff12ca34aa4e500a10b1fec64669c47086bc0f1d48ea6b37045f7e46c73c5ec41f7576653d7a6d7c79bd1215f16675bb31a59a7137241b7e6c97ede36a4ec13198d841ac5495b463df8ab90163cd3bf06404d78f80163afeb4b13e187dc1c1d04997ef04f1a2ecb3166dd00479521b08e5ad66c2fd6c2f514abe8416cd412dd2794d0f40d353fdd70500000000000000000000000000ffff2d20ed4c4e1f02a2e2673109a5e204f8a82baf628bb5f09a8dfc671859e84d2661cae03e6c6e198a037e968253e94cd099d07b98e94e0b3c7481f9b39efdcf96260c5e8b0f85ff3f646f0183ba23283a9b9dfda9cda5c3ee7e16881425506e976d60a39876a46ce82f38af5a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff12ca34aa4e3c9446b87f833f500e114d024d50024278f22d773111e8e5601e05178005298e5fc2933e400e235c0a51417872f68cc20d773bddc2720f67dd88bfcc61a857d8d9b2d92aae0103df73261636cb60d11484684c25e652217aad6f7f07862c324964cc87b1a7f45a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff22ff0f144e2f067ad7a999ad2dc7f41c735a3dff1d50068f0fc0fde50a7da1c472728ff33f9dd6b20385aaf3c34d9a259dcef975c48b9bd06acb04e2cf63daee7da0c65ce68715d5299b01045480c439ccaf9f38afff4a07e8a212735cdea7e7e8f2511c0883e2583e2b68ef6d852f7e1d547e18f881e4cb053d531b046c0750a8c620553524c81800000000000000000000000000ffff40c13ece4e1f05f2269374676476f00068b7cb168d124b7b780a92e8564e18edf45d77497abd9debf186ee98001a0c9a6dfccbab7a0af4aa6fd6b27d9649267b4ae48e3be5399c89d63a00a49e8534a2d427ef3a94d3ddaf2b05702e87e99d148739e949b64a7c1ebf695f78ef8076c76fd5eb17b5fb8f748bb04202f26efb7fba6840092acde00a00000000000000000000000000ffff22ff0f144e4f9155ae06f2e689f4fa68d5ff89e0d95feeacb431cce7065615d2de64095024e1b60bdfe740e5da5facf13cbbe9d06960265fa2c8a28b6abd1b22272a2cc52d2d84373175012507422a27822ce0fafa7847828eced46309ff30968980ab12d74d8c751507306645fce7c379f7dc790472e00b2e4c9595c0a8932ec0102ac2e63fd00000000000000000000000000000ffffad3d1ee74a498bb67827af87431673e737c49312c5a16fd284daf1c4050e530b604ec4f85f217080503f978a6bec89d1ad4bca089c322583b4b7628ef1186853ff1166818d69d3aeaa4200c5192f9396c9cdd34005cf129d71833f1b56e857b9d578c2b7afef862c1de0722514d561f31f9b08319ff74ebe1f38307764a84a1f1d1d3f5bcfe6040000000000000000000000000000ffff8c523b3327138e21a1a12d5638afbe0cc50b2d61e0deb6553dcd12b84dfd0606a61b2475031f814207f613debe5791798d77f1ea47087ac95522eff7ec28cecab0b6ec79ede11da1416b01c551d5597cc4f8ab6921af4f896ab68e6e71d15bfa8a1bec00769f6894157f075a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3f21ee554e3689fd3e2cc5690053c4252a2a95fccde944b141a3ac8e6b8c36c6b61e71d076f5cc4f9ba0f191d8051ea9b5c51cc5848059c75118444f9a31b03b4285c5dfb26da4f136b10186d4f4152d96ff46c1f8ff948d11923899d2459f4656d5419682d8e16a41c7df3554b945bbff333cff1a0d4d95c848b52e558060fd7b2f2e37dadbfd1a00000000000000000000000000ffff3432d0354e218312e0ba7e4ace816595ade43d2293d70c3dce6b3e7e0ce9e99016f99177277bb42e6d3c2d687ab3e8bed13fb0d3489011dd36c51a435a18af6d4b28b7bc23e706953df401461dc135037403e79929e97099d82532e48cc3f877f8d243bda0673cc73198755a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c00000000000000000000000000ffff3432d0354e2d8c8c7a5b96ed96dd5dbc40db042c301a9d70d5cb98ec073d41cc6a3c68d73ef0d6524cfa210ae1496a880e50fca3fcd15c5002882d6407c275f8850cafd70467a539a86301862677231ca31abd98e260e0678fe63d8580bf7a142a1afa68542aa7185409435a4a633d79445e9acfbc878f263e03b0a3c930091f7383b5467eba7b4c000000";
    NSData * message = [hexString hexToData];

    NSUInteger length = message.length;
    NSUInteger offset = 0;

    if (length - offset < 32) return;
    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;

    XCTAssertTrue(uint256_eq(baseBlockHash, UINT256_ZERO),@"Base block hash should be empty here");

    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 4) return;
    uint32_t totalTransactions = [message UInt32AtOffset:offset];
    XCTAssertTrue(totalTransactions == 13,@"There should be only 13 transaction");
    offset += 4;

    if (length - offset < 1) return;

    NSNumber * merkleHashCountLength;
    uint64_t merkleHashCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleHashCountLength]*sizeof(UInt256);
    offset += [merkleHashCountLength unsignedLongValue];


    NSData * merkleHashes = [message subdataWithRange:NSMakeRange(offset, merkleHashCount)];
    offset += merkleHashCount;

    NSNumber * merkleFlagCountLength;
    uint64_t merkleFlagCount = [message varIntAtOffset:offset length:&merkleFlagCountLength];
    offset += [merkleFlagCountLength unsignedLongValue];


    NSData * merkleFlags = [message subdataWithRange:NSMakeRange(offset, merkleFlagCount)];
    offset += merkleFlagCount;

    NSData * leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];

    DSCoinbaseTransaction *coinbaseTransaction = (DSCoinbaseTransaction*)[DSTransactionFactory transactionWithMessage:[message subdataWithRange:NSMakeRange(offset, message.length - offset)] onChain:devnetDRA];

    if (![coinbaseTransaction isMemberOfClass:[DSCoinbaseTransaction class]]) return;
    offset += coinbaseTransaction.payloadOffset;

    if (length - offset < 1) return;
    NSNumber * deletedMasternodeCountLength;
    uint64_t deletedMasternodeCount = [message varIntAtOffset:offset length:&deletedMasternodeCountLength];
    offset += [deletedMasternodeCountLength unsignedLongValue];

    NSMutableArray * deletedMasternodeHashes = [NSMutableArray array];

    while (deletedMasternodeCount >= 1) {
        if (length - offset < 32) return;
        [deletedMasternodeHashes addObject:[NSData dataWithUInt256:[message UInt256AtOffset:offset]]];
        offset += 32;
        deletedMasternodeCount--;
    }

    if (length - offset < 1) return;
    NSNumber * addedMasternodeCountLength;
    uint64_t addedMasternodeCount = [message varIntAtOffset:offset length:&addedMasternodeCountLength];
    offset += [addedMasternodeCountLength unsignedLongValue];

    leftOverData = [message subdataWithRange:NSMakeRange(offset, message.length - offset)];
    NSMutableDictionary * addedOrModifiedMasternodes = [NSMutableDictionary dictionary];

    while (addedMasternodeCount >= 1) {
        if (length - offset < [DSSimplifiedMasternodeEntry payloadLength]) return;
        NSData * data = [message subdataWithRange:NSMakeRange(offset, [DSSimplifiedMasternodeEntry payloadLength])];
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithData:data onChain:self.chain];
        [addedOrModifiedMasternodes setObject:simplifiedMasternodeEntry forKey:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash].reverse];
        offset += [DSSimplifiedMasternodeEntry payloadLength];
        addedMasternodeCount--;
    }

    NSMutableDictionary * tentativeMasternodeList = [NSMutableDictionary dictionary];

    [tentativeMasternodeList removeObjectsForKeys:deletedMasternodeHashes];
    [tentativeMasternodeList addEntriesFromDictionary:addedOrModifiedMasternodes];

    NSArray * proTxHashes = [tentativeMasternodeList allKeys];
    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
    }];

    NSArray * verifyStringHashes = @[@"368d37774de9e4694b94caff82737b72b3914e70f8d34905b644491ddf4dc424",
                                     @"6572053adbdc2d1ae4955b2c1574366d8b2f9e2734144632030e4c8327922929",
                                     @"46cb295d8deb1ca477d0bbb714299b49cddbd13d7683adb5b45773280ed9f431",
                                     @"6d8fd38216a9d76492fad8e72f0ba161784bcf5f888ab66daceca75db3dabfc2",
                                     @"5192c6531b6cc9acb5d39e7724c5dd45ebbafc6ad506d43db3c94f4bc5bf842c",
                                     @"3c692906f231771f2e1c19a15c2863a9c04b864ff2c45bd0fd46f91231a38bad",
                                     @"aa0e74b6f56eebbf55849f7fc40bf2f163d57e0752a6f724554f6e12fd4ad3f3",
                                     @"16e11b50a91d95a82f64283edd47b890baf8a74af3d408206111574cb8b32a16",
                                     @"a921e6d02823147dda734f8a0bef79d2ccc94cd4e3dc06d5378cbfb051b4a124",
                                     @"451ecdfdbb5ac685f56ec547d62174fbc5cd0b268a908d8336573b34c978ab68",
                                     @"97855159eaadf7e3d0f6fc0b2ffdaaad2a5ffeb1e858fa88d979f3c2042132cd",
                                     @"675ebde16c8719292812b68ed422fefc2a4f74461b6e7af20acf9b676c65082a",
                                     @"662d6de9ed5a85646ebf9e04b63537993be345ed28ebd253c8c0bda5a325ef87",
                                     @"535aca9cde16ebc6d6a51914b6c524044df6d6a87ec7c23c3dc7f355ff445fb5"];

    NSMutableArray * verifyHashes = [NSMutableArray array];

    for (NSString * stringHash in verifyStringHashes) {
        [verifyHashes addObject:stringHash.hexToData.reverse];
    }

    verifyHashes = [[verifyHashes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 hash1 = *(UInt256*)((NSData*)obj1).bytes;
        UInt256 hash2 = *(UInt256*)((NSData*)obj2).bytes;
        return uint256_sup(hash1, hash2)?NSOrderedDescending:NSOrderedAscending;
    }] mutableCopy];


    XCTAssertEqualObjects(verifyHashes,proTxHashes,
                          @"Provider transaction hashes");

    NSMutableArray * simplifiedMasternodeListHashes = [NSMutableArray array];
    for (NSData * proTxHash in proTxHashes) {
        DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [tentativeMasternodeList objectForKey:proTxHash];
        [simplifiedMasternodeListHashes addObject:[NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash]];
    }

    NSArray * verifyStringSMLEHashes = @[@"4090e9167892b3a452891efaf8935a3fa5ebaec7db3bffe1a4073e26a8218d56",
                                         @"d4e7a66aeda72ab6f25e2ffd6c82da297737068fb9eb795a06a42b723b27a2f1",
                                         @"a6b1b82aa961f74eba2f3f369bdb659bb4058f8fbca79909decf11e7ddd80f4d",
                                         @"feaaea4f2bfeb182f9590e100040fee93ddf1ebf4134b87d59012a7d188bcb76",
                                         @"cc5de8a7dfde4b451cb9138df76fcab8adf917bf5261bc9e2736aab73cd8d19e",
                                         @"5912f286cc9c1c86c8bc7cf97650f7b17629a085f951c30bdbd1aae5b79bc417",
                                         @"2c341c8badd76908aba636ee87911886417f5e506c7a0d3b556055eb4c21b6a1",
                                         @"894d469cbafc1b15e345d32815f73dbd21e73980b5362c52d7513a04466f2bbf",
                                         @"6067d7e815f0e14435c45775ae230736a16502fcbf0c42ba55eb0f384c1fb058",
                                         @"6b8e569016e188ebd5908edc5f3ede1fc364bf55398717eaedfa30f0c6cf8b1d",
                                         @"dd7b6adf37b728eb8985fff094b63f92c0a07f49f60edb629b1ff87a69a95080",
                                         @"c341516a6e4ed54d03f2ca6e946d2a2f53dcf624c1ee1822d743c3f4d85745d6",
                                         @"ebd859627703e030150beb7f1e080ee3742d48d8387604aadf53460debb9c2c8",
                                         @"4f87e5bd3e24b87b6894ee59e5f42f3427f7ae03106fc83c8269db0f0c49aa1c"];

    NSMutableArray * verifySMLEHashes = [NSMutableArray array];

    for (NSString * stringHash in verifyStringSMLEHashes) {
        [verifySMLEHashes addObject:stringHash.hexToData];
    }

    XCTAssertEqualObjects(simplifiedMasternodeListHashes,verifySMLEHashes,
                          @"SMLE transaction hashes");

    XCTAssertEqualObjects([NSData merkleRootFromHashes:simplifiedMasternodeListHashes],[NSData dataWithUInt256:coinbaseTransaction.merkleRootMNList],
                          @"MerkleRootEqual");


    XCTAssertEqualObjects([NSData merkleRootFromHashes:simplifiedMasternodeListHashes],@"6c45528d7b8d4e7a33614a1c3806f4faf5c463f0b313aa0ece1ce12c34154a44".hexToData,
                          @"MerkleRootEqual Value");

    //we need to check that the coinbase is in the transaction hashes we got back
    UInt256 coinbaseHash = coinbaseTransaction.txHash;
    BOOL foundCoinbase = FALSE;
    for (int i = 0;i<merkleHashes.length;i+=32) {
        UInt256 randomTransactionHash = [merkleHashes UInt256AtOffset:i];
        if (uint256_eq(coinbaseHash, randomTransactionHash)) {
            foundCoinbase = TRUE;
            break;
        }
    }

    XCTAssert(foundCoinbase,@"The coinbase was not part of provided hashes");

    //we need to check that the merkle tree is correct
    NSData * merkleRoot = @"ef45ec04d27938efb81184f97ceab908dbb66245c2dbffdf97b82b92bcddbd6e".hexToData;
    DSMerkleBlock * coinbaseVerificationMerkleBlock = [[DSMerkleBlock alloc] initWithBlockHash:blockHash merkleRoot:[merkleRoot UInt256] totalTransactions:totalTransactions hashes:merkleHashes flags:merkleFlags];

    XCTAssert([coinbaseVerificationMerkleBlock isMerkleTreeValid],@"Coinbase is not part of the valid merkle tree");
}

    
@end

