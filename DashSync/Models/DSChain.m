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
#import "DSWalletManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "DSChainPeerManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSCoder+Dash.h"
#import "DSDerivationPath.h"

typedef const struct checkpoint { uint32_t height; const char *checkpointHash; uint32_t timestamp; uint32_t target; } checkpoint;

static checkpoint testnet_checkpoint_array[] = {
    {           0, "00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c", 1390666206, 0x1e0ffff0u },
    {        2999, "0000024bc3f4f4cb30d29827c13d921ad77d2c6072e586c7f60d83c2722cdcc5", 1462856598, 0x1e03ffffu }
};

// blockchain checkpoints - these are also used as starting points for partial chain downloads, so they need to be at
// difficulty transition boundaries in order to verify the block difficulty at the immediately following transition
static checkpoint mainnet_checkpoint_array[] = {
    {      0, "00000ffd590b1485b3caadc19b22e6379c733355108f107a430458cdf3407ab6", 1390095618, 0x1e0ffff0u },//dash
    {   1500, "000000aaf0300f59f49bc3e970bad15c11f961fe2347accffff19d96ec9778e3", 1390109863, 0x1e00ffffu },//dash
    {   4991, "000000003b01809551952460744d5dbb8fcbd6cbae3c220267bf7fa43f837367", 1390271049, 0x1c426980u },//dash
    {   9918, "00000000213e229f332c0ffbe34defdaa9e74de87f2d8d1f01af8d121c3c170b", 1391392449, 0x1c41cc20u },//dash
    {  16912, "00000000075c0d10371d55a60634da70f197548dbbfa4123e12abfcbc5738af9", 1392328997, 0x1c07cc3bu },//dash
    {  23912, "0000000000335eac6703f3b1732ec8b2f89c3ba3a7889e5767b090556bb9a276", 1393373461, 0x1c0177efu },//dash
    {  35457, "0000000000b0ae211be59b048df14820475ad0dd53b9ff83b010f71a77342d9f", 1395110315, 0x1c00da53u },//dash
    {  45479, "000000000063d411655d590590e16960f15ceea4257122ac430c6fbe39fbf02d", 1396620889, 0x1c009c80u },//dash
    {  55895, "0000000000ae4c53a43639a4ca027282f69da9c67ba951768a20415b6439a2d7", 1398190161, 0x1c00bae3u },//dash
    {  68899, "0000000000194ab4d3d9eeb1f2f792f21bb39ff767cb547fe977640f969d77b7", 1400148293, 0x1b25df16u },//dash
    {  74619, "000000000011d28f38f05d01650a502cc3f4d0e793fbc26e2a2ca71f07dc3842", 1401048723, 0x1b1905e3u },//dash
    {  75095, "0000000000193d12f6ad352a9996ee58ef8bdc4946818a5fec5ce99c11b87f0d", 1401126238, 0x1b2587e3u },//dash
    {  88805, "00000000001392f1652e9bf45cd8bc79dc60fe935277cd11538565b4a94fa85f", 1403283082, 0x1b194dfbu },//dash
    { 107996, "00000000000a23840ac16115407488267aa3da2b9bc843e301185b7d17e4dc40", 1406300692, 0x1b11c217u },//dash
    { 137993, "00000000000cf69ce152b1bffdeddc59188d7a80879210d6e5c9503011929c3c", 1411014812, 0x1b1142abu },//dash
    { 167996, "000000000009486020a80f7f2cc065342b0c2fb59af5e090cd813dba68ab0fed", 1415730882, 0x1b112d94u },//dash
    { 207992, "00000000000d85c22be098f74576ef00b7aa00c05777e966aff68a270f1e01a5", 1422026638, 0x1b113c01u },//dash
    { 217752, "00000000000a7baeb2148272a7e14edf5af99a64af456c0afc23d15a0918b704", 1423563332, 0x1b10c9b6u },//dash
    { 227121, "00000000000455a2b3a2ed5dfb03990043ca0074568b939acec62820e89a6c45", 1425039295, 0x1b1261d6u },//dash
    { 246209, "00000000000eec6f7871d3d70321ae98ef1007ab0812d876bda1208afcfb7d7d", 1428046505, 0x1b1a5e27u },//dash
    { 298549, "00000000000cc467fbfcfd49b82e4f9dc8afb0ef83be7c638f573be6a852ba56", 1436306353, 0x1b1ff0dbu },//dash
    { 312645, "0000000000059dcb71ad35a9e40526c44e7aae6c99169a9e7017b7d84b1c2daf", 1438525019, 0x1b1c46ceu },//dash
    { 340000, "000000000014f4e32be2038272cc074a75467c342e25bfe0b566fabe927240b4", 1442833344, 0x1b1acd73u },
    { 360000, "0000000000136c1c34bfeb783103c77331930768e864aaf91859b302558d292c", 1445983058, 0x1b21ec4eu },
    { 380000, "00000000000a5ab368be389a048caac7435d7244960e69adaa53eb0b94f8b3c3", 1442833344, 0x1b16c480u },
    { 400000, "00000000000132b9afeca5e9a2fdf4477338df6dcff1342300240bc70397c4bb", 1452288263, 0x1b0d642eu },
    { 420000, "000000000006bd43eeab52946f5f47517441ac2339568401468ed6079b83c38e", 1455442477, 0x1b0eda3au },
    { 440000, "000000000005aca0dc68800e5cd701f4f3bf53e8e0c85d25f03d21a372e23f17", 1458594501, 0x1b124590u },
    { 460000, "00000000000eab034824bb5284946b36d8890d7c9f657048d3c7d1f405b1a36c", 1461747567, 0x1b14a0c0u },
    { 480000, "0000000000032ddb3552f63d2c641af5e4e2ca3c25bdcee85c1453876356ff81", 1464893443, 0x1b091760u },
    { 500000, "000000000002be1cff717f4aa6efc504fa06dc9c453c83773de0b712b8690b7d", 1468042975, 0x1b06a6cfu },
    { 520000, "000000000002dbfe2d15094c45b9bdf2c511e491af72aeadcb935a926389f468", 1471190891, 0x1b02e8bdu },
    { 540000, "000000000000daaac22af98ed775d153878c343e019155ed34c46110a12bd112", 1474340382, 0x1b01a7e0u },
    { 560000, "000000000000b7c1e52ebc9858305793af9554e67399e8d5c6839915b3e91214", 1477493476, 0x1b01da33u },
    { 580000, "000000000001636ac338ed16dc9fc06aeed60b595e647e014c89a2f0724e3086", 1480643973, 0x1b0184aeu },
    { 600000, "000000000000a0b730b5be60e65b4a730d1fdcf1d023c9e42c0e5bf4a059f709", 1483795508, 0x1b00db54u },
    { 620000, "0000000000002e7f2ab6cefe6f63b34c821e7f2f8aa5525c6409dc57677044b4", 1486948317, 0x1b0100c5u },
    { 640000, "00000000000079dfa97353fd50a420a4425b5e96b1699927da5e89cbabe730bf", 1490098758, 0x1b009c90u },
    { 660000, "000000000000124a71b04fa91cc37e510fabd66f2286491104ecf54f96148275", 1493250273, 0x1a710fe7u },
    { 680000, "00000000000012b333e5ba8a85895bcafa8ad3674c2fb8b2de98bf3a5f08fa81", 1496400309, 0x1a64bc7au },
    { 700000, "00000000000002958852d255726d695ecccfbfacfac318a9d0ebc558eecefeb9", 1499552504, 0x1a37e005u },
    { 720000, "0000000000000acfc49b67e8e72c6faa2d057720d13b9052161305654b39b281", 1502702260, 0x1a158e98u },
    { 740000, "00000000000008d0d8a9054072b0272024a01d1920ab4d5a5eb98584930cbd4c", 1505852282, 0x1a0ab756u },
    { 760000, "000000000000011131c4a8c6446e6ce4597a192296ecad0fb47a23ae4b506682", 1508998683, 0x1a014ed1u }
};

