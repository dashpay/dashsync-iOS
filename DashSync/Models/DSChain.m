//
//  DSChain.m
//  DashSync
//  Created by Quantum Explorer on 05/05/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSChain.h"
#import "DSPeer.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSEventManager.h"
#import "DSBloomFilter.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSPriceManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "DSPeerManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSCoder+Dash.h"
#import "DSAccount.h"
#import "DSBIP39Mnemonic.h"
#import "DSDerivationPath.h"
#import "DSOptionsManager.h"
#import "DSChainsManager.h"
#import "DSMasternodeManager.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "NSMutableData+Dash.h"
#import "NSData+Dash.h"
#import "DSSporkManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSChainManager.h"
#import "DSFundsDerivationPath.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSTransition.h"
#import "DSLocalMasternode+Protected.h"
#import "DSKey.h"
#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"
#import "DSCreditFundingTransaction.h"
#import "NSManagedObject+Sugar.h"

typedef const struct checkpoint { uint32_t height; const char *checkpointHash; uint32_t timestamp; uint32_t target; const char * masternodeListPath; const char * merkleRoot;} checkpoint;

static checkpoint testnet_checkpoint_array[] = {
    {           0, "00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c", 1390666206, 0x1e0ffff0u, "", "" },
    {        1500, "000002d7a07979a4d6b24efdda0bbf6e3c03a59c22765a0128a5c53b3888aa28", 1423460945, 0x1e03ffffu, "", "" },
    {        2000, "000006b9af71c8ac510ff912b632ff91a2e05ab92ba4de9f1ec4be424c4ba636", 1462833216, 0x1e0fffffu, "", "" },
    {        2999, "0000024bc3f4f4cb30d29827c13d921ad77d2c6072e586c7f60d83c2722cdcc5", 1462856598, 0x1e03ffffu, "", "" },
    {        4002, "00000534b6b0a7ba8746a412384c9c9bbd492e03e2babd2878f0723981f03978", 1544736464, 0x1e0fffffu, "", "" },
    {        8000, "0000001618273379c4d96403954480bdf5c522d734f457716db1295d7a3646e0", 1545231876, 0x1d1c3ba6u, "", "" },
    {       15000, "00000000172f1946aad9183732d65aaa117d47c2e86c698940bd942dc7ffccc5", 1546203631, 0x1c19907eu, "", "" },
    {       19500, "000000000735c41ba5948fbe6c791d5e28b02e3eff5ea4ac7fecf6d07c488edf", 1546803426, 0x1c0daf28u, "", "" }, //important for testInstantSendReceiveTransaction
    {       28000, "000000000204f318ee830af7416def9e45cef5507401fcc27a9627cbc28bb689", 1547961658, 0x1c0cd81bu, "", "" },
    {       50000, "0000000000d737f4b6f0fcd10ecd2f59e5e4f9409b1afae5fb50604510a2551f", 1550935893, 0x1c00e933u, "", "" },
    {      100000, "000000008650f09124958e7352f844f9c15705171ac38ee6668534c5c238b916", 1558052383, 0x1d00968du, "", "" },
    {      122064, "0000000003fa1af7f55b5cde19da8c8fdb024a881a50794cd1c31e0cb4506b3d", 1561126213, 0x1c0c2849u, "", "" }, //for tests
    {      122088, "0000000007eec28e1459b36de6e54ac81fa2dc2b12a797ac77ee7c7f7a59148f", 1561129080, 0x1c0839adu, "", "" }, //for tests
    {      122928, "0000000001d975dfc73df9040e894576f27f6c252f1540b1c092c80353cdb823", 1561247926, 0x1c0b30d2u, "", "" }, //for tests
    {      123000, "000000000577855d5599ce9a89417628233a6ccf3a86b2938b191f3dfed2e63d", 1561258020, 0x1c0d4446u, "", "" }, //for tests
    {      180000, "000000000175f718920ecebd54765faee973975511415f1dd1ef12194518675b", 1569211090, 0x1c025786u, "", "" }
};

// blockchain checkpoints - these are also used as starting points for partial chain downloads, so they need to be at
// difficulty transition boundaries in order to verify the block difficulty at the immediately following transition
static checkpoint mainnet_checkpoint_array[] = {
    {       0, "00000ffd590b1485b3caadc19b22e6379c733355108f107a430458cdf3407ab6", 1390095618, 0x1e0ffff0u, "", "" },//dash
    {    1500, "000000aaf0300f59f49bc3e970bad15c11f961fe2347accffff19d96ec9778e3", 1390109863, 0x1e00ffffu, "", "" },//dash
    {    4991, "000000003b01809551952460744d5dbb8fcbd6cbae3c220267bf7fa43f837367", 1390271049, 0x1c426980u, "", "" },//dash
    {    9918, "00000000213e229f332c0ffbe34defdaa9e74de87f2d8d1f01af8d121c3c170b", 1391392449, 0x1c41cc20u, "", "" },//dash
    {   16912, "00000000075c0d10371d55a60634da70f197548dbbfa4123e12abfcbc5738af9", 1392328997, 0x1c07cc3bu, "", "" },//dash
    {   23912, "0000000000335eac6703f3b1732ec8b2f89c3ba3a7889e5767b090556bb9a276", 1393373461, 0x1c0177efu, "", "" },//dash
    {   35457, "0000000000b0ae211be59b048df14820475ad0dd53b9ff83b010f71a77342d9f", 1395110315, 0x1c00da53u, "", "" },//dash
    {   45479, "000000000063d411655d590590e16960f15ceea4257122ac430c6fbe39fbf02d", 1396620889, 0x1c009c80u, "", "" },//dash
    {   55895, "0000000000ae4c53a43639a4ca027282f69da9c67ba951768a20415b6439a2d7", 1398190161, 0x1c00bae3u, "", "" },//dash
    {   68899, "0000000000194ab4d3d9eeb1f2f792f21bb39ff767cb547fe977640f969d77b7", 1400148293, 0x1b25df16u, "", "" },//dash
    {   74619, "000000000011d28f38f05d01650a502cc3f4d0e793fbc26e2a2ca71f07dc3842", 1401048723, 0x1b1905e3u, "", "" },//dash
    {   75095, "0000000000193d12f6ad352a9996ee58ef8bdc4946818a5fec5ce99c11b87f0d", 1401126238, 0x1b2587e3u, "", "" },//dash
    {   88805, "00000000001392f1652e9bf45cd8bc79dc60fe935277cd11538565b4a94fa85f", 1403283082, 0x1b194dfbu, "", "" },//dash
    {  107996, "00000000000a23840ac16115407488267aa3da2b9bc843e301185b7d17e4dc40", 1406300692, 0x1b11c217u, "", "" },//dash
    {  137993, "00000000000cf69ce152b1bffdeddc59188d7a80879210d6e5c9503011929c3c", 1411014812, 0x1b1142abu, "", "" },//dash
    {  167996, "000000000009486020a80f7f2cc065342b0c2fb59af5e090cd813dba68ab0fed", 1415730882, 0x1b112d94u, "", "" },//dash
    {  207992, "00000000000d85c22be098f74576ef00b7aa00c05777e966aff68a270f1e01a5", 1422026638, 0x1b113c01u, "", "" },//dash
    {  217752, "00000000000a7baeb2148272a7e14edf5af99a64af456c0afc23d15a0918b704", 1423563332, 0x1b10c9b6u, "", "" },//dash
    {  227121, "00000000000455a2b3a2ed5dfb03990043ca0074568b939acec62820e89a6c45", 1425039295, 0x1b1261d6u, "", "" },//dash This is the first sync time (aka BIP39 creation time).
    {  246209, "00000000000eec6f7871d3d70321ae98ef1007ab0812d876bda1208afcfb7d7d", 1428046505, 0x1b1a5e27u, "", "" },//dash
    {  298549, "00000000000cc467fbfcfd49b82e4f9dc8afb0ef83be7c638f573be6a852ba56", 1436306353, 0x1b1ff0dbu, "", "" },//dash
    {  312645, "0000000000059dcb71ad35a9e40526c44e7aae6c99169a9e7017b7d84b1c2daf", 1438525019, 0x1b1c46ceu, "", "" },//dash
    {  340000, "000000000014f4e32be2038272cc074a75467c342e25bfe0b566fabe927240b4", 1442833344, 0x1b1acd73u, "", "" },
    {  360000, "0000000000136c1c34bfeb783103c77331930768e864aaf91859b302558d292c", 1445983058, 0x1b21ec4eu, "", "" },
    {  380000, "00000000000a5ab368be389a048caac7435d7244960e69adaa53eb0b94f8b3c3", 1442833344, 0x1b16c480u, "", "" },
    {  400000, "00000000000132b9afeca5e9a2fdf4477338df6dcff1342300240bc70397c4bb", 1452288263, 0x1b0d642eu, "", "" },
    {  420000, "000000000006bd43eeab52946f5f47517441ac2339568401468ed6079b83c38e", 1455442477, 0x1b0eda3au, "", "" },
    {  440000, "000000000005aca0dc68800e5cd701f4f3bf53e8e0c85d25f03d21a372e23f17", 1458594501, 0x1b124590u, "", "" },
    {  460000, "00000000000eab034824bb5284946b36d8890d7c9f657048d3c7d1f405b1a36c", 1461747567, 0x1b14a0c0u, "", "" },
    {  480000, "0000000000032ddb3552f63d2c641af5e4e2ca3c25bdcee85c1453876356ff81", 1464893443, 0x1b091760u, "", "" },
    {  500000, "000000000002be1cff717f4aa6efc504fa06dc9c453c83773de0b712b8690b7d", 1468042975, 0x1b06a6cfu, "", "" },
    {  520000, "000000000002dbfe2d15094c45b9bdf2c511e491af72aeadcb935a926389f468", 1471190891, 0x1b02e8bdu, "", "" },
    {  540000, "000000000000daaac22af98ed775d153878c343e019155ed34c46110a12bd112", 1474340382, 0x1b01a7e0u, "", "" },
    {  560000, "000000000000b7c1e52ebc9858305793af9554e67399e8d5c6839915b3e91214", 1477493476, 0x1b01da33u, "", "" },
    {  580000, "000000000001636ac338ed16dc9fc06aeed60b595e647e014c89a2f0724e3086", 1480643973, 0x1b0184aeu, "", "" },
    {  600000, "000000000000a0b730b5be60e65b4a730d1fdcf1d023c9e42c0e5bf4a059f709", 1483795508, 0x1b00db54u, "", "" },
    {  620000, "0000000000002e7f2ab6cefe6f63b34c821e7f2f8aa5525c6409dc57677044b4", 1486948317, 0x1b0100c5u, "", "" },
    {  640000, "00000000000079dfa97353fd50a420a4425b5e96b1699927da5e89cbabe730bf", 1490098758, 0x1b009c90u, "", "" },
    {  660000, "000000000000124a71b04fa91cc37e510fabd66f2286491104ecf54f96148275", 1493250273, 0x1a710fe7u, "", "" },
    {  680000, "00000000000012b333e5ba8a85895bcafa8ad3674c2fb8b2de98bf3a5f08fa81", 1496400309, 0x1a64bc7au, "", "" },
    {  700000, "00000000000002958852d255726d695ecccfbfacfac318a9d0ebc558eecefeb9", 1499552504, 0x1a37e005u, "", "" },
    {  720000, "0000000000000acfc49b67e8e72c6faa2d057720d13b9052161305654b39b281", 1502702260, 0x1a158e98u, "", "" },
    {  740000, "00000000000008d0d8a9054072b0272024a01d1920ab4d5a5eb98584930cbd4c", 1505852282, 0x1a0ab756u, "", "" },
    {  760000, "000000000000011131c4a8c6446e6ce4597a192296ecad0fb47a23ae4b506682", 1508998683, 0x1a014ed1u, "", "" },
    {  780000, "0000000000000019c30fd5b13548fe169068cbcedb1efb14a630398c26a0ae3b", 1512146289, 0x19408279u, "", "" },
    {  800000, "000000000000002a702916db91213077926866437a6b63e90548af03647d5df3", 1515298907, 0x193a412au, "", "" },
    {  820000, "0000000000000006619ae1f0fc453690183f571817ef677a822b76d133ea920b", 1518449736, 0x192ab829u, "", "" },
    {  840000, "000000000000000dfb1273aad00884845ddbde6371f44f3fe1a157d057e7757e", 1521602534, 0x194d5e8eu, "", "" },
    {  860000, "000000000000001ed76fb953e7e96daf7000f657594a909540b0da6aa2252393", 1524751102, 0x1933df60u, "", "" },
    {  880000, "000000000000001c980f140d5ff954581b0b35d680e03f4aeba30505cb1072a6", 1527903835, 0x1962d4edu, "", "" },
    {  900000, "000000000000001eedab948c433a50b1131a8e15c8c2beef4be237701feff7b5", 1531055382, 0x1945cebcu, "", "" },
    {  920000, "00000000000000341469d7ab5aa190cbf49a19ac69afcf8cfd608d7f8cdf7245", 1534206756, 0x1950c940u, "", "" },
    {  940000, "000000000000001232b541264361386c0ea40ac3f0b72814b48a16a249c5386c", 1537357320, 0x1952e364u, "", "" },
    {  960000, "000000000000004a74127b49e7eebbde24253f08677880b4d0fd20c5637ab68c", 1540510859, 0x1965c6b0u, "", "" },
    {  980000, "0000000000000014a649707045782b2fa540492865a253d8beec12de1c69d513", 1543661716, 0x1935793au, "", "" },
    { 1000000, "000000000000000c9167ee9675411440e10e9adbc21fb57b88879fc293e9d494", 1546810296, 0x194a441cu, "", "" },
    { 1020000, "000000000000000ec0df78766bfe87f2414177c64a3960dc0ab06351ba81881e", 1549961482, 0x19469e2au, "", "" },
    { 1040000, "0000000000000014ddf198355bf1e10dd848465b0296097a520619c73f87e11a", 1553111735, 0x1934898bu, "", "" },
    { 1060000, "00000000000000132447e6bac9fe0d7d756851450eab29358787dc05d809bf07", 1556260812, 0x191f6aceu, "", "" },
    { 1080000, "00000000000000099c5cc38bac7878f771408537e520a1ef9e31b5c1040d2d2a", 1559412342, 0x192a9588u, "", "" },
    { 1088640, "00000000000000112e41e4b3afda8b233b8cc07c532d2eac5de097b68358c43e", 1560773201, 0x1922ae0bu, "ML1088640", "379fd491044a273372a8e901866fbe6ed9bab7ce2de0968a71d38de5d5eac340" },
    { 1100000, "00000000000000190560ed4b128c156e489fdbe0814bf62c8ab53ab3259d7908", 1562561033, 0x191a9f05u, "", ""},
    { 1120000, "0000000000000011103eae768e6a322b991c5c20569d95930b87e1305fa19c75", 1565712301, 0x19200768u, "", ""},
    { 1140000, "00000000000000083ac0e592e180487cb237f659a305d2be19e883ed564fe20f", 1568864488, 0x1923198bu, "", ""},
    { 1160000, "00000000000000098f985e79ca74ca2cf8c113763f8184011759306945149309", 1572017931, 0x191f3f6eu, "", ""},
    { 1180000, "0000000000000001e1de4be8cafd6b0dc70a16293f8e82bcc41a87d80032ac34", 1575169584, 0x191bb2a5u, "", ""},
    { 1200000, "0000000000000005fbc6c64e048be7c29d43e4829f360220cededb73ce84894c", 1578321180, 0x191c82aau, "ML1200000", "76c45ae14e68484bcd26d55cfee6155778e573c6dba4b68764189e25d50c0fe4"},
};