@interface DSChain ()

@property (nonatomic, strong) DSWallet * wallet;
@property (nonatomic, strong) DSMerkleBlock *lastBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary *blocks, *orphans,*checkpointsDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, assign) NSTimeInterval earliestKeyTime;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, copy) NSString * networkName;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

- (instancetype)initWithType:(DSChainType)type checkpoints:(NSArray*)checkpoints port:(uint32_t)port
{
    if (! (self = [super init])) return nil;
    
    _chainType = type;
    self.earliestKeyTime = [DSWalletManager sharedInstance].seedCreationTime;
    self.orphans = [NSMutableDictionary dictionary];
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.standardPort = port;
    [self chainEntity];
    return self;
}

+(NSMutableArray*)createCheckpointsArrayFromCheckpoints:(checkpoint*)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray * checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i <checkpointCount;i++) {
        DSCheckpoint * check = [DSCheckpoint new];
        check.height = checkpoints[i].height;
        check.checkpointHash = *(UInt256 *)[NSString stringWithCString:checkpoints[i].checkpointHash encoding:NSUTF8StringEncoding].hexToData.reverse.bytes;
        check.target = checkpoints[i].target;
        check.timestamp = checkpoints[i].timestamp;
        [checkpointMutableArray addObject:check];
    }
    return [checkpointMutableArray copy];
}

-(DSChainEntity*)chainEntity {
    __block DSChainEntity* chainEntity = nil;
    [[DSChainEntity context] performBlockAndWait:^{
        chainEntity = [DSChainEntity chainEntityForType:self.chainType genesisBlock:self.genesisHash checkpoints:self.checkpoints];
    }];
    return chainEntity;
}

+(DSChain*)mainnet {
    static DSChain* _mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:DSChainType_MainNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array)/sizeof(*mainnet_checkpoint_array))] port:MAINNET_STANDARD_PORT];
    });
    return _mainnet;
}

+(DSChain*)testnet {
    static DSChain* _testnet = nil;
    static dispatch_once_t testnetToken = 0;
    
    dispatch_once(&testnetToken, ^{
        _testnet = [[DSChain alloc] initWithType:DSChainType_TestNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array)/sizeof(*testnet_checkpoint_array))] port:TESTNET_STANDARD_PORT];
    });
    return _testnet;
}

static NSMutableDictionary * _devnetDictionary = nil;
static dispatch_once_t devnetToken = 0;

+(DSChain*)devnetWithGenesisHash:(UInt256)genesisHash {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(genesisHash);
    DSChain * devnetChain = nil;
    @synchronized(self) {
        devnetChain = [_devnetDictionary objectForKey:genesisValue];
    }
    return devnetChain;
}

+(DSChain*)setUpDevnetWithGenesisHash:(UInt256)genesisHash andCheckpoints:(NSArray*)checkpointArray onPort:(uint32_t)port {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(genesisHash);
    DSChain * devnetChain = nil;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:genesisValue]) {
            devnetChain = [[DSChain alloc] initWithType:DSChainType_DevNet checkpoints:checkpointArray port:port];
            [_devnetDictionary setObject:devnetChain forKey:genesisValue];
        } else {
            devnetChain = [_devnetDictionary objectForKey:genesisValue];
        }
    }
    return devnetChain;
}

+(DSChain*)createDevnetWithCheckpoints:(NSArray*)checkpointArray onPort:(uint32_t)port {
    NSData * checkpointData = [NSKeyedArchiver archivedDataWithRootObject:checkpointArray];
    DSChainEntity * chainEntity = [DSChainEntity managedObject];
    chainEntity.checkpoints = checkpointData;
    chainEntity.genesisBlockHash = [[checkpointArray firstObject] objectForKey:@"checkpointHash"];
    chainEntity.standardPort = port;
    chainEntity.type = DSChainType_DevNet;
    NSError * error = nil;
    [chainEntity.managedObjectContext save:&error];
    if (error) {
        return nil;
    } else {
        return [chainEntity chain];
    }
}

+(DSChain*)chainForNetworkName:(NSString*)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    return @[[DSDerivationPath bip32DerivationPathForAccountNumber:accountNumber],[DSDerivationPath bip44DerivationPathForChainType:self.chainType forAccountNumber:accountNumber]];
}