#define FEE_PER_BYTE_KEY          @"FEE_PER_BYTE"

#define CHAIN_WALLETS_KEY  @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY  @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY  @"REGISTERED_PEERS_KEY"

#define PROTOCOL_VERSION_LOCATION  @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION  @"MIN_PROTOCOL_VERSION_LOCATION"

#define STANDARD_PORT_LOCATION  @"STANDARD_PORT_LOCATION"
#define JRPC_PORT_LOCATION  @"JRPC_PORT_LOCATION"
#define GRPC_PORT_LOCATION  @"GRPC_PORT_LOCATION"

#define SPORK_PUBLIC_KEY_LOCATION  @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION  @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION  @"SPORK_PRIVATE_KEY_LOCATION"

#define CHAIN_VOTING_KEYS_KEY  @"CHAIN_VOTING_KEYS_KEY"

#define LOG_PREV_BLOCKS_ON_ORPHAN 0

// number of previous confirmations needed in ix inputs
#define MAINNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED 6
#define TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED 2

@interface DSChain ()

@property (nonatomic, strong) DSMerkleBlock *lastBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary *blocks, *orphans;
@property (nonatomic, strong) NSMutableDictionary <NSData*,DSCheckpoint*> *checkpointsByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary <NSNumber*,DSCheckpoint*> *checkpointsByHeightDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, copy) NSString * networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> * mWallets;
@property (nonatomic, strong) DSChainEntity * mainThreadChainEntity;
@property (nonatomic, strong) DSChainEntity * delegateQueueChainEntity;
@property (nonatomic, strong) NSString * devnetIdentifier;
@property (nonatomic, strong) DSAccount * viewingAccount;
@property (nonatomic, strong) NSMutableDictionary * estimatedBlockHeights;
@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;
@property (nonatomic, assign) uint64_t ixPreviousConfirmationsNeeded;
@property (nonatomic, assign) uint32_t cachedMinProtocolVersion;
@property (nonatomic, assign) uint32_t cachedProtocolVersion;
@property (nonatomic, assign) uint32_t cachedStandardPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiJRPCPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiGRPCPort;
@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

-(instancetype)init {
    if (! (self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.orphans = [NSMutableDictionary dictionary];
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.mWallets = [NSMutableArray array];
    self.estimatedBlockHeights = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    
    self.feePerByte = DEFAULT_FEE_PER_B;
    uint64_t feePerByte = [[NSUserDefaults standardUserDefaults] doubleForKey:FEE_PER_BYTE_KEY];
    if (feePerByte >= MIN_FEE_PER_B && feePerByte <= MAX_FEE_PER_B) self.feePerByte = feePerByte;
    
    return self;
}

- (instancetype)initWithType:(DSChainType)type checkpoints:(NSArray*)checkpoints
{
    if (! (self = [self init])) return nil;
    _chainType = type;
    switch (type) {
        case DSChainType_MainNet: {
            self.standardPort = MAINNET_STANDARD_PORT;
            self.standardDapiJRPCPort = MAINNET_DAPI_JRPC_STANDARD_PORT;
            self.ixPreviousConfirmationsNeeded = MAINNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED;
            break;
        }
        case DSChainType_TestNet: {
            self.standardPort = TESTNET_STANDARD_PORT;
            self.standardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
            self.ixPreviousConfirmationsNeeded = TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED;
            break;
        }
        case DSChainType_DevNet: {
            NSAssert(NO, @"DevNet should be configured with initAsDevnetWithIdentifier:checkpoints:port:dapiPort:ixPreviousConfirmationsNeeded:");
            break;
        }
    }
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.mainThreadChainEntity = [self chainEntity];

    return self;
}

-(void)setUp {
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
}


-(instancetype)initAsDevnetWithIdentifier:(NSString*)identifier checkpoints:(NSArray<DSCheckpoint*>*)checkpoints port:(uint32_t)port dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort ixPreviousConfirmationsNeeded:(uint64_t)ixPreviousConfirmationsNeeded
{
    //for devnet the genesis checkpoint is really the second block
    if (! (self = [self init])) return nil;
    _chainType = DSChainType_DevNet;
    if (!checkpoints || ![checkpoints count]) {
        DSCheckpoint * genesisCheckpoint = [DSCheckpoint genesisDevnetCheckpoint];
        DSCheckpoint * secondCheckpoint = [self createDevNetGenesisBlockCheckpointForParentCheckpoint:genesisCheckpoint withIdentifier:identifier];
        self.checkpoints = @[genesisCheckpoint,secondCheckpoint];
        self.genesisHash = secondCheckpoint.checkpointHash;
    } else {
        self.checkpoints = checkpoints;
        self.genesisHash = checkpoints[1].checkpointHash;
    }
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.checkpoints[0].checkpointHash]);
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.genesisHash]);
    self.standardPort = port;
    self.standardDapiJRPCPort = dapiJRPCPort;
    self.standardDapiGRPCPort = dapiGRPCPort;
    self.ixPreviousConfirmationsNeeded = ixPreviousConfirmationsNeeded;
    self.devnetIdentifier = identifier;
    self.mainThreadChainEntity = [self chainEntity];
    return self;
}

//static CBlock CreateDevNetGenesisBlock(const uint256 &prevBlockHash, const std::string& devNetName, uint32_t nTime, uint32_t nNonce, uint32_t nBits, const CAmount& genesisReward)
//{
//    assert(!devNetName.empty());
//
//    CMutableTransaction txNew;
//    txNew.nVersion = 1;
//    txNew.vin.resize(1);
//    txNew.vout.resize(1);
//    // put height (BIP34) and devnet name into coinbase
//    txNew.vin[0].scriptSig = CScript() << 1 << std::vector<unsigned char>(devNetName.begin(), devNetName.end());
//    txNew.vout[0].nValue = genesisReward;
//    txNew.vout[0].scriptPubKey = CScript() << OP_RETURN;
//
//    CBlock genesis;
//    genesis.nTime    = nTime;
//    genesis.nBits    = nBits;
//    genesis.nNonce   = nNonce;
//    genesis.nVersion = 4;
//    genesis.vtx.push_back(MakeTransactionRef(std::move(txNew)));
//    genesis.hashPrevBlock = prevBlockHash;
//    genesis.hashMerkleRoot = BlockMerkleRoot(genesis);
//    return genesis;
//}