// MARK: - Check Type

-(BOOL)isMainnet {
    return [self chainType] == DSChainType_MainNet;
}
-(BOOL)isTestnet {
    return [self chainType] == DSChainType_TestNet;
}

-(BOOL)isDevnetAny {
    return [self chainType] == DSChainType_DevNet;
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

// MARK: - Info

-(void)removeWallet {
    _wallet = nil;
}

-(BOOL)hasWalletSet {
    return !!_wallet;
}

-(DSWallet*)wallet {
    if (_wallet) return _wallet;
    self.wallet = [[DSWalletManager sharedInstance] createWalletForChain:self];
    return _wallet;
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

-(DSCheckpoint*)lastCheckpoint {
    return [[self checkpoints] lastObject];
}

#define GENESIS_BLOCK_HASH


- (NSMutableDictionary *)blocks
{
    if (_blocks.count > 0) return _blocks;
    
    [[DSMerkleBlockEntity context] performBlockAndWait:^{
        if (_blocks.count > 0) return;
        _blocks = [NSMutableDictionary dictionary];
        self.checkpointsDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;
            
            _blocks[uint256_obj(checkpointHash)] = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                       merkleRoot:UINT256_ZERO timestamp:checkpoint.timestamp
                                                                           target:checkpoint.target nonce:0 totalTransactions:0 hashes:nil
                                                                            flags:nil height:checkpoint.height];
            self.checkpointsDictionary[@(checkpoint.height)] = uint256_obj(checkpointHash);
        }
        
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity allObjects]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;
                
                if (b) _blocks[uint256_obj(b.blockHash)] = b;
            }
        };
    }];
    
    return _blocks;
}

-(BOOL)isActive {
    return false;
}

// this is used as part of a getblocks or getheaders request
- (NSArray *)blockLocatorArray
{
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSMerkleBlock *b = self.lastBlock;
    
    while (b && b.height > 0) {
        [locators addObject:uint256_obj(b.blockHash)];
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
    }
    
    [locators addObject:uint256_obj([self genesisHash])];
    return locators;
}