-(UInt256)blockHashForDevNetGenesisBlockWithVersion:(uint32_t)version prevHash:(UInt256)prevHash merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce {
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt32:version];
    
    [d appendBytes:&prevHash length:sizeof(prevHash)];
    [d appendBytes:&merkleRoot length:sizeof(merkleRoot)];
    [d appendUInt32:timestamp];
    [d appendUInt32:target];
    [d appendUInt32:nonce];
    return d.x11;
}

-(DSCheckpoint*)createDevNetGenesisBlockCheckpointForParentCheckpoint:(DSCheckpoint*)checkpoint withIdentifier:(NSString*)identifier {
    uint32_t nTime = checkpoint.timestamp + 1;
    uint32_t nBits = checkpoint.target;
    UInt256 fullTarget = setCompact(nBits);
    uint32_t nVersion = 4;
    UInt256 prevHash = checkpoint.checkpointHash;
    UInt256 merkleRoot = [DSTransaction devnetGenesisCoinbaseWithIdentifier:identifier forChain:self].txHash;
    uint32_t nonce = UINT32_MAX; //+1 => 0;
    UInt256 blockhash;
    do {
        nonce++; //should start at 0;
        blockhash = [self blockHashForDevNetGenesisBlockWithVersion:nVersion prevHash:prevHash merkleRoot:merkleRoot timestamp:nTime target:nBits nonce:nonce];
    } while (nonce < UINT32_MAX && uint256_sup(blockhash, fullTarget));
    DSCheckpoint * block2Checkpoint = [[DSCheckpoint alloc] init];
    block2Checkpoint.height = 1;
    block2Checkpoint.checkpointHash = blockhash;//*(UInt256*)[NSData dataWithUInt256:blockhash].reverse.bytes;
    block2Checkpoint.target = nBits;
    block2Checkpoint.timestamp = nTime;
    return block2Checkpoint;
}

+(NSMutableArray*)createCheckpointsArrayFromCheckpoints:(checkpoint*)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray * checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i <checkpointCount;i++) {
        DSCheckpoint * check = [DSCheckpoint new];
        check.height = checkpoints[i].height;
        check.checkpointHash = *(UInt256 *)[NSString stringWithCString:checkpoints[i].checkpointHash encoding:NSUTF8StringEncoding].hexToData.reverse.bytes;
        check.target = checkpoints[i].target;
        check.timestamp = checkpoints[i].timestamp;
        check.masternodeListName = [NSString stringWithCString:checkpoints[i].masternodeListPath encoding:NSUTF8StringEncoding];
        NSString * merkleRootString = [NSString stringWithCString:checkpoints[i].merkleRoot encoding:NSUTF8StringEncoding];
        check.merkleRoot = [merkleRootString isEqualToString:@""]?UINT256_ZERO:merkleRootString.hexToData.reverse.UInt256;
        [checkpointMutableArray addObject:check];
    }
    return [checkpointMutableArray copy];
}

-(DSChainEntity*)chainEntity {
    if ([NSThread isMainThread] && _mainThreadChainEntity) return self.mainThreadChainEntity;
    __block DSChainEntity* chainEntity = nil;
    [[DSChainEntity context] performBlockAndWait:^{
        chainEntity = [DSChainEntity chainEntityForType:self.chainType devnetIdentifier:self.devnetIdentifier checkpoints:self.checkpoints];
    }];
    return chainEntity;
}

-(DSChainManager*)chainManager {
    if (_chainManager) return _chainManager;
    return [[DSChainsManager sharedInstance] chainManagerForChain:self];
}

+(DSChain*)mainnet {
    static DSChain* _mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:DSChainType_MainNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array)/sizeof(*mainnet_checkpoint_array))]];
        
        inSetUp = TRUE;
        //DSDLog(@"%@",[NSData dataWithUInt256:_mainnet.checkpoints[0].checkpointHash]);
    });
    if (inSetUp) {
        [_mainnet setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_mainnet chainEntity];
            _mainnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _mainnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _mainnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return _mainnet;
}

+(DSChain*)testnet {
    static DSChain* _testnet = nil;
    static dispatch_once_t testnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&testnetToken, ^{
        _testnet = [[DSChain alloc] initWithType:DSChainType_TestNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array)/sizeof(*testnet_checkpoint_array))]];
        inSetUp = TRUE;
    });
    if (inSetUp) {
        [_testnet setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_testnet chainEntity];
            _testnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _testnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _testnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return _testnet;
}

static NSMutableDictionary * _devnetDictionary = nil;
static dispatch_once_t devnetToken = 0;

+(DSChain*)devnetWithIdentifier:(NSString*)identifier {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = [_devnetDictionary objectForKey:identifier];
    return devnetChain;
}

+(DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:identifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:identifier checkpoints:checkpointArray port:port dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort ixPreviousConfirmationsNeeded:TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED];
            [_devnetDictionary setObject:devnetChain forKey:identifier];
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:identifier];
        }
    }
    if (inSetUp) {
        [devnetChain setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [devnetChain chainEntity];
            devnetChain.totalMasternodeCount = chainEntity.totalMasternodeCount;
            devnetChain.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            devnetChain.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return devnetChain;
}

+(DSChain*)chainForNetworkName:(NSString*)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    return @[[DSFundsDerivationPath bip32DerivationPathForAccountNumber:accountNumber onChain:self],[DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self],[DSDerivationPath masterBlockchainIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self]];
}


-(void)save {
    [self.managedObjectContext performBlockAndWait:^{
        DSChainEntity * entity = self.chainEntity;
        entity.totalMasternodeCount = self.totalMasternodeCount;
        entity.totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        entity.baseBlockHash = [NSData dataWithUInt256:self.masternodeBaseBlockHash];
        [DSChainEntity saveContext];
    }];
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}",self.name]];
}

// MARK: - Check Type

-(BOOL)isMainnet {
    return [self chainType] == DSChainType_MainNet;
}

-(BOOL)isTestnet {
    return [self chainType] == DSChainType_TestNet;
}

-(BOOL)isEvonet {
    return ([self chainType] == DSChainType_DevNet) && [[self devnetIdentifier] isEqualToString:@"devnet-evonet"];
}

-(BOOL)isDevnetAny {
    return [self chainType] == DSChainType_DevNet;
}

-(BOOL)isEvolutionEnabled {
    return [self isDevnetAny];
}

-(NSString*)uniqueID {
    if (!_uniqueID) {
        _uniqueID = [[NSData dataWithUInt256:[self genesisHash]] shortHexString];
    }
    return _uniqueID;
}

-(BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    if ([self chainType] != DSChainType_DevNet) {
        return false;
    } else {
        return uint256_eq([self genesisHash],genesisHash);
    }
}

-(uint32_t)magicNumber {
    switch (_chainType) {
        case DSChainType_MainNet:
            return DASH_MAGIC_NUMBER_MAINNET;
        case DSChainType_TestNet:
            return DASH_MAGIC_NUMBER_TESTNET;
        case DSChainType_DevNet:
            return DASH_MAGIC_NUMBER_DEVNET;
        default:
            return DASH_MAGIC_NUMBER_MAINNET;
            break;
    }
}

-(uint16_t)transactionVersion {
    switch (_chainType) {
        case DSChainType_MainNet:
            return 1;
        case DSChainType_TestNet:
            return 1;
        case DSChainType_DevNet:
            return 3;
        default:
            return 3;
            break;
    }
}

-(NSString*)chainWalletsKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_WALLETS_KEY,[self uniqueID]];
}

-(NSString*)chainStandaloneDerivationPathsKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_STANDALONE_DERIVATIONS_KEY,[self uniqueID]];
}

-(NSString*)registeredPeersKey {
    return [NSString stringWithFormat:@"%@_%@",REGISTERED_PEERS_KEY,[self uniqueID]];
}

-(NSString*)votingKeysKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_VOTING_KEYS_KEY,[self uniqueID]];
}


// MARK: - Chain Parameters



-(uint32_t)protocolVersion {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return PROTOCOL_VERSION_MAINNET;
        case DSChainType_TestNet:
            return PROTOCOL_VERSION_TESTNET;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t protocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,PROTOCOL_VERSION_LOCATION], &error);
            if (!error && protocolVersion) return protocolVersion;
            else return PROTOCOL_VERSION_DEVNET;
        }
        default:
            break;
    }
}

-(void)setProtocolVersion:(uint32_t)protocolVersion
{
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(protocolVersion,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,PROTOCOL_VERSION_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}


-(uint32_t)minProtocolVersion {
    if (_cachedMinProtocolVersion) return _cachedMinProtocolVersion;
    switch ([self chainType]) {
        case DSChainType_MainNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_MAINNET;
            break;
        }
        case DSChainType_TestNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_TESTNET;
            break;
        }
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_DEVNET;
            break;
        }
        default:
            break;
    }
    return _cachedMinProtocolVersion;
}


-(void)setMinProtocolVersion:(uint32_t)minProtocolVersion
{
    if (minProtocolVersion < MIN_VALID_MIN_PROTOCOL_VERSION || minProtocolVersion > MAX_VALID_MIN_PROTOCOL_VERSION) return;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET),[NSString stringWithFormat:@"MAINNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
            break;
        case DSChainType_TestNet:
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET),[NSString stringWithFormat:@"TESTNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
            break;
        case DSChainType_DevNet:
        {
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET),[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
            break;
        }
        default:
            break;
    }
}

-(uint32_t)standardPort {
    if (_cachedStandardPort) return _cachedStandardPort;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            _cachedStandardPort = MAINNET_STANDARD_PORT;
            return MAINNET_STANDARD_PORT;
        case DSChainType_TestNet:
            _cachedStandardPort = TESTNET_STANDARD_PORT;
            return TESTNET_STANDARD_PORT;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t cachedStandardPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,STANDARD_PORT_LOCATION], &error);
            if (!error && cachedStandardPort) {
                _cachedStandardPort = cachedStandardPort;
                return _cachedStandardPort;
            }
            else return DEVNET_STANDARD_PORT;
            break;
        }
        default:
            break;
    }
}

-(void)setStandardPort:(uint32_t)standardPort {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(standardPort,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,STANDARD_PORT_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}

-(uint32_t)standardDapiGRPCPort {
    if (_cachedStandardDapiGRPCPort) return _cachedStandardDapiGRPCPort;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            _cachedStandardDapiGRPCPort = MAINNET_DAPI_GRPC_STANDARD_PORT;
            return MAINNET_DAPI_GRPC_STANDARD_PORT;
        case DSChainType_TestNet:
            _cachedStandardDapiGRPCPort = TESTNET_DAPI_GRPC_STANDARD_PORT;
            return TESTNET_DAPI_GRPC_STANDARD_PORT;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t cachedStandardDapiGRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,GRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiGRPCPort) {
                _cachedStandardDapiGRPCPort = cachedStandardDapiGRPCPort;
                return _cachedStandardDapiGRPCPort;
            }
            else return DEVNET_DAPI_GRPC_STANDARD_PORT;
            break;
        }
        default:
            break;
    }
}

-(void)setStandardDapiGRPCPort:(uint32_t)standardDapiGRPCPort {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(standardDapiGRPCPort,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,GRPC_PORT_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}

-(uint32_t)standardDapiJRPCPort {
    if (_cachedStandardDapiJRPCPort) return _cachedStandardDapiJRPCPort;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            _cachedStandardDapiJRPCPort = MAINNET_DAPI_JRPC_STANDARD_PORT;
            return MAINNET_DAPI_JRPC_STANDARD_PORT;
        case DSChainType_TestNet:
            _cachedStandardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
            return TESTNET_DAPI_JRPC_STANDARD_PORT;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t cachedStandardDapiJRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,JRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiJRPCPort) {
                _cachedStandardDapiJRPCPort = cachedStandardDapiJRPCPort;
                return _cachedStandardDapiJRPCPort;
            }
            else return DEVNET_DAPI_JRPC_STANDARD_PORT;
            break;
        }
        default:
            break;
    }
}

-(void)setStandardDapiJRPCPort:(uint32_t)standardDapiJRPCPort {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(standardDapiJRPCPort,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,JRPC_PORT_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}



-(uint32_t)maxProofOfWork {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return MAX_PROOF_OF_WORK_MAINNET;
        case DSChainType_TestNet:
            return MAX_PROOF_OF_WORK_TESTNET;
        case DSChainType_DevNet:
            return MAX_PROOF_OF_WORK_DEVNET;
        default:
            return MAX_PROOF_OF_WORK_MAINNET;
            break;
    }
}

-(BOOL)allowMinDifficultyBlocks {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return NO;
        case DSChainType_TestNet:
            return YES;
        case DSChainType_DevNet:
            return YES;
        default:
            return NO;
            break;
    }
}


-(NSString*)networkName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"main";
            break;
        case DSChainType_TestNet:
            return @"test";
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return @"dev";
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)name {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"Mainnet";
            break;
        case DSChainType_TestNet:
            return @"Testnet";
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [@"Devnet - " stringByAppendingString:self.devnetIdentifier];
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)localizedName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return DSLocalizedString(@"Mainnet",nil);
            break;
        case DSChainType_TestNet:
            return DSLocalizedString(@"Testnet",nil);
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [NSString stringWithFormat:@"%@ - %@", DSLocalizedString(@"Devnet",nil),self.devnetIdentifier];
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(void)setDevnetNetworkName:(NSString*)networkName {
    if ([self chainType] == DSChainType_DevNet) _networkName = @"Evonet";
}

-(uint64_t)baseReward {
    if ([self chainType] == DSChainType_MainNet) return 5 * DUFFS;
    return 50 * DUFFS;
}

-(uint32_t)peerMisbehavingThreshold {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return 20;
            break;
        case DSChainType_TestNet:
            return 40;
            break;
        case DSChainType_DevNet:
            return 3;
            break;
        default:
            break;
    }
    return 20;
}

-(DSCheckpoint*)lastCheckpoint {
    return [[self checkpoints] lastObject];
}

-(NSString*)sporkPublicKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
            break;
        case DSChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PUBLIC_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkPublicKey:(NSString *)sporkPublicKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkPublicKey,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PUBLIC_KEY_LOCATION], NO);
        }
        default:
            break;
    }
}

-(NSString*)sporkPrivateKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return nil;
            break;
        case DSChainType_TestNet:
            return nil;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PRIVATE_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkPrivateKey:(NSString *)sporkPrivateKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkPrivateKey,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PRIVATE_KEY_LOCATION], YES);
        }
        default:
            break;
    }
}

-(NSString*)sporkAddress {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return SPORK_ADDRESS_MAINNET;
            break;
        case DSChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_ADDRESS_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkAddress:(NSString *)sporkAddress {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkAddress,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_ADDRESS_LOCATION], NO);
        }
        default:
            break;
    }
}

// MARK: - Standalone Derivation Paths

-(DSAccount*)viewingAccount {
    if (_viewingAccount) return _viewingAccount;
    self.viewingAccount = [[DSAccount alloc] initAsViewOnlyWithAccountNumber:0 withDerivationPaths:@[] inContext:self.managedObjectContext];
    return _viewingAccount;
}

-(void)retrieveStandaloneDerivationPaths {
    NSError * error = nil;
    NSArray * standaloneIdentifiers = getKeychainArray(self.chainStandaloneDerivationPathsKey, &error);
    if (!error) {
        for (NSString * derivationPathIdentifier in standaloneIdentifiers) {
            DSDerivationPath * derivationPath = [[DSDerivationPath alloc] initWithExtendedPublicKeyIdentifier:derivationPathIdentifier onChain:self];
            
            if (derivationPath) {
                [self addStandaloneDerivationPath:derivationPath];
            }
        }
    }
}

-(void)unregisterAllStandaloneDerivationPaths {
    for (DSDerivationPath * standaloneDerivationPath in [self.viewingAccount.fundDerivationPaths copy]) {
        [self unregisterStandaloneDerivationPath:standaloneDerivationPath];
    }
}

-(void)unregisterStandaloneDerivationPath:(DSDerivationPath*)derivationPath {
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, &error) mutableCopy];
    if (!keyChainArray) return;
    [keyChainArray removeObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    [self.viewingAccount removeDerivationPath:derivationPath];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}
-(void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath {
    [self.viewingAccount addDerivationPath:derivationPath];
}

- (void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath
{
    if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]] && ![self.viewingAccount.fundDerivationPaths containsObject:(DSFundsDerivationPath*)derivationPath]) {
        [self addStandaloneDerivationPath:derivationPath];
    }
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray addObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}

-(NSArray*)standaloneDerivationPaths {
    return [self.viewingAccount fundDerivationPaths];
}

// MARK: - Voting Keys

//-(NSData*)votingKeyForMasternode:(DSSimplifiedMasternodeEntry*)masternodeEntry {
//    NSError * error = nil;
//    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
//    NSData * votingKey = [keyChainDictionary objectForKey:masternodeEntry.uniqueID];
//    return votingKey;
//}
//
//-(NSArray*)registeredMasternodes {
//    NSError * error = nil;
//    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
//    DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:self];
//    NSMutableArray * registeredMasternodes = [NSMutableArray array];
//    for (NSData * providerRegistrationTransactionHash in keyChainDictionary) {
//        DSSimplifiedMasternodeEntry * masternode = [chainManager.masternodeManager masternodeHavingProviderRegistrationTransactionHash:providerRegistrationTransactionHash];
//        [registeredMasternodes addObject:masternode];
//    }
//    return [registeredMasternodes copy];
//}
//
//-(void)registerVotingKey:(NSData*)votingKey forMasternodeEntry:(DSSimplifiedMasternodeEntry*)masternodeEntry {
//    NSError * error = nil;
//    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.votingKeysKey, &error) mutableCopy];
//    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
//    [keyChainDictionary setObject:votingKey forKey:[NSData dataWithUInt256:masternodeEntry.providerRegistrationTransactionHash]];
//    setKeychainDict([keyChainDictionary copy], self.votingKeysKey, YES);
//    NSManagedObjectContext * context = [DSSimplifiedMasternodeEntryEntity context];
//    [context performBlockAndWait:^{
//        [DSSimplifiedMasternodeEntryEntity setContext:context];
//        DSSimplifiedMasternodeEntryEntity * masternodeEntryEntity = masternodeEntry.simplifiedMasternodeEntryEntity;
//        masternodeEntryEntity.claimed = TRUE;
//        [DSSimplifiedMasternodeEntryEntity saveContext];
//    }];
//}

// MARK: - Probabilistic Filters

- (DSBloomFilter*)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak {
    NSMutableSet * allAddresses = [NSMutableSet set];
    NSMutableSet * allUTXOs = [NSMutableSet set];
    for (DSWallet * wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddresses addObjectsFromArray:[addresses allObjects]];
        [allUTXOs addObjectsFromArray:wallet.unspentOutputs];
        
        //we should also add the blockchain user public keys to the filter
        //[allAddresses addObjectsFromArray:[wallet blockchainIdentityAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerOwnerAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerVotingAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerOperatorAddresses]];
    }
    
    for (DSFundsDerivationPath * derivationPath in self.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddresses addObjectsFromArray:addresses];
    }
    
    
    [self clearOrphans];
    
    DSUTXO o;
    NSData *d;
    NSUInteger i, elemCount = allAddresses.count + allUTXOs.count;
    NSMutableArray *inputs = [NSMutableArray new];
    
    for (DSWallet * wallet in self.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            if (tx.blockHeight != TX_UNCONFIRMED && tx.blockHeight + 100 < self.lastBlockHeight) {
                //DSDLog(@"Not adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
                continue; // the transaction is confirmed for at least 100 blocks, then break
            }
            
            //DSDLog(@"Adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
            
            i = 0;
            
            for (NSValue *hash in tx.inputHashes) {
                [hash getValue:&o.hash];
                o.n = [tx.inputIndexes[i++] unsignedIntValue];
                
                DSTransaction *t = [wallet transactionForHash:o.hash];
                
                if (o.n < t.outputAddresses.count && [wallet containsAddress:t.outputAddresses[o.n]]) {
                    [inputs addObject:dsutxo_data(o)];
                    elemCount++;
                }
            }
        }
    }
    
    DSBloomFilter *filter = [[DSBloomFilter alloc] initWithFalsePositiveRate:falsePositiveRate
                                                             forElementCount:(elemCount < 200 ? 300 : elemCount + 100) tweak:tweak
                                                                       flags:BLOOM_UPDATE_ALL];
    
    for (NSString *addr in allAddresses) {// add addresses to watch for tx receiveing money to the wallet
        NSData *hash = addr.addressToHash160;
        
        if (hash && ! [filter containsData:hash]) [filter insertData:hash];
    }
    
    for (NSValue *utxo in allUTXOs) { // add UTXOs to watch for tx sending money from the wallet
        [utxo getValue:&o];
        d = dsutxo_data(o);
        if (! [filter containsData:d]) [filter insertData:d];
    }
    
    for (d in inputs) { // also add TXOs spent within the last 100 blocks
        if (! [filter containsData:d]) [filter insertData:d];
    }
    return filter;
}