- (DSMerkleBlock *)lastBlock
{
    if (! _lastBlock) {
        NSFetchRequest *req = [DSMerkleBlockEntity fetchReq];
        
        req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:NO]];
        req.predicate = [NSPredicate predicateWithFormat:@"height >= 0 && height != %d", BLOCK_UNKNOWN_HEIGHT];
        req.fetchLimit = 1;
        _lastBlock = [[DSMerkleBlockEntity fetchObjects:req].lastObject merkleBlock];
        // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
        for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
            if (i == 0 || self.checkpoints[i].timestamp + 7*24*60*60 < self.earliestKeyTime + NSTimeIntervalSince1970) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                
                _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                           merkleRoot:UINT256_ZERO timestamp:self.checkpoints[i].timestamp
                                                               target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                               height:self.checkpoints[i].height];
            }
        }
        
        if (_lastBlock.height > _estimatedBlockHeight) _estimatedBlockHeight = _lastBlock.height;
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
    if (blockHeight == TX_UNCONFIRMED) return (self.lastBlock.timestamp - NSTimeIntervalSince1970) + 10*60; //next block
    
    if (blockHeight >= self.lastBlockHeight) { // future block, assume 10 minutes per block after last block
        return (self.lastBlock.timestamp - NSTimeIntervalSince1970) + (blockHeight - self.lastBlockHeight)*10*60;
    }
    
    if (_blocks.count > 0) {
        if (blockHeight >= self.lastBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSMerkleBlock *block = self.lastBlock;
            
            while (block && block.height > blockHeight) block = self.blocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp - NSTimeIntervalSince1970;
        }
    }
    else [[DSMerkleBlockEntity context] performBlock:^{ [self blocks]; }];
    
    uint32_t h = self.lastBlockHeight, t = self.lastBlock.timestamp;

    for (long i = self.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpoints[i].height <= blockHeight) {
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp)*
            (blockHeight - self.checkpoints[i].height)/(h - self.checkpoints[i].height);
            return t - NSTimeIntervalSince1970;
        }
        
        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }
    
    return self.checkpoints[0].timestamp - NSTimeIntervalSince1970;
}

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    NSArray *updatedTx = [self.wallet setBlockHeight:height andTimestamp:timestamp
                                                                     forTxHashes:txHashes];
    
    [self.peerManagerDelegate chain:self didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

- (BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer
{
    NSArray *txHashes = block.txHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSMerkleBlock *prev = self.blocks[prevBlock];
    uint32_t transitionTime = 0, txTime = 0;
    UInt256 checkpoint = UINT256_ZERO;
    BOOL syncDone = NO;
    
    if (! prev) { // block is an orphan
        //        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        //        for (DSMerkleBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
        //            NSLog(@"printing previous block at height %d : %@",merkleBlock.height,uint256_obj(merkleBlock.blockHash));
        //        }
        NSLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, height %d", peer.host, peer.port,
              blockHash, prevBlock, block.height, uint256_obj(self.lastBlock.blockHash), self.lastBlockHeight);
        
        [self.peerManagerDelegate chain:self receivedOrphanBlock:block fromPeer:peer];
        
        self.orphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return TRUE;
    }
    
    block.height = prev.height + 1;
    txTime = block.timestamp/2 + prev.timestamp/2;
    
    if ((block.height % 1000) == 0) { //free up some memory from time to time
        
        DSMerkleBlock *b = block;
        
        for (uint32_t i = 0; b && i < (DGW_PAST_BLOCKS_MAX + 50); i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
        
        while (b) { // free up some memory
            b = self.blocks[uint256_obj(b.prevBlock)];
            if (b) [self.blocks removeObjectForKey:uint256_obj(b.prevBlock)];
        }
    }
    
    // verify block difficulty if block is past last checkpoint
    if ((block.height > ([self lastCheckpoint].height + DGW_PAST_BLOCKS_MAX)) &&
        ![block verifyDifficultyWithPreviousBlocks:self.blocks]) {
        uint32_t foundDifficulty = [block darkGravityWaveTargetWithPreviousBlocks:self.blocks];
        NSLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
              block.height,block.target,foundDifficulty, blockHash);
        [self.peerManagerDelegate chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }
    
    [self.checkpointsDictionary[@(block.height)] getValue:&checkpoint ];
    
    // verify block chain checkpoints
    if (! uint256_is_zero(checkpoint) && ! uint256_eq(block.blockHash, checkpoint)) {
        NSLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              peer.host, peer.port, block.height, blockHash, self.checkpointsDictionary[@(block.height)]);
        [self.peerManagerDelegate chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    if (uint256_eq(block.prevBlock, self.lastBlock.blockHash)) { // new block extends main chain
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            NSLog(@"adding block at height: %d", block.height);
        }
        
        self.blocks[blockHash] = block;
        self.lastBlock = block;
        [self setBlockHeight:block.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:txHashes];
        peer.currentBlockHeight = block.height; //might be download peer instead
        if (block.height == _estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    }
    else if (self.blocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            NSLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
        }
        
        self.blocks[blockHash] = block;
        
        DSMerkleBlock *b = self.lastBlock;
        
        while (b && b.height > block.height) b = self.blocks[uint256_obj(b.prevBlock)]; // is block in main chain?
        
        if (uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:block.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:txHashes];
            if (block.height == self.lastBlockHeight) self.lastBlock = block;
        }
    }
    else { // new block is on a fork
        if (block.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            NSLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                  block.height, blockHash);
            return TRUE;
        }
        
        // special case, if a new block is mined while we're rescanning the chain, mark as orphan til we're caught up
        if (self.lastBlockHeight < peer.lastblock && block.height > self.lastBlockHeight + 1) {
            NSLog(@"marking new block at height %d as orphan until rescan completes", block.height);
            self.orphans[prevBlock] = block;
            self.lastOrphan = block;
            return TRUE;
        }
        
        NSLog(@"chain fork to height %d", block.height);
        self.blocks[blockHash] = block;
        if (block.height <= self.lastBlockHeight) return TRUE; // if fork is shorter than main chain, ignore it for now
        
        NSMutableArray *txHashes = [NSMutableArray array];
        DSMerkleBlock *b = block, *b2 = self.lastBlock;
        
        while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
            b = self.blocks[uint256_obj(b.prevBlock)];
            if (b.height < b2.height) b2 = self.blocks[uint256_obj(b2.prevBlock)];
        }
        
        NSLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
        
        // mark transactions after the join point as unconfirmed
        for (DSTransaction *tx in self.wallet.allTransactions) {
            if (tx.blockHeight <= b.height) break;
            [txHashes addObject:uint256_obj(tx.txHash)];
        }
        
        [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:txHashes];
        b = block;
        
        while (b.height > b2.height) { // set transaction heights for new main chain
            [self setBlockHeight:b.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:b.txHashes];
            b = self.blocks[uint256_obj(b.prevBlock)];
            txTime = b.timestamp/2 + ((DSMerkleBlock *)self.blocks[uint256_obj(b.prevBlock)]).timestamp/2;
        }
        
        self.lastBlock = block;
        if (block.height == _estimatedBlockHeight) syncDone = YES;
    }
    
    //NSLog(@"%@:%d added block at height %d target %x blockHash: %@", peer.host, peer.port,
    //      block.height,block.target, blockHash);
    
    if (syncDone) { // chain download is complete
        [self saveBlocks];
        [self.peerManagerDelegate chainFinishedSyncing:self fromPeer:peer onMainChain:onMainChain];
    }
    
    if (block.height > _estimatedBlockHeight) {
        _estimatedBlockHeight = block.height;
        
        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
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
    NSLog(@"[DSChain] save blocks");
    NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
    DSMerkleBlock *b = self.lastBlock;
    
    while (b) {
        blocks[[NSData dataWithBytes:b.blockHash.u8 length:sizeof(UInt256)]] = b;
        b = self.blocks[uint256_obj(b.prevBlock)];
    }
    
    [[DSMerkleBlockEntity context] performBlock:^{
        [DSMerkleBlockEntity deleteObjects:[DSMerkleBlockEntity objectsMatching:@"! (blockHash in %@)",
                                            blocks.allKeys]];
        
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity objectsMatching:@"blockHash in %@", blocks.allKeys]) {
            @autoreleasepool {
                [e setAttributesFromBlock:blocks[e.blockHash]];
                [blocks removeObjectForKey:e.blockHash];
            }
        }
        
        for (DSMerkleBlock *b in blocks.allValues) {
            @autoreleasepool {
                [[DSMerkleBlockEntity managedObject] setAttributesFromBlock:b];
            }
        }
        
        [DSMerkleBlockEntity saveContext];
    }];
}