// MARK: - Wallet

-(void)wipeBlockchainIdentitiesPersistedData {
    [[DSBlockchainIdentityEntity context] performBlockAndWait:^{
        NSArray * objects = [DSBlockchainIdentityEntity objectsMatching:@"chain == %@",self.chainEntity];
        [DSBlockchainIdentityEntity deleteObjects:objects];
    }];
}

- (void)wipeBlockchainInfo {
    for (DSWallet * wallet in self.wallets) {
        [wallet wipeBlockchainInfo];
    }
    [self wipeBlockchainIdentitiesPersistedData];
    [self.viewingAccount wipeBlockchainInfo];
    self.bestBlockHeight = 0;
    _blocks = nil;
    _lastBlock = nil;
    [self setLastBlockHeightForRescan];
    [self.chainManager chainWasWiped:self];
}

-(void)wipeMasternodesInContext:(NSManagedObjectContext*)context {
    [DSChainEntity setContext:context];
    [DSSimplifiedMasternodeEntryEntity setContext:context];
    [DSLocalMasternodeEntity setContext:context];
    [DSQuorumEntryEntity setContext:context];
    [DSMasternodeListEntity setContext:context];
    DSChainEntity * chainEntity = self.chainEntity;
    [DSLocalMasternodeEntity deleteAllOnChain:chainEntity];
    [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
    [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
    [DSMasternodeListEntity deleteAllOnChain:chainEntity];
    [self.chainManager.masternodeManager wipeMasternodeInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",self.uniqueID,LAST_SYNCED_MASTERNODE_LIST]];
}

-(void)wipeWalletsAndDerivatives {
    [self unregisterAllWallets];
    [self unregisterAllStandaloneDerivationPaths];
    self.mWallets = [NSMutableArray array];
    self.viewingAccount = nil;
}

-(void)retrieveWallets {
    NSError * error = nil;
    NSArray * walletIdentifiers = getKeychainArray(self.chainWalletsKey, &error);
    if (!error && walletIdentifiers) {
        for (NSString * uniqueID in walletIdentifiers) {
            DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueID forChain:self];
            [self addWallet:wallet];
            
        }
    }
}

-(BOOL)canConstructAFilter {
    return [self hasAStandaloneDerivationPath] || [self hasAWallet];
}

-(BOOL)hasAStandaloneDerivationPath {
    return !![self.viewingAccount.fundDerivationPaths count];
}

-(BOOL)hasAWallet {
    return !![self.mWallets count];
}

-(BOOL)syncsBlockchain { //required for SPV wallets
    return !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_NeedsWalletSyncType);
}

-(void)unregisterAllWallets {
    for (DSWallet * wallet in [self.mWallets copy]) {
        [self unregisterWallet:wallet];
    }
}

-(void)unregisterWallet:(DSWallet*)wallet {
    NSAssert(wallet.chain == self, @"the wallet you are trying to remove is not on this chain");
    [wallet wipeBlockchainInfo];
    [wallet wipeWalletInfo];
    [self.mWallets removeObject:wallet];
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueID];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}

-(void)addWallet:(DSWallet*)wallet {
    [self.mWallets addObject:wallet];
}

- (void)registerWallet:(DSWallet*)wallet
{
    BOOL firstWallet = !self.mWallets.count;
    if ([self.mWallets indexOfObject:wallet] == NSNotFound) {
        [self addWallet:wallet];
    }
    
    if (firstWallet) {
        //this is the first wallet, we should reset the last block height to the most recent checkpoint.
        _lastBlock = nil; //it will lazy load later
    }
    
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    if (![keyChainArray containsObject:wallet.uniqueID]) {
        [keyChainArray addObject:wallet.uniqueID];
        setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
}

-(uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSWallet * wallet in self.wallets) {
        rBalance += wallet.balance;
    }
    for (DSDerivationPath * standaloneDerivationPath in self.standaloneDerivationPaths) {
        rBalance += standaloneDerivationPath.balance;
    }
    return rBalance;
}

-(NSArray*)wallets {
    return [self.mWallets copy];
}

-(void)reloadDerivationPaths {
    for (DSWallet * wallet in self.mWallets) {
        [wallet reloadDerivationPaths];
    }
}

// This is a time interval since 1970
-(NSTimeInterval)earliestWalletCreationTime {
    if (![self.wallets count]) return BIP39_CREATION_TIME;
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    for (DSWallet * wallet in self.wallets) {
        if (timeInterval > wallet.walletCreationTime) {
            timeInterval = wallet.walletCreationTime;
        }
    }
    return timeInterval;
}


-(NSTimeInterval)startSyncFromTime {
    if ([self syncsBlockchain]) {
        return [self earliestWalletCreationTime];
    } else {
        return self.checkpoints.lastObject.timestamp;
    }
}

- (DSCheckpoint* _Nullable)lastCheckpointWithMasternodeList {
    NSSet * set = [self.checkpointsByHeightDictionary keysOfEntriesPassingTest:^BOOL(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        DSCheckpoint * checkpoint = (DSCheckpoint *)obj;
        return (checkpoint.masternodeListName && ![checkpoint.masternodeListName isEqualToString:@""]);
    }];
    NSArray * numbers = [[set allObjects] sortedArrayUsingSelector: @selector(compare:)];
    if (!numbers.count) return nil;
    return self.checkpointsByHeightDictionary[numbers.lastObject];
}

- (DSCheckpoint*)checkpointForBlockHash:(UInt256)blockHash {
    return [self.checkpointsByHashDictionary objectForKey:uint256_data(blockHash)];
}

- (DSCheckpoint*)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [self.checkpointsByHeightDictionary objectForKey:@(blockHeight)];
}

-(NSDictionary*)recentBlocks {
    return [[self blocks] copy];
}

- (NSMutableDictionary *)blocks
{
    if (_blocks.count > 0) {
        if (!_checkpointsByHashDictionary) _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        if (!_checkpointsByHeightDictionary) _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        return _blocks;
    }
    
    [[DSMerkleBlockEntity context] performBlockAndWait:^{
        if (self->_blocks.count > 0) return;
        self->_blocks = [NSMutableDictionary dictionary];
        self.checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        self.checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;
            
            self->_blocks[uint256_obj(checkpointHash)] = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                                       merkleRoot:checkpoint.merkleRoot timestamp:checkpoint.timestamp
                                                                                           target:checkpoint.target nonce:0 totalTransactions:0 hashes:nil
                                                                                            flags:nil height:checkpoint.height chainLock:nil];
            self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
            self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
        }
        self.delegateQueueChainEntity = [self chainEntity];
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastBlocks:LLMQ_KEEP_RECENT_BLOCKS onChain:self.delegateQueueChainEntity]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;
                
                if (b) self->_blocks[uint256_obj(b.blockHash)] = b;
            }
        };
    }];
    
    return _blocks;
}

-(NSMutableDictionary*)checkpointsByHashDictionary {
    if (!_checkpointsByHashDictionary) [self blocks];
    return _checkpointsByHashDictionary;
}

-(NSMutableDictionary*)checkpointsByHeightDictionary {
    if (!_checkpointsByHeightDictionary) [self blocks];
    return _checkpointsByHeightDictionary;
}


// this is used as part of a getblocks or getheaders request
- (NSArray *)blockLocatorArray
{
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSMerkleBlock *b = self.lastBlock;
    uint32_t lastHeight = b.height;
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
    }
    DSCheckpoint * lastCheckpoint;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    [locators addObject:uint256_data(lastCheckpoint.checkpointHash)];
    return locators;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    DSCheckpoint * checkpoint = [self.checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    
    DSMerkleBlock * block = [self.blocks objectForKey:uint256_obj(blockhash)];
    if (block && (block.height != UINT32_MAX)) {
        return block.height;
    }
    
    DSMerkleBlock *b = self.lastBlock;
    
    @synchronized (self.blocks) {
        while (b && b.height > 0) {
            if (uint256_eq(b.blockHash, blockhash)) {
                return b.height;
            }
            UInt256 prevBlock = b.prevBlock;
            NSValue * prevBlockValue = uint256_obj(prevBlock);
            b = self.blocks[prevBlockValue];
        }
    }
    
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (uint256_eq(checkpoint.checkpointHash, blockhash)) {
            return checkpoint.height;
        }
    }
    DSDLog(@"Requesting unknown blockhash %@ (it's probably being added asyncronously)",uint256_reverse_hex(blockhash));
    return UINT32_MAX;
}

- (DSMerkleBlock * _Nullable)blockForBlockHash:(UInt256)blockHash {
    return self.blocks[uint256_obj(blockHash)];
}

-(BOOL)blockHeightChainLocked:(uint32_t)height {
    DSMerkleBlock *b = self.lastBlock;
    NSUInteger count = 0;
    BOOL confirmed = false;
    while (b && b.height > height) {
        b = self.blocks[uint256_obj(b.prevBlock)];
        confirmed |= b.chainLocked;
        count++;
    }
    if (b.height != height) return NO;
    return confirmed;
}

- (DSMerkleBlock *)blockAtHeight:(uint32_t)height {
    DSMerkleBlock *b = self.lastBlock;
    NSUInteger count = 0;
    while (b && b.height > height) {
        b = self.blocks[uint256_obj(b.prevBlock)];
        count++;
    }
    if (b.height != height) return nil;
    return b;
}

- (DSMerkleBlock *)blockFromChainTip:(NSUInteger)blocksAgo {
    DSMerkleBlock *b = self.lastBlock;
    NSUInteger count = 0;
    while (b && b.height > 0 && count < blocksAgo) {
        b = self.blocks[uint256_obj(b.prevBlock)];
        count++;
    }
    return b;
}

- (DSMerkleBlock *)lastBlock
{
    if (! _lastBlock) {
        [DSMerkleBlockEntity.context performBlockAndWait:^{
            NSArray * lastBlocks = [DSMerkleBlockEntity lastBlocks:1 onChain:self.chainEntity];
            DSMerkleBlock * lastBlock = [[lastBlocks firstObject] merkleBlock];
            self->_lastBlock = lastBlock;
            if (lastBlock) {
                DSDLog(@"last block at height %d recovered from db (hash is %@)",lastBlock.height,[NSData dataWithUInt256:lastBlock.blockHash].hexString);
            }
        }];

        if (!_lastBlock) {
            if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
                NSUInteger genesisHeight = [self isDevnetAny]?1:0;
                UInt256 checkpointHash = self.checkpoints[genesisHeight].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
                
            } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
                    if (i == 0 || ![self syncsBlockchain] || (self.checkpoints[i].height <= [[DSOptionsManager sharedInstance] syncFromHeight])) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                        
                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:self.checkpoints[i].merkleRoot timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height chainLock:nil];
                    }
                }
            } else {
                NSTimeInterval startSyncTime = self.startSyncFromTime;
                NSUInteger genesisHeight = [self isDevnetAny]?1:0;
                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= genesisHeight; i--) {
                    if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].timestamp + WEEK_TIME_INTERVAL < startSyncTime)) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                        
                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:self.checkpoints[i].merkleRoot timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height chainLock:nil];
                    }
                }
                if (_lastBlock) {
                    DSDLog(@"last block at height %d chosen from checkpoints (hash is %@)",_lastBlock.height,[NSData dataWithUInt256:_lastBlock.blockHash].hexString);
                }
            }
            
        }
        
        
        
        if (_lastBlock.height > self.estimatedBlockHeight) _bestEstimatedBlockHeight = _lastBlock.height;
    }
    
    return _lastBlock;
}

- (NSString*)chainTip {
    return [NSData dataWithUInt256:self.lastBlock.blockHash].shortHexString;
}

- (uint32_t)lastBlockHeight
{
    return self.lastBlock.height;
}

// seconds since reference date, 00:00:00 01/01/01 GMT
// NOTE: this is only accurate for the last two weeks worth of blocks, other timestamps are estimated from checkpoints
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight
{
    if (blockHeight == TX_UNCONFIRMED) return (self.lastBlock.timestamp) + 2.5*60; //next block
    
    if (blockHeight >= self.lastBlockHeight) { // future block, assume 2.5 minutes per block after last block
        return (self.lastBlock.timestamp) + (blockHeight - self.lastBlockHeight)*2.5*60;
    }
    
    if (_blocks.count > 0) {
        if (blockHeight >= self.lastBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSMerkleBlock *block = self.lastBlock;
            
            while (block && block.height > blockHeight) block = self.blocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp;
        }
    }
    else [[DSMerkleBlockEntity context] performBlock:^{ [self blocks]; }];
    
    uint32_t h = self.lastBlockHeight, t = self.lastBlock.timestamp;
    
    for (long i = self.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpoints[i].height <= blockHeight) {
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp)*
            (blockHeight - self.checkpoints[i].height)/(h - self.checkpoints[i].height);
            return t;
        }
        
        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }
    
    return self.checkpoints[0].timestamp;
}

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) self.bestBlockHeight = height;
    NSMutableArray *updatedTx = [NSMutableArray array];
    if ([txHashes count]) {
        //need to reverify this works
        
        for (DSWallet * wallet in self.wallets) {
            [updatedTx addObjectsFromArray:[wallet setBlockHeight:height andTimestamp:timestamp
                                                      forTxHashes:txHashes]];
        }
    } else {
        for (DSWallet * wallet in self.wallets) {
            [wallet chainUpdatedBlockHeight:height];
        }
    }
    
    [self.chainManager chain:self didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

- (BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer
{
    //DSDLog(@"a block %@",uint256_hex(block.blockHash));
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.txHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSMerkleBlock *prev = self.blocks[prevBlock];
    uint32_t txTime = 0;
    BOOL syncDone = NO;
    
    if (! prev) { // block is an orphan
#if LOG_PREV_BLOCKS_ON_ORPHAN
        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        for (DSMerkleBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            DSDLog(@"printing previous block at height %d : %@",merkleBlock.height,uint256_obj(merkleBlock.blockHash));
        }
#endif
        DSDLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", peer.host, peer.port,
              uint256_reverse_hex(block.blockHash), uint256_reverse_hex(block.prevBlock), block.height, uint256_reverse_hex(self.lastBlock.blockHash), self.lastBlockHeight,[NSDate dateWithTimeIntervalSince1970:block.timestamp]);
        
        [self.chainManager chain:self receivedOrphanBlock:block fromPeer:peer];
        [peer receivedOrphanBlock];
        
        self.orphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return TRUE;
    }
    
    block.height = prev.height + 1;
    txTime = block.timestamp/2 + prev.timestamp/2;
    
    @synchronized (self.blocks) {
        if ((block.height % 1000) == 0) { //free up some memory from time to time
            [self saveBlocks];
            DSMerkleBlock *b = block;
            
            for (uint32_t i = 0; b && i < LLMQ_KEEP_RECENT_BLOCKS; i++) {
                b = self.blocks[uint256_obj(b.prevBlock)];
            }
            NSMutableArray * blocksToRemove = [NSMutableArray array];
            while (b) { // free up some memory
                [blocksToRemove addObject:uint256_obj(b.blockHash)];
                b = self.blocks[uint256_obj(b.prevBlock)];
            }
            [self.blocks removeObjectsForKeys:blocksToRemove];
            //DSDLog(@"%lu blocks remaining",(unsigned long)[self.blocks count]);
        }
    }
    
    // verify block difficulty if block is past last checkpoint
    DSCheckpoint * lastCheckpoint = [self lastCheckpoint];
    
    if (!self.isDevnetAny) {
        if ((block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
            ![block verifyDifficultyWithPreviousBlocks:self.blocks]) {
            uint32_t foundDifficulty = [block darkGravityWaveTargetWithPreviousBlocks:self.blocks];
            DSDLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
                  block.height,block.target,foundDifficulty, blockHash);
            [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            return FALSE;
        }
    }
    
    DSCheckpoint * checkpoint = [self.checkpointsByHeightDictionary objectForKey:@(block.height)];

    // verify block chain checkpoints
    if (checkpoint && ! uint256_eq(block.blockHash, checkpoint.checkpointHash)) {
        DSDLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              peer.host, peer.port, block.height, blockHash, uint256_hex(checkpoint.checkpointHash));
        [self.chainManager chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    if (uint256_eq(block.prevBlock, self.lastBlock.blockHash)) { // new block extends main chain
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            DSDLog(@"adding block on %@ at height: %d from peer %@", self.name, block.height,peer.host);
        }
        @synchronized (self.blocks) {
            self.blocks[blockHash] = block;
        }
        self.lastBlock = block;
        [self setBlockHeight:block.height andTimestamp:txTime forTxHashes:txHashes];
        peer.currentBlockHeight = block.height; //might be download peer instead
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    }
    else if (self.blocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            DSDLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
        }
        
        @synchronized (self.blocks) {
            self.blocks[blockHash] = block;
        }
        
        DSMerkleBlock *b = self.lastBlock;
        
        while (b && b.height > block.height) b = self.blocks[uint256_obj(b.prevBlock)]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:block.height andTimestamp:txTime forTxHashes:txHashes];
            if (block.height == self.lastBlockHeight) self.lastBlock = block;
        }
    }
    else { // new block is on a fork
        if (block.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            DSDLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                  block.height, blockHash);
            return TRUE;
        }
        
        // special case, if a new block is mined while we're rescanning the chain, mark as orphan til we're caught up
        if (self.lastBlockHeight < peer.lastblock && block.height > self.lastBlockHeight + 1) {
            DSDLog(@"marking new block at height %d as orphan until rescan completes", block.height);
            self.orphans[prevBlock] = block;
            self.lastOrphan = block;
            return TRUE;
        }
        
        DSDLog(@"chain fork to height %d", block.height);
        @synchronized (self.blocks) {
            self.blocks[blockHash] = block;
        }
        if (block.height <= self.lastBlockHeight) return TRUE; // if fork is shorter than main chain, ignore it for now
        
        NSMutableArray *txHashes = [NSMutableArray array];
        DSMerkleBlock *b = block, *b2 = self.lastBlock;
        
        while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
            b = self.blocks[uint256_obj(b.prevBlock)];
            if (b.height < b2.height) b2 = self.blocks[uint256_obj(b2.prevBlock)];
        }
        
        DSDLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
        
        // mark transactions after the join point as unconfirmed
        for (DSWallet * wallet in self.wallets) {
            for (DSTransaction *tx in wallet.allTransactions) {
                if (tx.blockHeight <= b.height) break;
                [txHashes addObject:uint256_obj(tx.txHash)];
            }
        }
        
        [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:txHashes];
        b = block;
        
        while (b.height > b2.height) { // set transaction heights for new main chain
            [self setBlockHeight:b.height andTimestamp:txTime forTxHashes:b.txHashes];
            b = self.blocks[uint256_obj(b.prevBlock)];
            txTime = b.timestamp/2 + ((DSMerkleBlock *)self.blocks[uint256_obj(b.prevBlock)]).timestamp/2;
        }
        
        self.lastBlock = block;
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
    }
    
    //DSDLog(@"%@:%d added block at height %d target %x blockHash: %@", peer.host, peer.port,
    //      block.height,block.target, blockHash);
    
    if (checkpoint && checkpoint == [self lastCheckpointWithMasternodeList]) {
        [self.chainManager.masternodeManager loadFileDistributedMasternodeLists];
    }
    
    if (syncDone) { // chain download is complete
        [self saveBlocks];
        [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self fromPeer:peer onMainChain:onMainChain];
    }
    
    if (block.height > self.estimatedBlockHeight) {
        _bestEstimatedBlockHeight = block.height;
        [self saveBlocks];
        [self.chainManager chain:self wasExtendedWithBlock:block fromPeer:peer];
        
        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
    
    // check if the next block was received as an orphan
    if (block == self.lastBlock && self.orphans[blockHash]) {
        DSMerkleBlock *b = self.orphans[blockHash];
        
        [self.orphans removeObjectForKey:blockHash];
        [self addBlock:b fromPeer:peer]; //used to be [self peer:peer relayedBlock:b]; (hopefully this works now)
    }
    return TRUE;
}

- (void)saveBlocks
{
    DSDLog(@"[DSChain] save blocks");
    NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
    DSMerkleBlock *b = self.lastBlock;
    uint32_t startHeight = 0;
    while (b) {
        blocks[[NSData dataWithBytes:b.blockHash.u8 length:sizeof(UInt256)]] = b;
        startHeight = b.height;
        b = self.blocks[uint256_obj(b.prevBlock)];
    }
    
    [[DSMerkleBlockEntity context] performBlock:^{
        if ([[DSOptionsManager sharedInstance] keepHeaders]) {
            //only remove orphan chains
            NSArray<DSMerkleBlockEntity *> * recentOrphans = [DSMerkleBlockEntity objectsMatching:@"(chain == %@) && (height > %u) && !(blockHash in %@) ",self.delegateQueueChainEntity,startHeight,blocks.allKeys];
            if ([recentOrphans count])  DSDLog(@"%lu recent orphans will be removed from disk",(unsigned long)[recentOrphans count]);
            [DSMerkleBlockEntity deleteObjects:recentOrphans];
        } else {
            //remember to not delete blocks needed for quorums
            NSArray<DSMerkleBlockEntity *> * oldBlockHeaders = [DSMerkleBlockEntity objectsMatching:@"(chain == %@) && !(blockHash in %@) && (usedByQuorums.@count == 0) && masternodeList == NIL",self.delegateQueueChainEntity,blocks.allKeys];
            [DSMerkleBlockEntity deleteObjects:oldBlockHeaders];
        }
        
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity objectsMatching:@"blockHash in %@",blocks.allKeys]) {
            @autoreleasepool {
                [e setAttributesFromBlock:blocks[e.blockHash] forChain:self.delegateQueueChainEntity];
                [blocks removeObjectForKey:e.blockHash];
            }
        }
        
        for (DSMerkleBlock *b in blocks.allValues) {
            @autoreleasepool {
                [[DSMerkleBlockEntity managedObject] setAttributesFromBlock:b forChain:self.delegateQueueChainEntity];
            }
        }
        
        [DSMerkleBlockEntity saveContext];
    }];
}