-(void)wipeChain {
    self.earliestKeyTime = [DSWalletManager sharedInstance].seedCreationTime;
    [DSMerkleBlockEntity deleteAllObjects];
    [DSMerkleBlockEntity saveContext];
    _blocks = nil;
    _lastBlock = nil;
    [self.peerManagerDelegate chainWasWiped:self];
}

-(void)clearOrphans {
    [self.orphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

-(void)setLastBlockHeightForRescan {
    _lastBlock = nil;
    // start the chain download from the most recent checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
        if (i == 0 || self.checkpoints[i].timestamp + 7*24*60*60 < self.earliestKeyTime + NSTimeIntervalSince1970) {
            UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
            
            _lastBlock = self.blocks[uint256_obj(checkpointHash)];
        }
    }
}

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer {
    _estimatedBlockHeight = estimatedBlockHeight;
}

@end

@implementation DSCheckpoint

#pragma mark NSCoding

#define kHeightKey       @"Height"
#define kCheckpointHashKey      @"CheckpointHash"
#define kTimestampKey      @"Timestamp"
#define kTargetKey      @"Target"

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

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeUInt256:self.checkpointHash forKey:kCheckpointHashKey];
    [aCoder encodeInt32:self.height forKey:kHeightKey];
    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
    [aCoder encodeInt32:self.target forKey:kTargetKey];
}



@end