-(void)clearOrphans {
    [self.orphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

-(void)setLastBlockHeightForRescan {
    _lastBlock = nil;
    
    if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
        NSUInteger genesisHeight = [self isDevnetAny]?1:0;
        UInt256 checkpointHash = self.checkpoints[genesisHeight].checkpointHash;
        
        _lastBlock = self.blocks[uint256_obj(checkpointHash)];
    } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
        // start the chain download from the most recent checkpoint that's before the height variable
        for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
            if (i == 0 || (self.checkpoints[i].height <= [[DSOptionsManager sharedInstance] syncFromHeight])) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            }
        }
    } else {
        
        // start the chain download from the most recent checkpoint that's at least a week older than earliestKeyTime
        for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
            if (i == 0 || (self.checkpoints[i].timestamp + WEEK_TIME_INTERVAL < self.startSyncFromTime)) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            }
        }
    }
}

-(uint32_t)estimatedBlockHeight {
    if (_bestEstimatedBlockHeight) return _bestEstimatedBlockHeight;
    uint32_t maxCount = 0;
    uint32_t tempBestEstimatedBlockHeight = 0;
    for (NSNumber * height in self.estimatedBlockHeights) {
        NSArray * announcers = self.estimatedBlockHeights[height];
        if (announcers.count > maxCount) {
            tempBestEstimatedBlockHeight = [height intValue];
        }
    }
    _bestEstimatedBlockHeight = tempBestEstimatedBlockHeight;
    return _bestEstimatedBlockHeight;
}

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer {
    _bestEstimatedBlockHeight = 0; //lazy loading
    
    //remove from other heights
    for (NSNumber * height in [self.estimatedBlockHeights copy]) {
        if ([height intValue] == estimatedBlockHeight) continue;
        NSMutableArray * announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if (![announcers count]) {
            if (self.estimatedBlockHeights[height]) {
                [self.estimatedBlockHeights removeObjectForKey:height];
            }
        }
    }
    if (![self estimatedBlockHeights][@(estimatedBlockHeight)]) {
        [self estimatedBlockHeights][@(estimatedBlockHeight)] = [NSMutableArray arrayWithObject:peer];
    } else {
        NSMutableArray * peersAnnouncingHeight = [self estimatedBlockHeights][@(estimatedBlockHeight)];
        if (![peersAnnouncingHeight containsObject:peer]) {
            [peersAnnouncingHeight addObject:peer];
        }
    }
}

-(void)removeEstimatedBlockHeightOfPeer:(DSPeer*)peer {
    for (NSNumber * height in [self.estimatedBlockHeights copy]) {
        NSMutableArray * announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if (![announcers count]) {
            if (self.estimatedBlockHeights[height]) {
                [self.estimatedBlockHeights removeObjectForKey:height];
            }
        }
        if ([self.estimatedBlockHeights count]) { //keep best estimate if no other peers reporting on estimate
            if ([height intValue] == _bestEstimatedBlockHeight) _bestEstimatedBlockHeight = 0;
        }
    }
}

- (DSTransaction *)transactionForHash:(UInt256)txHash returnWallet:(DSWallet**)rWallet {
    for (DSWallet * wallet in self.wallets) {
        DSTransaction * transaction = [wallet transactionForHash:txHash];
        if (transaction) {
            if (rWallet) *rWallet = wallet;
            return transaction;
        }
    }
    return nil;
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    return [self transactionForHash:txHash returnWallet:nil];
}

- (DSAccount* _Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    if (!transaction) return nil;
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet firstAccountThatCanContainTransaction:transaction];
        if (account) return account;
    }
    return nil;
}

- (NSArray*)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSMutableArray * mArray = [NSMutableArray array];
    if (!transaction) return @[];
    for (DSWallet * wallet in self.wallets) {
        [mArray addObjectsFromArray:[wallet accountsThatCanContainTransaction:transaction]];
    }
    return [mArray copy];
}

- (DSAccount* _Nullable)accountContainingAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet accountForAddress:address];
        if (account) return account;
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction wallet:(DSWallet **)wallet {
    for (DSWallet * lWallet in self.wallets) {
        for (DSAccount * account in lWallet.accounts) {
            DSTransaction * lTransaction = [account transactionForHash:txHash];
            if (lTransaction) {
                if (transaction) *transaction = lTransaction;
                if (wallet) *wallet = lWallet;
                return account;
            }
        }
    }
    return nil;
}

-(uint32_t)blockchainIdentitiesCount {
    uint32_t blockchainIdentitiesCount = 0;
    for (DSWallet * lWallet in self.wallets) {
        blockchainIdentitiesCount += [lWallet blockchainIdentitiesCount];
    }
    return blockchainIdentitiesCount;
}

-(NSArray *) allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSWallet * wallet in self.wallets) {
        [mArray addObjectsFromArray:wallet.allTransactions];
    }
    return mArray;
}

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size
{
    uint64_t standardFee = size*TX_FEE_PER_B; // standard fee based on tx size
        
#if (!!FEE_PER_KB_URL)
        uint64_t fee = ((size*self.feePerByte + 99)/100)*100; // fee using feePerByte, rounded up to nearest 100 satoshi
        return (fee > standardFee) ? fee : standardFee;
#else
        return standardFee;
#endif
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount
{
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT*self.feePerByte + MIN_FEE_PER_B - 1)/MIN_FEE_PER_B;
    
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], _genesisHash));
}

// MARK: - Registering special transactions

-(BOOL)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction {
    DSWallet * ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil];
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil];
    DSWallet * holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil];
    DSAccount * account = [self accountContainingAddress:providerRegistrationTransaction.payoutAddress];
    BOOL registered = NO;
    registered |= [account registerTransaction:providerRegistrationTransaction];
    registered |= [ownerWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    registered |= [votingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    registered |= [operatorWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    registered |= [holdingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    
    if (ownerWallet) {
        DSAuthenticationKeysDerivationPath * ownerDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:ownerWallet];
        [ownerDerivationPath registerTransactionAddress:providerRegistrationTransaction.ownerAddress];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath * votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerRegistrationTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath * operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerRegistrationTransaction.operatorAddress];
    }
    
    if (holdingWallet) {
        DSMasternodeHoldingsDerivationPath * holdingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:holdingWallet];
        [holdingDerivationPath registerTransactionAddress:providerRegistrationTransaction.holdingAddress];
    }
    
    return registered;
}

-(BOOL)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction*)providerUpdateServiceTransaction {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateServiceTransaction];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateServiceTransaction];
    }
    return registered;
}

-(BOOL)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction*)providerUpdateRegistrarTransaction {
    
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateRegistrarTransaction];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath * votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath * operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.operatorAddress];
    }
    return registered;
}

-(BOOL)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction*)providerUpdateRevocationTransaction {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        return [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRevocationTransaction];
    } else {
        return NO;
    }
}
//
//-(BOOL)registerBlockchainIdentityRegistrationTransaction:(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction {
//    DSWallet * blockchainIdentityWallet = [self walletHavingBlockchainIdentityAuthenticationHash:blockchainIdentityRegistrationTransaction.pubkeyHash foundAtIndex:nil];
//    BOOL registered = [blockchainIdentityWallet.specialTransactionsHolder registerTransaction:blockchainIdentityRegistrationTransaction];
//
//    if (blockchainIdentityWallet) {
//        DSAuthenticationKeysDerivationPath * blockchainIdentitiesDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:blockchainIdentityWallet];
//        [blockchainIdentitiesDerivationPath registerTransactionAddress:blockchainIdentityRegistrationTransaction.pubkeyAddress];
//    }
//    return registered;
//}
//
//-(BOOL)registerBlockchainIdentityResetTransaction:(DSBlockchainIdentityUpdateTransition*)blockchainIdentityResetTransaction {
//    DSWallet * blockchainIdentityWallet = [self walletHavingBlockchainIdentityAuthenticationHash:blockchainIdentityResetTransaction.replacementPublicKeyHash foundAtIndex:nil];
//    [blockchainIdentityWallet.specialTransactionsHolder registerTransaction:blockchainIdentityResetTransaction];
//    DSWallet * blockchainIdentityRegistrationWallet = nil;
//    DSTransaction * blockchainIdentityRegistrationTransaction = [self transactionForHash:blockchainIdentityResetTransaction.registrationTransactionHash returnWallet:&blockchainIdentityRegistrationWallet];
//    BOOL registered = NO;
//    if (blockchainIdentityRegistrationTransaction && blockchainIdentityRegistrationWallet && (blockchainIdentityWallet != blockchainIdentityRegistrationWallet)) {
//        registered = [blockchainIdentityRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainIdentityResetTransaction];
//    }
//
//    if (blockchainIdentityWallet) {
//        DSAuthenticationKeysDerivationPath * blockchainIdentitiesDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:blockchainIdentityWallet];
//        [blockchainIdentitiesDerivationPath registerTransactionAddress:blockchainIdentityResetTransaction.replacementAddress];
//    }
//    return registered;
//}
//
//-(BOOL)registerBlockchainIdentityCloseTransaction:(DSBlockchainIdentityCloseTransition*)blockchainIdentityCloseTransaction {
//    DSWallet * blockchainIdentityRegistrationWallet = nil;
//    DSTransaction * blockchainIdentityRegistrationTransaction = [self transactionForHash:blockchainIdentityCloseTransaction.registrationTransactionHash returnWallet:&blockchainIdentityRegistrationWallet];
//    if (blockchainIdentityRegistrationTransaction && blockchainIdentityRegistrationWallet) {
//        return [blockchainIdentityRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainIdentityCloseTransaction];
//    } else {
//        return NO;
//    }
//}
//
//-(BOOL)registerBlockchainIdentityTopupTransaction:(DSBlockchainIdentityTopupTransition*)blockchainIdentityTopupTransaction {
//    DSWallet * blockchainIdentityRegistrationWallet = nil;
//    DSTransaction * blockchainIdentityRegistrationTransaction = [self transactionForHash:blockchainIdentityTopupTransaction.registrationTransactionHash returnWallet:&blockchainIdentityRegistrationWallet];
//    if (blockchainIdentityRegistrationTransaction && blockchainIdentityRegistrationWallet) {
//        return [blockchainIdentityRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainIdentityTopupTransaction];
//    } else {
//        return NO;
//    }
//}
//
//-(BOOL)registerTransition:(DSTransition*)transition {
//    DSWallet * blockchainIdentityRegistrationWallet = nil;
//    DSTransaction * blockchainIdentityRegistrationTransaction = [self transactionForHash:transition.registrationTransactionHash returnWallet:&blockchainIdentityRegistrationWallet];
//    if (blockchainIdentityRegistrationTransaction && blockchainIdentityRegistrationWallet) {
//        return [blockchainIdentityRegistrationWallet.specialTransactionsHolder registerTransaction:transition];
//    } else {
//        return NO;
//    }
//}

-(BOOL)registerSpecialTransaction:(DSTransaction*)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        return [self registerProviderRegistrationTransaction:providerRegistrationTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        return [self registerProviderUpdateServiceTransaction:providerUpdateServiceTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        return [self registerProviderUpdateRegistrarTransaction:providerUpdateRegistrarTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        return [self registerProviderUpdateRevocationTransaction:providerUpdateRevocationTransaction];
    }
//    else if ([transaction isKindOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
//        DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition *)transaction;
//        return [self registerBlockchainIdentityRegistrationTransaction:blockchainIdentityRegistrationTransaction];
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
//        DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = (DSBlockchainIdentityUpdateTransition *)transaction;
//        return [self registerBlockchainIdentityResetTransaction:blockchainIdentityResetTransaction];
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityCloseTransition class]]) {
//        DSBlockchainIdentityCloseTransition * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransition *)transaction;
//        return [self registerBlockchainIdentityCloseTransaction:blockchainIdentityCloseTransaction];
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityTopupTransition class]]) {
//        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransition *)transaction;
//        return [self registerBlockchainIdentityTopupTransaction:blockchainIdentityTopupTransaction];
//    } else if ([transaction isKindOfClass:[DSTransition class]]) {
//        DSTransition * transition = (DSTransition*)transaction;
//        return [self registerTransition:transition];
//    }
    return FALSE;
}

// MARK: - Special Transactions

//Does the chain mat
-(BOOL)transactionHasLocalReferences:(DSTransaction*)transaction {
    if ([self firstAccountThatCanContainTransaction:transaction]) return TRUE;
    
    //PROVIDERS
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil]) return TRUE;
        if ([self accountContainingAddress:providerRegistrationTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        if ([self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        if ([self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        if ([self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash]) return TRUE;
        
        //BLOCKCHAIN USERS
    }
//    else if ([transaction isKindOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
//        DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition *)transaction;
//        if ([self walletHavingBlockchainIdentityAuthenticationHash:blockchainIdentityRegistrationTransaction.pubkeyHash foundAtIndex:nil]) return TRUE;
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
//        DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = (DSBlockchainIdentityUpdateTransition *)transaction;
//        if ([self walletHavingBlockchainIdentityAuthenticationHash:blockchainIdentityResetTransaction.replacementPublicKeyHash foundAtIndex:nil]) return TRUE;
//        if ([self transactionForHash:blockchainIdentityResetTransaction.registrationTransactionHash]) return TRUE;
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityCloseTransition class]]) {
//        DSBlockchainIdentityCloseTransition * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransition *)transaction;
//        if ([self transactionForHash:blockchainIdentityCloseTransaction.registrationTransactionHash]) return TRUE;
//    } else if ([transaction isKindOfClass:[DSBlockchainIdentityTopupTransition class]]) {
//        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransition *)transaction;
//        if ([self transactionForHash:blockchainIdentityTopupTransaction.registrationTransactionHash]) return TRUE;
//    }
    return FALSE;
}

-(void)triggerUpdatesForLocalReferences:(DSTransaction*)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil] || [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil] || [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil]) {
            [self.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:TRUE];
        }
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateServiceTransaction:providerUpdateServiceTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRegistrarTransaction:providerUpdateRegistrarTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRevocationTransaction:providerUpdateRevocationTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSCreditFundingTransaction class]]) {
        DSCreditFundingTransaction * creditFundingTransaction = (DSCreditFundingTransaction *)transaction;
        uint32_t index;
        DSWallet * wallet = [self walletHavingBlockchainIdentityCreditFundingRegistrationHash:creditFundingTransaction.creditBurnPublicKeyHash foundAtIndex:&index];
        if (wallet) {
            DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];
            if (!blockchainIdentity) {
                blockchainIdentity = [[DSBlockchainIdentity alloc] initWithFundingTransaction:creditFundingTransaction withUsernameStatusDictionary:nil inWallet:wallet inContext:self.managedObjectContext];
                [blockchainIdentity registerInWalletForRegistrationFundingTransaction:creditFundingTransaction];
            }
        }
    }
}

-(void)triggerUpdatesForLocalReferencesFromTransition:(DSTransition*)transition {
//    if ([transition isKindOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
//        DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition *)transition;
//        DSWallet * wallet = [self walletHavingBlockchainIdentityAuthenticationHash:blockchainIdentityRegistrationTransition.pubkeyHash foundAtIndex:nil];
//        if (wallet) {
//            DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForRegistrationHash:blockchainIdentityRegistrationTransition.txHash];
//            if (!blockchainIdentity) {
//                blockchainIdentity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityRegistrationTransition:blockchainIdentityRegistrationTransition inContext:self.managedObjectContext];
//                [wallet registerBlockchainIdentity:blockchainIdentity];
//            }
//        }
//    } else if ([transition isKindOfClass:[DSBlockchainIdentityTopupTransition class]]) {
//        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransition *)transition;
//        DSWallet * wallet;
//        [self transactionForHash:blockchainIdentityTopupTransaction.registrationTransactionHash returnWallet:&wallet];
//        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForRegistrationHash:blockchainIdentityTopupTransaction.registrationTransactionHash];
//        [blockchainIdentity updateWithTopupTransition:blockchainIdentityTopupTransaction save:TRUE];
//    } else if ([transition isKindOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
//        DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = (DSBlockchainIdentityUpdateTransition *)transition;
//        DSWallet * wallet;
//        [self transactionForHash:blockchainIdentityResetTransaction.registrationTransactionHash returnWallet:&wallet];
//        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForRegistrationHash:blockchainIdentityResetTransaction.registrationTransactionHash];
//        [blockchainIdentity updateWithUpdateTransition:blockchainIdentityResetTransaction save:TRUE];
//    } else if ([transition isKindOfClass:[DSBlockchainIdentityCloseTransition class]]) {
//        DSBlockchainIdentityCloseTransition * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransition *)transition;
//        DSWallet * wallet;
//        [self transactionForHash:blockchainIdentityCloseTransaction.registrationTransactionHash returnWallet:&wallet];
//        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForRegistrationHash:blockchainIdentityCloseTransaction.registrationTransactionHash];
//        [blockchainIdentity updateWithCloseTransition:blockchainIdentityCloseTransaction save:TRUE];
//    } else if ([transition isKindOfClass:[DSTransition class]]) {
//        DSWallet * wallet;
//        [self transactionForHash:transition.registrationTransactionHash returnWallet:&wallet];
//        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForRegistrationHash:transition.registrationTransactionHash];
//        [blockchainIdentity updateWithTransition:transition save:TRUE];
//    }
}

- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(NSArray*)simplifiedMasternodeEntries {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in simplifiedMasternodeEntries) {
        NSString * votingAddress = simplifiedMasternodeEntry.votingAddress;
        NSString * operatorAddress = simplifiedMasternodeEntry.operatorAddress;
        for (DSWallet * wallet in self.wallets) {
            DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
            if ([providerOperatorKeysDerivationPath containsAddress:operatorAddress]) {
                [providerOperatorKeysDerivationPath registerTransactionAddress:operatorAddress];
            }
            DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
            if ([providerVotingKeysDerivationPath containsAddress:votingAddress]) {
                [providerVotingKeysDerivationPath registerTransactionAddress:votingAddress];
            }
        }
    }
}

// MARK: - Merging Wallets

- (DSWallet*)walletHavingBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainIdentityCreditFundingRegistrationHash:creditFundingRegistrationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet*)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderVotingAuthenticationHash:votingAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOwningAuthenticationHash:owningAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOperatorAuthenticationKey:providerOperatorAuthenticationKey];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction * _Nonnull)transaction foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        for (NSString * outputAddresses in transaction.outputAddresses) {
            NSUInteger index = [wallet indexOfHoldingAddress:outputAddresses];
            if (index != NSNotFound) {
                if (rIndex) *rIndex = (uint32_t)index;
                return wallet;
            }
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

@end

@implementation DSCheckpoint

#pragma mark NSCoding

#define kHeightKey       @"Height"
#define kCheckpointHashKey      @"CheckpointHash"
#define kTimestampKey      @"Timestamp"
#define kTargetKey      @"Target"

+(DSCheckpoint*)genesisDevnetCheckpoint {
    DSCheckpoint * checkpoint = [DSCheckpoint new];
    checkpoint.checkpointHash = *(UInt256 *)[NSString stringWithCString:"000008ca1832a4baf228eb1553c03d3a2c8e02399550dd6ea8d65cec3ef23d2e" encoding:NSUTF8StringEncoding].hexToData.reverse.bytes;
    checkpoint.height = 0;
    checkpoint.timestamp = 1417713337;
    checkpoint.target = 0x207fffffu;
    return checkpoint;
}

-(instancetype)initWithHash:(UInt256)checkpointHash height:(uint32_t)height timestamp:(uint32_t)timestamp target:(uint32_t)target {
    if (! (self = [super init])) return nil;
    
    self.checkpointHash = checkpointHash;
    self.height = height;
    self.timestamp = timestamp;
    self.target = target;
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    UInt256 checkpointHash = [decoder decodeUInt256ForKey:kCheckpointHashKey];
    uint32_t height = [decoder decodeInt32ForKey:kHeightKey];
    uint32_t timestamp = [decoder decodeInt32ForKey:kTimestampKey];
    uint32_t target = [decoder decodeInt32ForKey:kTargetKey];
    return [self initWithHash:checkpointHash height:height timestamp:timestamp target:target];
}

-(DSMerkleBlock*)merkleBlockForChain:(DSChain*)chain {
    return [[DSMerkleBlock alloc] initWithBlockHash:self.checkpointHash onChain:chain version:1 prevBlock:UINT256_ZERO
                                  merkleRoot:self.merkleRoot timestamp:self.timestamp
                                      target:self.target nonce:0 totalTransactions:0 hashes:nil
                                       flags:nil height:self.height chainLock:nil];
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeUInt256:self.checkpointHash forKey:kCheckpointHashKey];
    [aCoder encodeInt32:self.height forKey:kHeightKey];
    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
    [aCoder encodeInt32:self.target forKey:kTargetKey];
}

@end
