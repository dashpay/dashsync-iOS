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

#import "DSChain+Protected.h"
#import "DSPeer.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSEventManager.h"
#import "DSBloomFilter.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSBlock+Protected.h"
#import "DSMerkleBlock.h"
#import "DSFullBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSPriceManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSWallet+Protected.h"
#import "DSPeerManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSCoder+Dash.h"
#import "DSAccount.h"
#import "DSBIP39Mnemonic.h"
#import "DSDerivationPath.h"
#import "DSOptionsManager.h"
#import "DSChainsManager.h"
#import "DSMasternodeManager+Protected.h"
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
#import "DSBlockchainIdentity+Protected.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "BigIntTypes.h"
#import "DSChainCheckpoints.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSCheckpoint.h"

#define FEE_PER_BYTE_KEY          @"FEE_PER_BYTE"

#define CHAIN_WALLETS_KEY  @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY  @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY  @"REGISTERED_PEERS_KEY"

#define PROTOCOL_VERSION_LOCATION  @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION  @"MIN_PROTOCOL_VERSION_LOCATION"

#define STANDARD_PORT_LOCATION  @"STANDARD_PORT_LOCATION"
#define JRPC_PORT_LOCATION  @"JRPC_PORT_LOCATION"
#define GRPC_PORT_LOCATION  @"GRPC_PORT_LOCATION"

#define DPNS_CONTRACT_ID  @"DPNS_CONTRACT_ID"
#define DASHPAY_CONTRACT_ID  @"DASHPAY_CONTRACT_ID"

#define MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY  @"MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY"

#define SPORK_PUBLIC_KEY_LOCATION  @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION  @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION  @"SPORK_PRIVATE_KEY_LOCATION"

#define CHAIN_VOTING_KEYS_KEY  @"CHAIN_VOTING_KEYS_KEY"

#define LOG_PREV_BLOCKS_ON_ORPHAN 0

#define BLOCK_NO_FORK_DEPTH 25

@interface DSChain ()

@property (nonatomic, strong) DSBlock *lastSyncBlock, *lastTerminalBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary <NSValue*, DSBlock*> *mSyncBlocks, *mTerminalBlocks, *mOrphans;
@property (nonatomic, strong) NSMutableDictionary <NSData*, DSCheckpoint*> *checkpointsByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary <NSNumber*, DSCheckpoint*> *checkpointsByHeightDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, copy) NSString * networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> * mWallets;
@property (nonatomic, strong) NSString * devnetIdentifier;
@property (nonatomic, strong) DSAccount * viewingAccount;
@property (nonatomic, strong) NSMutableDictionary * estimatedBlockHeights;
@property (nonatomic, assign) uint32_t cachedMinimumDifficultyBlocks;
@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;
//@property (nonatomic, assign) uint32_t headersMaxAmount;
@property (nonatomic, assign) uint32_t cachedMinProtocolVersion;
@property (nonatomic, assign) uint32_t cachedProtocolVersion;
@property (nonatomic, assign) UInt256 cachedMaxProofOfWork;
@property (nonatomic, assign) uint32_t cachedStandardPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiJRPCPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiGRPCPort;
@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, assign) UInt256 cachedDpnsContractID;
@property (nonatomic, assign) UInt256 cachedDashpayContractID;
@property (nonatomic, strong) NSMutableDictionary <NSData*,NSNumber*>* transactionHashHeights;
@property (nonatomic, strong) NSMutableDictionary <NSData*,NSNumber*>* transactionHashTimestamps;
@property (nonatomic, strong) NSManagedObjectContext * chainManagedObjectContext;
@property (nonatomic, strong) DSCheckpoint * terminalHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint * syncHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint * lastCheckpoint;
@property (nonatomic, assign) NSTimeInterval lastNotifiedBlockDidChange;
@property (nonatomic, assign, getter=isTransient) BOOL transient;

@property (nonatomic, readonly) NSString * chainWalletsKey;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

-(instancetype)init {
    if (! (self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.mOrphans = [NSMutableDictionary dictionary];
    self.mWallets = [NSMutableArray array];
    self.estimatedBlockHeights = [NSMutableDictionary dictionary];
    
    self.transactionHashHeights = [NSMutableDictionary dictionary];
    self.transactionHashTimestamps = [NSMutableDictionary dictionary];
    
    self.lastNotifiedBlockDidChange = 0;
    
    if (self.checkpoints) {
        self.genesisHash = self.checkpoints[0].checkpointHash;
        dispatch_sync(self.networkingQueue, ^{
            self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
        });
    }
    
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
            self.headersMaxAmount = MAINNET_DEFAULT_HEADERS_MAX_AMOUNT;
            break;
        }
        case DSChainType_TestNet: {
            self.standardPort = TESTNET_STANDARD_PORT;
            self.standardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
            self.headersMaxAmount = TESTNET_DEFAULT_HEADERS_MAX_AMOUNT;
            break;
        }
        case DSChainType_DevNet: {
            NSAssert(NO, @"DevNet should be configured with initAsDevnetWithIdentifier:checkpoints:port:dapiPort:dapiGRPCPort:dpnsContractID:dashpayContractID:");
            break;
        }
    }
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].checkpointHash;
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
    
    return self;
}

-(instancetype)initAsDevnetWithIdentifier:(NSString*)identifier checkpoints:(NSArray<DSCheckpoint*>*)checkpoints
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
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.checkpoints[0].checkpointHash]);
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.genesisHash]);
    self.devnetIdentifier = identifier;
    self.headersMaxAmount = DEVNET_DEFAULT_HEADERS_MAX_AMOUNT;
    return self;
}

-(instancetype)initAsDevnetWithIdentifier:(NSString*)identifier checkpoints:(NSArray<DSCheckpoint*>*)checkpoints minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks port:(uint32_t)port dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID isTransient:(BOOL)isTransient
{
    //for devnet the genesis checkpoint is really the second block
    if (! (self = [self initAsDevnetWithIdentifier:identifier checkpoints:checkpoints])) return nil;
    self.standardPort = port;
    self.standardDapiJRPCPort = dapiJRPCPort;
    self.standardDapiGRPCPort = dapiGRPCPort;
    self.dpnsContractID = dpnsContractID;
    self.dashpayContractID = dashpayContractID;
    self.minimumDifficultyBlocks = minimumDifficultyBlocks;
    self.transient = isTransient;
    return self;
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
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_mainnet chainEntityInContext:[NSManagedObjectContext chainContext]];
            _mainnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _mainnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            _mainnet.lastPersistedChainSyncLocators = [NSKeyedUnarchiver unarchiveObjectWithData:chainEntity.syncLocators];
            _mainnet.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            _mainnet.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            _mainnet.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
        }];
        [_mainnet setUp];
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
        
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_testnet chainEntityInContext:[NSManagedObjectContext chainContext]];
            _testnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _testnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            _testnet.lastPersistedChainSyncLocators = [NSKeyedUnarchiver unarchiveObjectWithData:chainEntity.syncLocators];
            _testnet.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            _testnet.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            _testnet.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
        }];
        [_testnet setUp];
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

+(DSChain*)recoverKnownDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray performSetup:(BOOL)performSetup {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:identifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:identifier checkpoints:checkpointArray];
            [_devnetDictionary setObject:devnetChain forKey:identifier];
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:identifier];
        }
    }
    if (inSetUp) {
        
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity * chainEntity = [devnetChain chainEntityInContext:[NSManagedObjectContext chainContext]];
            devnetChain.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            devnetChain.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            devnetChain.lastPersistedChainSyncLocators = [NSKeyedUnarchiver unarchiveObjectWithData:chainEntity.syncLocators];
            devnetChain.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            devnetChain.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            devnetChain.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
        }];
        if (performSetup) {
            [devnetChain setUp];
        }
    }
    
    return devnetChain;
}

+(DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray withMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID isTransient:(BOOL)isTransient {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:identifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:identifier checkpoints:checkpointArray minimumDifficultyBlocks:minimumDifficultyBlocks port:port dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID isTransient:isTransient];
            [_devnetDictionary setObject:devnetChain forKey:identifier];
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:identifier];
        }
    }
    if (inSetUp && !isTransient) {
        //note: there is no point to load anything if the chain is transient
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity * chainEntity = [devnetChain chainEntityInContext:[NSManagedObjectContext chainContext]];
            devnetChain.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            devnetChain.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            devnetChain.lastPersistedChainSyncLocators = [NSKeyedUnarchiver unarchiveObjectWithData:chainEntity.syncLocators];
            devnetChain.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            devnetChain.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            devnetChain.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
        }];
        [devnetChain setUp];
    }
    
    return devnetChain;
}

+(DSChain*)chainForNetworkName:(NSString*)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

-(void)setUp {
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
}

// MARK: - Helpers

-(NSDictionary<NSValue*,DSBlock*>*)syncBlocks {
    return [self.mSyncBlocks copy];
}

-(NSDictionary<NSValue*,DSBlock*>*)terminalBlocks {
    return [self.mTerminalBlocks copy];
}

-(NSDictionary<NSValue*,DSBlock*>*)orphans {
    return [self.mOrphans copy];
}

-(DSChainManager*)chainManager {
    if (_chainManager) return _chainManager;
    return [[DSChainsManager sharedInstance] chainManagerForChain:self];
}

+(NSMutableArray*)createCheckpointsArrayFromCheckpoints:(checkpoint*)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray * checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i <checkpointCount;i++) {
        NSString * merkleRootString = [NSString stringWithCString:checkpoints[i].merkleRoot encoding:NSUTF8StringEncoding];
        DSCheckpoint * checkpoint = [DSCheckpoint checkpointForHeight:checkpoints[i].height blockHash:[NSString stringWithCString:checkpoints[i].checkpointHash encoding:NSUTF8StringEncoding].hexToData.reverse.UInt256 timestamp:checkpoints[i].timestamp target:checkpoints[i].target merkleRoot:[merkleRootString isEqualToString:@""]?UINT256_ZERO:merkleRootString.hexToData.reverse.UInt256 chainWork:UINT256_ZERO masternodeListName:[NSString stringWithCString:checkpoints[i].masternodeListPath encoding:NSUTF8StringEncoding]];
        [checkpointMutableArray addObject:checkpoint];
    }
    return [checkpointMutableArray copy];
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], _genesisHash));
}

// MARK: Devnet Helpers

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
    UInt256 fullTarget = setCompactLE(nBits);
    uint32_t nVersion = 4;
    UInt256 prevHash = checkpoint.checkpointHash;
    UInt256 merkleRoot = [DSTransaction devnetGenesisCoinbaseWithIdentifier:identifier forChain:self].txHash;
    UInt256 chainWork = @"0400000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    uint32_t nonce = UINT32_MAX; //+1 => 0;
    UInt256 blockhash;
    do {
        nonce++; //should start at 0;
        blockhash = [self blockHashForDevNetGenesisBlockWithVersion:nVersion prevHash:prevHash merkleRoot:merkleRoot timestamp:nTime target:nBits nonce:nonce];
    } while (nonce < UINT32_MAX && uint256_sup(blockhash, fullTarget));
    DSCheckpoint * block2Checkpoint = [DSCheckpoint checkpointForHeight:1 blockHash:blockhash timestamp:nTime target:nBits merkleRoot:merkleRoot chainWork:chainWork masternodeListName:nil];
    return block2Checkpoint;
}

-(dispatch_queue_t)networkingQueue {
    if (!_networkingQueue) {
        NSAssert(!uint256_is_zero(self.genesisHash), @"genesisHash must be set");
        _networkingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.network.%@",self.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return _networkingQueue;
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

-(BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    if ([self chainType] != DSChainType_DevNet) {
        return false;
    } else {
        return uint256_eq([self genesisHash],genesisHash);
    }
}

// MARK: - Keychain Strings

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


// MARK: - Names and Identifiers

-(NSString*)uniqueID {
    if (!_uniqueID) {
        _uniqueID = [[NSData dataWithUInt256:[self genesisHash]] shortHexString];
    }
    return _uniqueID;
}


-(NSString*)networkName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"main";
        case DSChainType_TestNet:
            return @"test";
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return @"dev";
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)name {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"Mainnet";
        case DSChainType_TestNet:
            return @"Testnet";
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [@"Devnet - " stringByAppendingString:self.devnetIdentifier];
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)localizedName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return DSLocalizedString(@"Mainnet",nil);
        case DSChainType_TestNet:
            return DSLocalizedString(@"Testnet",nil);
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [NSString stringWithFormat:@"%@ - %@", DSLocalizedString(@"Devnet",nil),self.devnetIdentifier];
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(void)setDevnetNetworkName:(NSString*)networkName {
    if ([self chainType] == DSChainType_DevNet) _networkName = @"Evonet";
}

// MARK: - L1 Chain Parameters

// MARK: Local Parameters

-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    return @[[DSFundsDerivationPath bip32DerivationPathForAccountNumber:accountNumber onChain:self],[DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self],[DSDerivationPath masterBlockchainIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self]];
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

-(uint32_t)peerMisbehavingThreshold {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return 20;
        case DSChainType_TestNet:
            return 40;
        case DSChainType_DevNet:
            return 3;
        default:
            break;
    }
    return 20;
}

-(BOOL)syncsBlockchain { //required for SPV wallets
    return !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_NeedsWalletSyncType);
}

- (BOOL)needsInitialTerminalHeadersSync
{
    return !(self.estimatedBlockHeight == self.lastTerminalBlockHeight);
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

- (NSString*)chainTip {
    return [NSData dataWithUInt256:self.lastTerminalBlock.blockHash].shortHexString;
}

// MARK: Sync Parameters

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

-(uint32_t)protocolVersion {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return (70216 + (self.headersMaxAmount / 2000));//PROTOCOL_VERSION_MAINNET;
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
            _cachedStandardPort = standardPort;
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
            _cachedStandardDapiGRPCPort = standardDapiGRPCPort;
            setKeychainInt(standardDapiGRPCPort,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,GRPC_PORT_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}

// MARK: Mining and Dark Gravity Wave Parameters

-(UInt256)maxProofOfWork {
    if (!uint256_is_zero(_cachedMaxProofOfWork)) return _cachedMaxProofOfWork;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_MAINNET;
            break;
        case DSChainType_TestNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_TESTNET;
            break;
        case DSChainType_DevNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_DEVNET;
            break;
        default:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_MAINNET;
    }
    return _cachedMaxProofOfWork;
}

-(uint32_t)maxProofOfWorkTarget {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return MAX_TARGET_PROOF_OF_WORK_MAINNET;
        case DSChainType_TestNet:
            return MAX_TARGET_PROOF_OF_WORK_TESTNET;
        case DSChainType_DevNet:
            return MAX_TARGET_PROOF_OF_WORK_DEVNET;
        default:
            return MAX_TARGET_PROOF_OF_WORK_MAINNET;
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
    }
}

-(uint64_t)baseReward {
    if ([self chainType] == DSChainType_MainNet) return 5 * DUFFS;
    return 50 * DUFFS;
}

// MARK: Spork Parameters

-(NSString*)sporkPublicKeyHexString {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
        case DSChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
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

-(void)setSporkPublicKeyHexString:(NSString *)sporkPublicKey {
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

-(NSString*)sporkPrivateKeyBase58String {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return nil;
        case DSChainType_TestNet:
            return nil;
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

-(void)setSporkPrivateKeyBase58String:(NSString *)sporkPrivateKey {
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
        case DSChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
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

// MARK: Fee Parameters

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

// MARK: - L2 Chain Parameters

-(UInt256)dpnsContractID {
    if (!uint256_is_zero(_cachedDpnsContractID)) return _cachedDpnsContractID;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = MAINNET_DPNS_CONTRACT_ID.hexToData.UInt256;
            return _cachedDpnsContractID;
        case DSChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = TESTNET_DPNS_CONTRACT_ID.hexToData.UInt256;
            return _cachedDpnsContractID;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSData * cachedDpnsContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DPNS_CONTRACT_ID], &error);
            if (!error && cachedDpnsContractIDData) {
                _cachedDpnsContractID = cachedDpnsContractIDData.UInt256;
                return _cachedDpnsContractID;
            }
            else return UINT256_ZERO;
            break;
        }
    }
}

-(void)setDpnsContractID:(UInt256)dpnsContractID {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            _cachedDpnsContractID = dpnsContractID;
            if (uint256_is_zero(dpnsContractID)) {
                NSError * error = nil;
                NSString * identifier = [NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DPNS_CONTRACT_ID];
                BOOL hasDashpayContractID = getKeychainData(identifier, &error);
                if (hasDashpayContractID) {
                    setKeychainData(nil, identifier, NO);
                }
            } else {
                setKeychainData(uint256_data(dpnsContractID), [NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DPNS_CONTRACT_ID], NO);
            }
            break;
        }
    }
}

-(UInt256)dashpayContractID {
    if (!uint256_is_zero(_cachedDashpayContractID)) return _cachedDashpayContractID;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = MAINNET_DASHPAY_CONTRACT_ID.hexToData.UInt256;
            return _cachedDashpayContractID;
        case DSChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = TESTNET_DASHPAY_CONTRACT_ID.hexToData.UInt256;
            return _cachedDashpayContractID;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSData * cachedDashpayContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DASHPAY_CONTRACT_ID], &error);
            if (!error && cachedDashpayContractIDData) {
                _cachedDashpayContractID = cachedDashpayContractIDData.UInt256;
                return _cachedDashpayContractID;
            }
            else return UINT256_ZERO;
            break;
        }
    }
}

-(void)setDashpayContractID:(UInt256)dashpayContractID {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            _cachedDashpayContractID = dashpayContractID;
            if (uint256_is_zero(dashpayContractID)) {
                NSError * error = nil;
                NSString * identifier = [NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DASHPAY_CONTRACT_ID];
                BOOL hasDashpayContractID = getKeychainData(identifier, &error);
                if (hasDashpayContractID) {
                    setKeychainData(nil, identifier, NO);
                }
            } else {
                setKeychainData(uint256_data(dashpayContractID), [NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DASHPAY_CONTRACT_ID], NO);
            }
            break;
        }
    }
}

-(void)setMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            _cachedMinimumDifficultyBlocks = minimumDifficultyBlocks;
            setKeychainInt(minimumDifficultyBlocks, [NSString stringWithFormat:@"%@%@",self.devnetIdentifier,MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], NO);
            break;
        }
    }
}

-(uint32_t)minimumDifficultyBlocks {
    if (_cachedMinimumDifficultyBlocks) return _cachedMinimumDifficultyBlocks;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            _cachedMinimumDifficultyBlocks = 0;
            return 0;
        case DSChainType_TestNet:
            _cachedMinimumDifficultyBlocks = 0;
            return 0;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t cachedMinimumDifficultyBlocks = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], &error);
            if (!error && cachedMinimumDifficultyBlocks) {
                _cachedMinimumDifficultyBlocks = cachedMinimumDifficultyBlocks;
                return _cachedMinimumDifficultyBlocks;
            }
            else return 0;
        }
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
        }
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
            _cachedStandardDapiJRPCPort = standardDapiJRPCPort;
            setKeychainInt(standardDapiJRPCPort,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,JRPC_PORT_LOCATION], NO);
            break;
        }
    }
}

// MARK: - Standalone Derivation Paths

-(BOOL)hasAStandaloneDerivationPath {
    return !![self.viewingAccount.fundDerivationPaths count];
}

-(DSAccount*)viewingAccount {
    if (_viewingAccount) return _viewingAccount;
    self.viewingAccount = [[DSAccount alloc] initAsViewOnlyWithAccountNumber:0 withDerivationPaths:@[] inContext:self.chainManagedObjectContext];
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

// MARK: - Probabilistic Filters

- (DSBloomFilter*)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak {
    NSMutableSet * allAddresses = [NSMutableSet set];
    NSMutableSet * allUTXOs = [NSMutableSet set];
    for (DSWallet * wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL internal:NO error:nil];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL internal:YES error:nil];
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
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO error:nil];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES error:nil];
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
            if (tx.blockHeight != TX_UNCONFIRMED && tx.blockHeight + 100 < self.lastSyncBlockHeight) {
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

-(BOOL)canConstructAFilter {
    return [self hasAStandaloneDerivationPath] || [self hasAWallet];
}

// MARK: - Checkpoints

-(BOOL)blockHeightHasCheckpoint:(uint32_t)blockHeight {
    DSCheckpoint * checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    return (checkpoint.height == blockHeight);
}

-(DSCheckpoint*)lastCheckpoint {
    if (!_lastCheckpoint) {
        _lastCheckpoint = [[self checkpoints] lastObject];
    }
    return _lastCheckpoint;
}

-(DSCheckpoint*)lastCheckpointOnOrBeforeHeight:(uint32_t)height {
    NSUInteger genesisHeight = [self isDevnetAny]?1:0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].height <= height)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

-(DSCheckpoint*)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    NSUInteger genesisHeight = [self isDevnetAny]?1:0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].timestamp <= timestamp)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint* _Nullable)lastCheckpointHavingMasternodeList {
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


-(NSMutableDictionary*)checkpointsByHashDictionary {
    if (!_checkpointsByHashDictionary) [self mSyncBlocks];
    return _checkpointsByHashDictionary;
}

-(NSMutableDictionary*)checkpointsByHeightDictionary {
    if (!_checkpointsByHeightDictionary) [self mSyncBlocks];
    return _checkpointsByHeightDictionary;
}

- (void)useCheckpointBeforeOrOnHeightForTerminalBlocksSync:(uint32_t)blockHeight {
    DSCheckpoint * checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    self.terminalHeadersOverrideUseCheckpoint = checkpoint;
}

- (void)useCheckpointBeforeOrOnHeightForSyncingChainBlocks:(uint32_t)blockHeight {
    DSCheckpoint * checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    self.syncHeadersOverrideUseCheckpoint = checkpoint;
}


// MARK: - Wallet

-(BOOL)hasAWallet {
    return !![self.mWallets count];
}

-(NSArray*)wallets {
    return [self.mWallets copy];
}

-(void)unregisterAllWallets {
    for (DSWallet * wallet in [self.mWallets copy]) {
        [self unregisterWallet:wallet];
    }
}

-(void)unregisterAllWalletsMissingExtendedPublicKeys {
    for (DSWallet * wallet in [self.mWallets copy]) {
        if ([wallet hasAnExtendedPublicKeyMissing]) {
            [self unregisterWallet:wallet];
        }
    }
}

-(void)unregisterWallet:(DSWallet*)wallet {
    NSAssert(wallet.chain == self, @"the wallet you are trying to remove is not on this chain");
    [wallet wipeBlockchainInfoInContext:self.chainManagedObjectContext];
    [wallet wipeWalletInfo];
    [self.mWallets removeObject:wallet];
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueIDString];
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
        _lastSyncBlock = nil; //it will lazy load later
    }
    
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    if (![keyChainArray containsObject:wallet.uniqueIDString]) {
        [keyChainArray addObject:wallet.uniqueIDString];
        setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
}

-(void)retrieveWallets {
    NSError * error = nil;
    NSArray * walletIdentifiers = getKeychainArray(self.chainWalletsKey, &error);
    if (!error && walletIdentifiers) {
        for (NSString * uniqueID in walletIdentifiers) {
            DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueID forChain:self];
            [self addWallet:wallet];
        }
        //we should load blockchain identies after all wallets are in the chain, as blockchain identities might be on different wallets and have interactions between each other
        for (DSWallet * wallet in self.wallets) {
            [wallet loadBlockchainIdentities];
        }
    }
}

// MARK: - Blocks

-(NSDictionary*)recentBlocks {
    return [[self mSyncBlocks] copy];
}

- (DSBlock *)lastChainSyncBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    DSBlock *b = self.lastSyncBlock;
    NSTimeInterval blockTime = b.timestamp;
    while (b && b.height > 0 && blockTime >= timestamp) {
        b = self.mSyncBlocks[b.prevBlockValue];
    }
    if (!b) b = [[DSMerkleBlock alloc] initWithCheckpoint:[self lastCheckpointOnOrBeforeTimestamp:timestamp] onChain:self];
    return b;
}

- (DSBlock *)lastBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    DSBlock *b = self.lastTerminalBlock;
    NSTimeInterval blockTime = b.timestamp;
    BOOL useSyncBlocksNow = (b != _lastTerminalBlock);
    while (b && b.height > 0 && blockTime >= timestamp) {
        if (!useSyncBlocksNow) {
            b = useSyncBlocksNow?self.mSyncBlocks[b.prevBlockValue]:self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = !useSyncBlocksNow;
            b = useSyncBlocksNow?self.mSyncBlocks[b.prevBlockValue]:self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    if (!b) b = [[DSMerkleBlock alloc] initWithCheckpoint:[self lastCheckpointOnOrBeforeTimestamp:timestamp] onChain:self];
    return b;
}

-(void)setLastTerminalBlockFromCheckpoints {
    DSCheckpoint * checkpoint = self.terminalHeadersOverrideUseCheckpoint?self.terminalHeadersOverrideUseCheckpoint:[self lastCheckpoint];
    if (checkpoint) {
        if (self.mTerminalBlocks[uint256_obj(checkpoint.checkpointHash)]) {
            _lastTerminalBlock = self.mSyncBlocks[uint256_obj(checkpoint.checkpointHash)];
        } else {
            _lastTerminalBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.mTerminalBlocks[uint256_obj(checkpoint.checkpointHash)] = _lastTerminalBlock;
        }
    }
    
    if (_lastTerminalBlock) {
        DSDLog(@"last terminal block at height %d chosen from checkpoints (hash is %@)",_lastSyncBlock.height,[NSData dataWithUInt256:_lastTerminalBlock.blockHash].hexString);
    }
}

-(void)setLastSyncBlockFromCheckpoints {
    DSCheckpoint * checkpoint = nil;
    if (self.syncHeadersOverrideUseCheckpoint) {
        checkpoint = self.syncHeadersOverrideUseCheckpoint;
    } else if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
        NSUInteger genesisHeight = [self isDevnetAny]?1:0;
        checkpoint = self.checkpoints[genesisHeight];
    } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
        checkpoint = [self lastCheckpointOnOrBeforeHeight:[[DSOptionsManager sharedInstance] syncFromHeight]];
    } else {
        NSTimeInterval startSyncTime = self.startSyncFromTime;
        checkpoint = [self lastCheckpointOnOrBeforeTimestamp:(startSyncTime == BIP39_CREATION_TIME)?BIP39_CREATION_TIME:startSyncTime - HEADER_WINDOW_BUFFER_TIME];
    }
    
    if (checkpoint) {
        if (self.mSyncBlocks[uint256_obj(checkpoint.checkpointHash)]) {
            _lastSyncBlock = self.mSyncBlocks[uint256_obj(checkpoint.checkpointHash)];
        } else {
            _lastSyncBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.mSyncBlocks[uint256_obj(checkpoint.checkpointHash)] = _lastSyncBlock;
        }
    }
    
    if (_lastSyncBlock) {
        DSDLog(@"last sync block at height %d chosen from checkpoints (hash is %@)",_lastSyncBlock.height,[NSData dataWithUInt256:_lastSyncBlock.blockHash].hexString);
    }
}

- (DSBlock *)lastSyncBlock
{
    if (! _lastSyncBlock) {
        [self setLastSyncBlockFromCheckpoints];
    }
    
    return _lastSyncBlock;
}

- (NSMutableDictionary *)mSyncBlocks
{
    if (_mSyncBlocks.count > 0) {
        if (!_checkpointsByHashDictionary) _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        if (!_checkpointsByHeightDictionary) _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        return _mSyncBlocks;
    }
    
    [self.chainManagedObjectContext performBlockAndWait:^{
        if (self->_mSyncBlocks.count > 0) return;
        self->_mSyncBlocks = [NSMutableDictionary dictionary];
        
        if (!uint256_is_zero(self.lastPersistedChainSyncBlockHash)) {
            self->_mSyncBlocks[uint256_obj(self.lastPersistedChainSyncBlockHash)] = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight onChain:self];
        }
        
        self.checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        self.checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;
            
            self->_mSyncBlocks[uint256_obj(checkpointHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
            self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
        }
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastTerminalBlocks:LLMQ_KEEP_RECENT_BLOCKS onChainEntity:[self chainEntityInContext:self.chainManagedObjectContext]]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;
                
                if (b) self->_mSyncBlocks[b.blockHashValue] = b;
            }
        };
    }];
    
    return _mSyncBlocks;
}

- (NSArray <NSData*> *)chainSyncBlockLocatorArray {
    if (_lastSyncBlock && !(_lastSyncBlock.height == 1 && self.chainType == DSChainType_DevNet)) {
        return [self blockLocatorArrayForBlock:_lastSyncBlock];
    } else if (!_lastPersistedChainSyncLocators) {
        _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:1425039295 includeInitialTerminalBlocks:NO];
    }
    return _lastPersistedChainSyncLocators;
}

- (NSArray <NSData*> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp includeInitialTerminalBlocks:(BOOL)includeHeaders {
    DSBlock *block = includeHeaders?[self lastBlockOnOrBeforeTimestamp:timestamp]:[self lastChainSyncBlockOnOrBeforeTimestamp:timestamp];
    return [self blockLocatorArrayForBlock:block];
}

// this is used as part of a getblocks or getheaders request
- (NSArray <NSData*> *)blockLocatorArrayForBlock:(DSBlock*)block
{
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSBlock *b = block;
    uint32_t lastHeight = b.height;
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.mSyncBlocks[b.prevBlockValue];
            if (!b) b = self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    DSCheckpoint * lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight && checkpoint.timestamp < b.timestamp) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.checkpointHash)];
    }
    return locators;
}


- (DSBlock * _Nullable)blockForBlockHash:(UInt256)blockHash {
    DSBlock * b = self.mSyncBlocks[uint256_obj(blockHash)];
    if (b) return b;
    return self.mTerminalBlocks[uint256_obj(blockHash)];
}

-(DSBlock*)recentTerminalBlockForBlockHash:(UInt256)blockHash {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL useSyncBlocksNow = FALSE;
    while (b && b.height > 0 && !uint256_eq(b.blockHash, blockHash)) {
        if (!useSyncBlocksNow) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = TRUE;
        }
        if (useSyncBlocksNow) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        count++;
    }
    return b;
}

- (DSBlock *)blockAtHeight:(uint32_t)height {
    DSBlock *b = self.lastTerminalBlock;
    while (b && b.height > height) {
        b = self.mTerminalBlocks[b.prevBlockValue];
    }
    if (b.height != height) {
        DSBlock *b = self.lastSyncBlock;
        while (b && b.height > height) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        if (b.height != height) return nil;
    }
    return b;
}

- (DSBlock *)blockFromChainTip:(NSUInteger)blocksAgo {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL useSyncBlocksNow = FALSE;
    while (b && b.height > 0 && count < blocksAgo) {
        if (!useSyncBlocksNow) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = TRUE;
        }
        if (useSyncBlocksNow) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        count++;
    }
    return b;
}

// MARK: From Peer


- (BOOL)addMinedFullBlock:(DSFullBlock *)block {
    NSAssert(block.transactionHashes, @"Block must have txHashes");
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    if (!self.mSyncBlocks[prevBlock] || !self.mTerminalBlocks[prevBlock]) return NO;
    if (!uint256_eq(self.lastSyncBlock.blockHash,self.mSyncBlocks[prevBlock].blockHash)) return NO;
    if (!uint256_eq(self.lastTerminalBlock.blockHash,self.mTerminalBlocks[prevBlock].blockHash)) return NO;
    
    
    @synchronized (self.mSyncBlocks) {
        self.mSyncBlocks[blockHash] = block;
    }
    self.lastSyncBlock = block;
    
    @synchronized (self.mTerminalBlocks) {
        self.mTerminalBlocks[blockHash] = block;
    }
    self.lastTerminalBlock = block;
    
    uint32_t txTime = block.timestamp/2 + self.mTerminalBlocks[prevBlock].timestamp/2;
    
    [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
    
    if (block.height > self.estimatedBlockHeight) {
        _bestEstimatedBlockHeight = block.height;
        [self saveBlockLocators];
        [self saveTerminalBlocks];
        
        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
    
    return TRUE;
}

//TRUE if it was added to the end of the chain
- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer*)peer
{
    if (peer && !self.chainManager.syncPhase) {
        DSDLog(@"Block was received from peer after reset, ignoring it");
        return FALSE;
    }
    //DSDLog(@"a block %@",uint256_hex(block.blockHash));
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSBlock *prev = nil;
    BOOL isTerminalBlock = FALSE;
    DSChainSyncPhase phase = self.chainManager.syncPhase;
    if (phase == DSChainSyncPhase_InitialTerminalBlocks) {
        //In this phase all received blocks are treated as terminal blocks
        prev = self.mTerminalBlocks[prevBlock];
        if (prev) {
            isTerminalBlock = TRUE;
        }
    } else {
        prev = self.mSyncBlocks[prevBlock];
        if (!prev) {
            prev = self.mTerminalBlocks[prevBlock];
            if (prev) {
                isTerminalBlock = TRUE;
            }
        }
    }

    
    
    if (! prev) { // header is an orphan
#if LOG_PREV_BLOCKS_ON_ORPHAN
        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        for (DSBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            DSDLog(@"printing previous block at height %d : %@",merkleBlock.height,merkleBlock.blockHashValue);
        }
#endif
        DSDLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", peer.host?peer.host:@"TEST", peer.port,
               uint256_reverse_hex(block.blockHash), uint256_reverse_hex(block.prevBlock), block.height, uint256_reverse_hex(self.lastTerminalBlock.blockHash), self.lastSyncBlockHeight,[NSDate dateWithTimeIntervalSince1970:block.timestamp]);
        
        if (peer) {
            [self.chainManager chain:self receivedOrphanBlock:block fromPeer:peer];
            [peer receivedOrphanBlock];
        }
        
        self.mOrphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return FALSE;
    }
    
    BOOL syncDone = NO;
    
    block.height = prev.height + 1;
    UInt256 target = setCompactLE(block.target);
    NSAssert(!uint256_is_zero(prev.aggregateWork), @"previous block should have aggregate work set");
    block.aggregateWork = uInt256AddLE(prev.aggregateWork,uInt256AddOneLE(uInt256DivideLE(uint256_inverse(target), uInt256AddOneLE(target))));
    uint32_t txTime = block.timestamp/2 + prev.timestamp/2;
    
    if (isTerminalBlock) {
        if ((block.height % 10000) == 0 || ((block.height == self.estimatedBlockHeight) && (block.height % 100) == 0)) { //free up some memory from time to time
            @synchronized (self.mTerminalBlocks) {
                //[self saveTerminalBlocks];
                DSBlock *b = block;
                
                for (uint32_t i = 0; b && i < LLMQ_KEEP_RECENT_BLOCKS; i++) {
                    b = self.mTerminalBlocks[b.prevBlockValue];
                }
                NSMutableArray * blocksToRemove = [NSMutableArray array];
                while (b) { // free up some memory
                    [blocksToRemove addObject:b.blockHashValue];
                    b = self.mTerminalBlocks[b.prevBlockValue];
                }
                [self.mTerminalBlocks removeObjectsForKeys:blocksToRemove];
            }
        }
    } else { //sync block
        if ((block.height % 1000) == 0) { //free up some memory from time to time
            @synchronized (self.mSyncBlocks) {

                DSBlock *b = block;
                
                for (uint32_t i = 0; b && i < LLMQ_KEEP_RECENT_BLOCKS; i++) {
                    b = self.mSyncBlocks[b.prevBlockValue];
                }
                NSMutableArray * blocksToRemove = [NSMutableArray array];
                while (b) { // free up some memory
                    [blocksToRemove addObject:b.blockHashValue];
                    b = self.mSyncBlocks[b.prevBlockValue];
                }
                [self.mSyncBlocks removeObjectsForKeys:blocksToRemove];
            }
        }
    }
    
    // verify block difficulty if block is past last checkpoint
    DSCheckpoint * lastCheckpoint = [self lastCheckpoint];
    
    DSBlock * equivalentTerminalBlock = nil;
    
    if (!isTerminalBlock) {
        if (self.lastSyncBlockHeight + 1 >= lastCheckpoint.height) {
            equivalentTerminalBlock = self.mTerminalBlocks[blockHash];
        }
    }

    
    if (!equivalentTerminalBlock) { //no need to check difficulty if we already have terminal blocks
        if ((block.height > self.minimumDifficultyBlocks) && (block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
            ![block verifyDifficultyWithPreviousBlocks:isTerminalBlock?self.mTerminalBlocks:self.mSyncBlocks]) {
            uint32_t foundDifficulty = [block darkGravityWaveTargetWithPreviousBlocks:isTerminalBlock?self.mTerminalBlocks:self.mSyncBlocks];
            DSDLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
                   block.height,block.target,foundDifficulty, blockHash);
            if (peer) {
                [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
    }
    
    if (!equivalentTerminalBlock) {
        
        DSCheckpoint * checkpoint = [self.checkpointsByHeightDictionary objectForKey:@(block.height)];
        
        // verify block chain checkpoints
        if (checkpoint && ! uint256_eq(block.blockHash, checkpoint.checkpointHash)) {
            DSDLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
                   peer.host, peer.port, block.height, blockHash, uint256_hex(checkpoint.checkpointHash));
            if (peer) {
                [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
    }
    
    BOOL onMainChain = FALSE;
    
    if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && uint256_eq(block.prevBlock, self.lastSyncBlockHash)) { // new block extends sync chain
        if ((block.height % 100) == 0 || txHashes.count > 0 || block.height > peer.lastBlockHeight) {
            DSDLog(@"adding sync block on %@ at height: %d from peer %@", self.name, block.height,peer.host);
        }
        @synchronized (self.mSyncBlocks) {
            self.mSyncBlocks[blockHash] = block;
        }
        self.lastSyncBlock = block;
        
        if (!equivalentTerminalBlock && uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) {
            if ((block.height % 100) == 0 || txHashes.count > 0 || block.height > peer.lastBlockHeight) {
                DSDLog(@"adding terminal block on %@ (caught up) at height: %d with hash: %@ from peer %@", self.name, block.height,uint256_hex(block.blockHash),peer.host?peer.host:@"TEST");
            }
            @synchronized (self.mTerminalBlocks) {
                self.mTerminalBlocks[blockHash] = block;
            }
            self.lastTerminalBlock = block;
            if (peer) {
                peer.currentBlockHeight = block.height; //might be download peer instead
            }
        }
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
        [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
        onMainChain = TRUE;
        
        if ([self blockHeightHasCheckpoint:block.height] || ((block.height % 1000 == 0) && block.height + BLOCK_NO_FORK_DEPTH < self.lastTerminalBlockHeight) ) {
            [self saveBlockLocators];
        }
        
    } else if (uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) { // new block extends terminal chain
        if ((block.height % 100) == 0 || txHashes.count > 0 || block.height > peer.lastBlockHeight) {
            DSDLog(@"adding terminal block on %@ at height: %d with hash: %@ from peer %@", self.name, block.height,uint256_hex(block.blockHash),peer.host?peer.host:@"TEST");
        }
        @synchronized (self.mTerminalBlocks) {
            self.mTerminalBlocks[blockHash] = block;
        }
        self.lastTerminalBlock = block;
        if (peer) {
            peer.currentBlockHeight = block.height; //might be download peer instead
        }
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    } else if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && self.mSyncBlocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((block.height % 1) == 0 || txHashes.count > 0 || block.height > peer.lastBlockHeight) {
            DSDLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
        }
        
        @synchronized (self.mSyncBlocks) {
            self.mSyncBlocks[blockHash] = block;
        }
        
        DSBlock *b = self.lastSyncBlock;
        
        while (b && b.height > block.height) b = self.mSyncBlocks[b.prevBlockValue]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
            if (block.height == self.lastSyncBlockHeight) self.lastSyncBlock = block;
        }
    }  else if (self.mTerminalBlocks[blockHash] != nil && isTerminalBlock) { // we already have the block (or at least the header)
           if ((block.height % 1) == 0 || txHashes.count > 0 || block.height > peer.lastBlockHeight) {
               DSDLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
           }
           
           @synchronized (self.mTerminalBlocks) {
               self.mTerminalBlocks[blockHash] = block;
           }
           
           DSBlock *b = self.lastTerminalBlock;
           
           while (b && b.height > block.height) b = self.mTerminalBlocks[b.prevBlockValue]; // is block in main chain?
           
           if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
               [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
               if (block.height == self.lastTerminalBlockHeight) self.lastTerminalBlock = block;
           }
       }
    else { // new block is on a fork
        if (block.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            DSDLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                   block.height, blockHash);
            return TRUE;
        }
        
        // special case, if a new block is mined while we're rescanning the chain, mark as orphan til we're caught up
        if (self.lastSyncBlockHeight < peer.lastBlockHeight && block.height > self.lastSyncBlockHeight + 1) {
            DSDLog(@"marking new block at height %d as orphan until rescan completes", block.height);
            self.mOrphans[prevBlock] = block;
            self.lastOrphan = block;
            return TRUE;
        }
        
        DSDLog(@"potential chain fork to height %d", block.height);
        if (isTerminalBlock) {
            @synchronized (self.mTerminalBlocks) {
                self.mTerminalBlocks[blockHash] = block;
            }
            if (uint256_supeq(self.lastTerminalBlock.aggregateWork, block.aggregateWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSDLog(@"found chain fork on height %d", block.height);
            
            DSBlock *b = block, *b2 = self.lastTerminalBlock;
            
            while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
                b = self.mTerminalBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
            }
            
            DSDLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
            
            self.lastTerminalBlock = block;
            if (block.height == self.estimatedBlockHeight) syncDone = YES;
        } else {
            @synchronized (self.mSyncBlocks) {
                self.mSyncBlocks[blockHash] = block;
            }
            if (uint256_supeq(self.lastSyncBlock.aggregateWork, block.aggregateWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSDLog(@"found sync chain fork on height %d", block.height);
            
            DSBlock *b = block, *b2 = self.lastSyncBlock;
            
            while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
                b = self.mSyncBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mSyncBlocks[b2.prevBlockValue];
            }
            
            DSDLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
            
            NSMutableArray *txHashes = [NSMutableArray array];
            // mark transactions after the join point as unconfirmed
            for (DSWallet * wallet in self.wallets) {
                for (DSTransaction *tx in wallet.allTransactions) {
                    if (tx.blockHeight <= b.height) break;
                    [txHashes addObject:uint256_obj(tx.txHash)];
                }
            }
            
            [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTransactionHashes:txHashes];
            b = block;
    
            while (b.height > b2.height) { // set transaction heights for new main chain
                [self setBlockHeight:b.height andTimestamp:txTime forTransactionHashes:b.transactionHashes];
                b = self.mSyncBlocks[b.prevBlockValue];
                txTime = b.timestamp/2 + ((DSBlock *)self.mSyncBlocks[b.prevBlockValue]).timestamp/2;
            }
            
            self.lastSyncBlock = block;
            if (block.height == self.estimatedBlockHeight) syncDone = YES;
        }

    }
    
    
    BOOL savedBlockLocators = NO;
    BOOL savedTerminalBlocks = NO;
    if (syncDone) { // chain download is complete
        if (isTerminalBlock) {
            [self saveTerminalBlocks];
            savedTerminalBlocks = YES;
            if (peer) {
                [self.chainManager chainFinishedSyncingInitialHeaders:self fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainInitialHeadersDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            });
        } else if (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) {
            //we should only save
            [self saveBlockLocators];
            savedBlockLocators = YES;
            if (peer) {
                [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            });
        }
    }
    
    if (block.height > self.estimatedBlockHeight) {
        _bestEstimatedBlockHeight = block.height;
        if (peer && !isTerminalBlock && !savedBlockLocators) {
            [self saveBlockLocators];
        }
        if (!savedTerminalBlocks) {
            [self saveTerminalBlocks];
        }
        if (peer) {
            [self.chainManager chain:self wasExtendedWithBlock:block fromPeer:peer];
        }
        
        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    } else {
        //we should avoid dispatching this message too frequently
        NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
        if (!self.lastNotifiedBlockDidChange || (timestamp - self.lastNotifiedBlockDidChange > 0.1)) {
            self.lastNotifiedBlockDidChange = timestamp;
            if (isTerminalBlock)
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isTerminalBlock) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
                }
            });
        }
    }
    
    // check if the next block was received as an orphan
    if (block == self.lastTerminalBlock && self.mOrphans[blockHash]) {
        DSBlock *b = self.mOrphans[blockHash];
        
        [self.mOrphans removeObjectForKey:blockHash];
        [self addBlock:b receivedAsHeader:YES fromPeer:peer]; //revisit this
    }
    return TRUE;
}

//- (BOOL)addTerminalBlock:(DSBlock *)terminalBlock fromPeer:(DSPeer*)peer
//{
//    NSValue *blockHash = terminalBlock.blockHashValue, *prevBlock = terminalBlock.prevBlockValue;
//    DSBlock *prev = self.terminalBlocks[prevBlock];
//    uint32_t txTime = 0;
//    BOOL syncDone = NO;
//
//    if (! prev) { // header is an orphan
//#if LOG_PREV_BLOCKS_ON_ORPHAN
//        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
//        for (DSBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
//            DSDLog(@"printing previous block at height %d : %@",merkleBlock.height,merkleBlock.blockHashValue);
//        }
//#endif
//        DSDLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", peer.host, peer.port,
//               uint256_reverse_hex(terminalBlock.blockHash), uint256_reverse_hex(terminalBlock.prevBlock), terminalBlock.height, uint256_reverse_hex(self.lastTerminalBlock.blockHash), self.lastSyncBlockHeight,[NSDate dateWithTimeIntervalSince1970:terminalBlock.timestamp]);
//
//        [self.chainManager chain:self receivedOrphanBlock:terminalBlock fromPeer:peer];
//        [peer receivedOrphanBlock];
//
//        self.orphans[prevBlock] = terminalBlock; // orphans are indexed by prevBlock instead of blockHash
//        self.lastOrphan = terminalBlock;
//        return TRUE;
//    }
//
//    terminalBlock.height = prev.height + 1;
//    txTime = terminalBlock.timestamp/2 + prev.timestamp/2;
//
//    if (terminalBlock.height % 1 == 0) {
//        DSDLog(@"Adding terminal block at height %d %@",terminalBlock.height,uint256_hex(terminalBlock.blockHash));
//    }
//
//
//    if ((terminalBlock.height % 10000) == 0 || ((terminalBlock.height == self.estimatedBlockHeight) && (terminalBlock.height % 100) == 0)) { //free up some memory from time to time
//        @synchronized (self.terminalBlocks) {
//            //[self saveTerminalBlocks];
//            DSBlock *b = terminalBlock;
//
//            for (uint32_t i = 0; b && i < LLMQ_KEEP_RECENT_BLOCKS; i++) {
//                b = self.terminalBlocks[b.prevBlockValue];
//            }
//            NSMutableArray * blocksToRemove = [NSMutableArray array];
//            while (b) { // free up some memory
//                [blocksToRemove addObject:b.blockHashValue];
//                b = self.terminalBlocks[b.prevBlockValue];
//            }
//            [self.terminalBlocks removeObjectsForKeys:blocksToRemove];
//            //DSDLog(@"%lu blocks remaining",(unsigned long)[self.blocks count]);
//        }
//    }
//
//
//    // verify block difficulty if block is past last checkpoint
//    DSCheckpoint * lastCheckpoint = [self lastCheckpoint];
//
//    if (!self.isDevnetAny) {
//        if ((terminalBlock.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
//            ![terminalBlock verifyDifficultyWithPreviousBlocks:self.terminalBlocks]) {
//            uint32_t foundDifficulty = [terminalBlock darkGravityWaveTargetWithPreviousBlocks:self.terminalBlocks];
//            DSDLog(@"%@:%d relayed header with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
//                   terminalBlock.height,terminalBlock.target,foundDifficulty, blockHash);
//            [self.chainManager chain:self badBlockReceivedFromPeer:peer];
//            return FALSE;
//        }
//    }
//
//    DSCheckpoint * checkpoint = [self.checkpointsByHeightDictionary objectForKey:@(terminalBlock.height)];
//
//    // verify block chain checkpoints
//    if (checkpoint && ! uint256_eq(terminalBlock.blockHash, checkpoint.checkpointHash)) {
//        DSDLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
//               peer.host, peer.port, terminalBlock.height, blockHash, uint256_hex(checkpoint.checkpointHash));
//        [self.chainManager chain:self badBlockReceivedFromPeer:peer];
//        return FALSE;
//    }
//
//    BOOL onMainChain = FALSE;
//
//    if (uint256_eq(terminalBlock.prevBlock, self.lastTerminalBlock.blockHash)) { // new block extends main chain
//        if ((terminalBlock.height % self.headersMaxAmount) == 0 || terminalBlock.height > peer.lastBlockHeight) {
//            DSDLog(@"adding header on %@ at height: %d from peer %@", self.name, terminalBlock.height,peer.host);
//        }
//        @synchronized (self.terminalBlocks) {
//            self.terminalBlocks[blockHash] = terminalBlock;
//        }
//        self.lastTerminalBlock = terminalBlock;
//        peer.currentBlockHeight = terminalBlock.height; //might be download peer instead
//        if (terminalBlock.height == self.estimatedBlockHeight) syncDone = YES;
//        onMainChain = TRUE;
//    }
//    else if (self.terminalBlocks[blockHash] == nil) { // new header is a new orphan
//        if (terminalBlock.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
//            DSDLog(@"ignoring header on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
//                   terminalBlock.height, blockHash);
//            return TRUE;
//        }
//
//
//        DSDLog(@"chain header fork to height %d", terminalBlock.height);
//        @synchronized (self.terminalBlocks) {
//            self.terminalBlocks[blockHash] = terminalBlock;
//        }
//        if (terminalBlock.height <= self.lastSyncBlockHeight) return TRUE; // if fork is shorter than main chain, ignore it for now
//
//        NSMutableArray *txHashes = [NSMutableArray array];
//        DSBlock *b = terminalBlock, *b2 = self.lastTerminalBlock;
//
//        while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
//            b = self.terminalBlocks[b.prevBlockValue];
//            if (b.height < b2.height) b2 = self.terminalBlocks[b2.prevBlockValue];
//        }
//
//        DSDLog(@"reorganizing chain from height %d, new height is %d", b.height, terminalBlock.height);
//
//        // mark transactions after the join point as unconfirmed
//        for (DSWallet * wallet in self.wallets) {
//            for (DSTransaction *tx in wallet.allTransactions) {
//                if (tx.blockHeight <= b.height) break;
//                [txHashes addObject:uint256_obj(tx.txHash)];
//            }
//        }
//
//        b = terminalBlock;
//
//        while (b.height > b2.height) { // set transaction heights for new main chain
//            [self setBlockHeight:b.height andTimestamp:txTime forTransactionHashes:b.txHashes];
//            b = self.terminalBlocks[b.prevBlockValue];
//            txTime = b.timestamp/2 + ((DSBlock *)self.syncBlocks[b.prevBlockValue]).timestamp/2;
//        }
//
//        self.lastTerminalBlock = terminalBlock;
//        if (terminalBlock.height == self.estimatedBlockHeight) syncDone = YES;
//    }
//
//    DSBlock * lastTerminalBlock = self.lastTerminalBlock;
//
//    //DSDLog(@"%@:%d added block at height %d target %x blockHash: %@", peer.host, peer.port,
//    //      block.height,block.target, blockHash);
//
//    if (checkpoint && checkpoint == [self lastCheckpointHavingMasternodeList]) {
//        [self.chainManager.masternodeManager loadFileDistributedMasternodeLists];
//    }
//
//    BOOL savedTerminalBlocks = NO;
//    if (syncDone) { // chain download is complete
//        [self saveTerminalBlocks];
//        savedTerminalBlocks = YES;
//        [self.chainManager chainFinishedSyncingInitialHeaders:self fromPeer:peer onMainChain:onMainChain];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainInitialHeadersDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
//        });
//    }
//
//    if (terminalBlock.height > self.estimatedBlockHeight) {
//        _bestEstimatedBlockHeight = terminalBlock.height;
//        if (!savedTerminalBlocks) {
//            [self saveTerminalBlocks];
//        }
//        [self.chainManager chain:self wasExtendedWithBlock:terminalBlock fromPeer:peer];
//
//        // notify that transaction confirmations may have changed
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
//            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
//        });
//    } else {
//        //we should avoid dispatching this message too frequently
//        NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
//        if (!self.lastNotifiedBlockDidChange || (timestamp - self.lastNotifiedBlockDidChange > 0.1)) {
//            self.lastNotifiedBlockDidChange = timestamp;
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
//            });
//        }
//    }
//
//    // check if the next block was received as an orphan
//    if (terminalBlock == lastTerminalBlock && self.orphans[blockHash]) {
//        DSBlock *b = self.orphans[blockHash];
//
//        [self.orphans removeObjectForKey:blockHash];
//        [self addTerminalBlock:b fromPeer:peer];
//    }
//    return TRUE;
//}

// MARK: Terminal Blocks

- (NSMutableDictionary *)mTerminalBlocks
{
    if (_mTerminalBlocks.count > 0) {
        if (!_checkpointsByHashDictionary) _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        if (!_checkpointsByHeightDictionary) _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        return _mTerminalBlocks;
    }
    
    [self.chainManagedObjectContext performBlockAndWait:^{
        if (self->_mTerminalBlocks.count > 0) return;
        self->_mTerminalBlocks = [NSMutableDictionary dictionary];
        self.checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        self.checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;
            
            self->_mTerminalBlocks[uint256_obj(checkpointHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
            self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
        }
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastTerminalBlocks:LLMQ_KEEP_RECENT_BLOCKS onChainEntity:[self chainEntityInContext:self.chainManagedObjectContext]]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;
                
                if (b) self->_mTerminalBlocks[b.blockHashValue] = b;
            }
        };
    }];
    
    return _mTerminalBlocks;
}

- (DSBlock *)lastTerminalBlock {
    if (!_lastTerminalBlock) {
        [self.chainManagedObjectContext performBlockAndWait:^{
            NSArray * lastTerminalBlocks = [DSMerkleBlockEntity lastTerminalBlocks:1 onChainEntity:[self chainEntityInContext:self.chainManagedObjectContext]];
            DSMerkleBlock * lastTerminalBlock = [[lastTerminalBlocks firstObject] merkleBlock];
            self->_lastTerminalBlock = lastTerminalBlock;
            if (lastTerminalBlock) {
                DSDLog(@"last terminal block at height %d recovered from db (hash is %@)",lastTerminalBlock.height,[NSData dataWithUInt256:lastTerminalBlock.blockHash].hexString);
            }
        }];
        if (!_lastTerminalBlock) {
            
            // if we don't have any headers yet, use the latest checkpoint
            DSCheckpoint * lastCheckpoint = self.terminalHeadersOverrideUseCheckpoint?self.terminalHeadersOverrideUseCheckpoint:self.lastCheckpoint;
            uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
            
            if (lastCheckpoint.height > lastSyncBlockHeight) {
                [self setLastTerminalBlockFromCheckpoints];
            } else {
                _lastTerminalBlock = self.lastSyncBlock;
            }
        }
        
        if (_lastTerminalBlock.height > self.estimatedBlockHeight) _bestEstimatedBlockHeight = _lastTerminalBlock.height;
    }
    return _lastTerminalBlock;
}

- (NSArray *)terminalBlocksLocatorArray {
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSBlock *b = self.lastTerminalBlock;
    uint32_t lastHeight = b.height;
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    DSCheckpoint * lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this header
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.checkpointHash)];
    }
    return locators;
}


// MARK: Orphans

-(void)clearOrphans {
    [self.mOrphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

// MARK: Chain Locks

-(BOOL)blockHeightChainLocked:(uint32_t)height {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL confirmed = false;
    while (b && b.height > height) {
        b = self.mTerminalBlocks[b.prevBlockValue];
        confirmed |= b.chainLocked;
        count++;
    }
    if (b.height != height) return NO;
    return confirmed;
}
// MARK: - Heights

-(NSTimeInterval)lastSyncBlockTimestamp {
    return _lastSyncBlock?_lastSyncBlock.timestamp:(self.lastPersistedChainSyncBlockTimestamp?self.lastPersistedChainSyncBlockTimestamp:self.lastSyncBlock.timestamp);
}

- (uint32_t)lastSyncBlockHeight {
    return _lastSyncBlock?_lastSyncBlock.height:(self.lastPersistedChainSyncBlockHeight?self.lastPersistedChainSyncBlockHeight:self.lastSyncBlock.height);
}

- (UInt256)lastSyncBlockHash {
    return _lastSyncBlock?_lastSyncBlock.blockHash:(!uint256_is_zero( self.lastPersistedChainSyncBlockHash)?self.lastPersistedChainSyncBlockHash:self.lastSyncBlock.blockHash);
}

- (uint32_t)lastTerminalBlockHeight {
    return self.lastTerminalBlock.height;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    DSCheckpoint * checkpoint = [self.checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    
    DSBlock * syncBlock = [self.mSyncBlocks objectForKey:uint256_obj(blockhash)];
    if (syncBlock && (syncBlock.height != UINT32_MAX)) {
        return syncBlock.height;
    }
    
    DSBlock * terminalBlock = [self.mTerminalBlocks objectForKey:uint256_obj(blockhash)];
    if (terminalBlock && (terminalBlock.height != UINT32_MAX)) {
        return terminalBlock.height;
    }
    
    DSBlock *b = self.lastTerminalBlock;
    
    if (!b) {
        b = self.lastSyncBlock;
    }
    
    @synchronized (self.mTerminalBlocks) {
        while (b && b.height > 0) {
            if (uint256_eq(b.blockHash, blockhash)) {
                return b.height;
            }
            b = self.mTerminalBlocks[b.prevBlockValue];
            if (!b) {
                b = self.mSyncBlocks[b.prevBlockValue];
            }
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

// seconds since reference date, 00:00:00 01/01/01 GMT
// NOTE: this is only accurate for the last two weeks worth of blocks, other timestamps are estimated from checkpoints
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight
{
    if (blockHeight == TX_UNCONFIRMED) return (self.lastTerminalBlock.timestamp) + 2.5*60; //next block
    
    if (blockHeight >= self.lastTerminalBlockHeight) { // future block, assume 2.5 minutes per block after last block
        return (self.lastTerminalBlock.timestamp) + (blockHeight - self.lastTerminalBlockHeight)*2.5*60;
    }
    
    if (_mTerminalBlocks.count > 0) {
        if (blockHeight >= self.lastTerminalBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSBlock *block = self.lastTerminalBlock;
            
            while (block && block.height > blockHeight) block = self.mTerminalBlocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp;
        }
    } else {
        //load blocks
        [self mTerminalBlocks];
    }
    
    uint32_t h = self.lastSyncBlockHeight, t = self.lastSyncBlock.timestamp;
    
    for (long i = self.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpoints[i].height <= blockHeight) {
            if (h == self.checkpoints[i].height) return t;
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp)*
            (blockHeight - self.checkpoints[i].height)/(h - self.checkpoints[i].height);
            return t;
        }
        
        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }
    
    return self.checkpoints[0].timestamp;
}

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray <NSValue*> *)transactionHashes
{
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) _bestBlockHeight = height;
    NSMutableArray *updatedTransactions = [NSMutableArray array];
    if ([transactionHashes count]) {
        //need to reverify this works
        for (NSValue * transactionHash in transactionHashes) {
            [self.transactionHashHeights setObject:@(height) forKey:uint256_data_from_obj(transactionHash)];
        }
        for (NSValue * transactionHash in transactionHashes) {
            [self.transactionHashTimestamps setObject:@(timestamp) forKey:uint256_data_from_obj(transactionHash)];
        }
        for (DSWallet * wallet in self.wallets) {
            [updatedTransactions addObjectsFromArray:[wallet setBlockHeight:height andTimestamp:timestamp
                                                       forTransactionHashes:transactionHashes]];
        }
    } else {
        for (DSWallet * wallet in self.wallets) {
            [wallet chainUpdatedBlockHeight:height];
        }
    }
    
    [self.chainManager chain:self didSetBlockHeight:height andTimestamp:timestamp forTransactionHashes:transactionHashes updatedTransactions:updatedTransactions];
}

-(void)reloadDerivationPaths {
    for (DSWallet * wallet in self.mWallets) {
        if (!wallet.isTransient) { //no need to reload transient wallets (those are for testing purposes)
            [wallet reloadDerivationPaths];
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

// MARK: - Accounts

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

- (DSAccount* _Nullable)accountContainingDashpayExternalDerivationPathAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet accountForDashpayExternalDerivationPathAddress:address];
        if (account) return account;
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)firstAccountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction wallet:(DSWallet **)wallet {
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

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction {
    NSMutableArray * accounts = [NSMutableArray array];
    for (DSWallet * lWallet in self.wallets) {
        for (DSAccount * account in lWallet.accounts) {
            DSTransaction * lTransaction = [account transactionForHash:txHash];
            if (lTransaction) {
                if (transaction) *transaction = lTransaction;
                [accounts addObject:account];
            }
        }
    }
    return [accounts copy];
}

// MARK: - Transactions

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    return [self transactionForHash:txHash returnWallet:nil];
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

-(NSArray <DSTransaction*> *) allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSWallet * wallet in self.wallets) {
        [mArray addObjectsFromArray:wallet.allTransactions];
    }
    return mArray;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t received = 0;
    for (DSWallet * wallet in self.wallets) {
        received += [wallet amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t sent = 0;
    for (DSWallet * wallet in self.wallets) {
        sent += [wallet amountSentByTransaction:transaction];
    }
    return sent;
}

- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction {
    const uint64_t sent = [self amountSentByTransaction:transaction];
    const uint64_t received = [self amountReceivedFromTransaction:transaction];
    const uint64_t fee = transaction.feeUsed;
    
    if (sent > 0 && (received + fee) == sent) {
        // moved
        return DSTransactionDirection_Moved;
    }
    else if (sent > 0) {
        // sent
        return DSTransactionDirection_Sent;
    }
    else if (received > 0) {
        // received
        return DSTransactionDirection_Received;
    } else {
        // no funds moved on this account
        return DSTransactionDirection_NotAccountFunds;
    }
}

// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext*)context {
    for (DSWallet * wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    _mSyncBlocks = nil;
    _mTerminalBlocks = nil;
    _lastSyncBlock = nil;
    _lastTerminalBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastTerminalBlockFromCheckpoints];
    [self setLastSyncBlockFromCheckpoints];
    [self.chainManager chainWasWiped:self];
}

- (void)wipeBlockchainNonTerminalInfoInContext:(NSManagedObjectContext*)context {
    for (DSWallet * wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    _mSyncBlocks = nil;
    _lastSyncBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastSyncBlockFromCheckpoints];
    [self.chainManager chainWasWiped:self];
}

-(void)wipeMasternodesInContext:(NSManagedObjectContext*)context {
    DSChainEntity * chainEntity = [self chainEntityInContext:context];
    [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
    [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
    [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
    [DSMasternodeListEntity deleteAllOnChainEntity:chainEntity];
    [self.chainManager.masternodeManager wipeMasternodeInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",self.uniqueID,LAST_SYNCED_MASTERNODE_LIST]];
}

-(void)wipeWalletsAndDerivatives {
    [self unregisterAllWallets];
    [self unregisterAllStandaloneDerivationPaths];
    self.mWallets = [NSMutableArray array];
    self.viewingAccount = nil;
}

// MARK: - Identities

-(uint32_t)localBlockchainIdentitiesCount {
    uint32_t blockchainIdentitiesCount = 0;
    for (DSWallet * lWallet in self.wallets) {
        blockchainIdentitiesCount += [lWallet blockchainIdentitiesCount];
    }
    return blockchainIdentitiesCount;
}

-(NSArray <DSBlockchainIdentity *>*)localBlockchainIdentities {
    NSMutableArray * rAllBlockchainIdentities = [NSMutableArray array];
    for (DSWallet * wallet in self.wallets) {
        [rAllBlockchainIdentities addObjectsFromArray:[wallet.blockchainIdentities allValues]];
    }
    return rAllBlockchainIdentities;
}

-(NSDictionary <NSData*,DSBlockchainIdentity *>*)localBlockchainIdentitiesByUniqueIdDictionary {
    NSMutableDictionary * rAllBlockchainIdentities = [NSMutableDictionary dictionary];
    for (DSWallet * wallet in self.wallets) {
        for (DSBlockchainIdentity * blockchainIdentity in [wallet.blockchainIdentities allValues]) {
            [rAllBlockchainIdentities setObject:blockchainIdentity forKey:blockchainIdentity.uniqueIDData];
        }
    }
    return rAllBlockchainIdentities;
}


-(DSBlockchainIdentity*)blockchainIdentityForUniqueId:(UInt256)uniqueId {
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
    return [self blockchainIdentityForUniqueId:uniqueId foundInWallet:nil includeForeignBlockchainIdentities:NO];
}

-(DSBlockchainIdentity*)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet**)foundInWallet {
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
    return [self blockchainIdentityForUniqueId:uniqueId foundInWallet:foundInWallet includeForeignBlockchainIdentities:NO];
}

-(DSBlockchainIdentity* _Nullable)blockchainIdentityThatCreatedContract:(DPContract*)contract withContractId:(UInt256)contractId foundInWallet:(DSWallet**)foundInWallet {
    NSAssert(!uint256_is_zero(contractId), @"contractId must not be null");
    for (DSWallet * wallet in self.wallets) {
        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityThatCreatedContract:contract withContractId:contractId];
        if (blockchainIdentity) {
            if (foundInWallet) {
                *foundInWallet = wallet;
            }
            return blockchainIdentity;
        }
    }
    return nil;
}

-(DSBlockchainIdentity*)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet**)foundInWallet includeForeignBlockchainIdentities:(BOOL)includeForeignBlockchainIdentities {
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
    for (DSWallet * wallet in self.wallets) {
        DSBlockchainIdentity * blockchainIdentity = [wallet blockchainIdentityForUniqueId:uniqueId];
        if (blockchainIdentity) {
            if (foundInWallet) {
                *foundInWallet = wallet;
            }
            return blockchainIdentity;
        }
    }
    if (includeForeignBlockchainIdentities) {
        return [self.chainManager.identitiesManager foreignBlockchainIdentityWithUniqueId:uniqueId];
    } else {
        return nil;
    }
}

-(void)wipeBlockchainIdentitiesPersistedDataInContext:(NSManagedObjectContext*)context {
    [context performBlockAndWait:^{
        NSArray * objects = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@",[self chainEntityInContext:context]];
        [DSBlockchainIdentityEntity deleteObjects:objects inContext:context];
    }];
}

// MARK: - Registering special transactions


-(BOOL)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet * ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil];
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil];
    DSWallet * holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil];
    DSAccount * account = [self accountContainingAddress:providerRegistrationTransaction.payoutAddress];
    BOOL registered = NO;
    registered |= [account registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [ownerWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [votingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [operatorWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [holdingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    
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

-(BOOL)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction*)providerUpdateServiceTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    }
    return registered;
}


-(BOOL)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction*)providerUpdateRegistrarTransaction saveImmediately:(BOOL)saveImmediately {
    
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
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

-(BOOL)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction*)providerUpdateRevocationTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        return [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRevocationTransaction saveImmediately:saveImmediately];
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

-(BOOL)registerSpecialTransaction:(DSTransaction*)transaction saveImmediately:(BOOL)saveImmediately {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        return [self registerProviderRegistrationTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        return [self registerProviderUpdateServiceTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        return [self registerProviderUpdateRegistrarTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        return [self registerProviderUpdateRevocationTransaction:providerUpdateRevocationTransaction saveImmediately:saveImmediately];
    }
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
                blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:[creditFundingTransaction usedDerivationPathIndex] withFundingTransaction:creditFundingTransaction withUsernameDictionary:nil inWallet:wallet];
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

- (DSWallet*)walletHavingBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainIdentityCreditFundingTopupHash:creditFundingTopupHash];
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

// MARK: - Persistence

-(DSChainEntity*)chainEntityInContext:(NSManagedObjectContext*)context {
    NSParameterAssert(context);
    __block DSChainEntity* chainEntity = nil;
    [context performBlockAndWait:^{
        chainEntity = [DSChainEntity chainEntityForType:self.chainType devnetIdentifier:self.devnetIdentifier checkpoints:self.checkpoints inContext:context];
    }];
    return chainEntity;
}

-(void)save {
    if (self.isTransient) return;
    [self saveInContext:self.chainManagedObjectContext];
}

-(void)saveInContext:(NSManagedObjectContext*)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSChainEntity * entity = [self chainEntityInContext:context];
        entity.totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        entity.baseBlockHash = [NSData dataWithUInt256:self.masternodeBaseBlockHash];
        [context ds_save];
    }];
}

-(void)saveBlockLocators {
    if (self.isTransient) return;
//    NSAssert(self.chainManager.syncPhase == DSChainSyncPhase_ChainSync || self.chainManager.syncPhase == DSChainSyncPhase_Synced,@"This should only be happening in chain sync phase");
    [self prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:self.lastSyncBlockHeight];
    DSBlock * lastBlock = self.lastSyncBlock;
    UInt256 lastBlockHash = lastBlock.blockHash;
    uint32_t lastBlockHeight = lastBlock.height;
    [self.chainManagedObjectContext performBlockAndWait:^{
        DSChainEntity * chainEntity = [self chainEntityInContext:self.chainManagedObjectContext];
        
        chainEntity.syncBlockHash = uint256_data(lastBlockHash);
        chainEntity.syncBlockHeight = lastBlockHeight;
        chainEntity.syncBlockTimestamp = lastBlock.timestamp;
        NSArray * array = [self chainSyncBlockLocatorArray];
        _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:1425039295 includeInitialTerminalBlocks:NO];
        chainEntity.syncLocators = array?[NSKeyedArchiver archivedDataWithRootObject:array]:nil;
        
        NSMutableSet *entities = [NSMutableSet set];
        
        [self persistIncomingTransactionsAttributesForBlockSaveWithNumber:lastBlockHeight inContext:self.chainManagedObjectContext];
        
        for (DSTransactionHashEntity *e in [DSTransactionHashEntity objectsInContext:self.chainManagedObjectContext matching:@"txHash in %@", [self.transactionHashHeights allKeys]]) {
            e.blockHeight = [self.transactionHashHeights[e.txHash] intValue];
            e.timestamp = [self.transactionHashTimestamps[e.txHash] intValue];;
            [entities addObject:e];
        }
        for (DSTransactionHashEntity *e in entities) {
            DSDLog(@"blockHeight is %u for %@",e.blockHeight,e.txHash);
        }
        self.transactionHashHeights = [NSMutableDictionary dictionary];
        self.transactionHashTimestamps = [NSMutableDictionary dictionary];
        
        [self.chainManagedObjectContext ds_save];
    }];
}

- (void)saveTerminalBlocks
{
    if (self.isTransient) return;
    NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
    DSBlock *b = self.lastTerminalBlock;
    uint32_t endHeight = b.height;
    uint32_t startHeight = b.height;
    while (b && (startHeight > self.lastCheckpoint.height) && (endHeight - startHeight < LLMQ_KEEP_RECENT_BLOCKS)) {
        blocks[[NSData dataWithUInt256:b.blockHash]] = b;
        startHeight = b.height;
        b = self.mTerminalBlocks[b.prevBlockValue];
    }
    if (startHeight == b.height) { //only save last one then
        blocks[[NSData dataWithUInt256:b.blockHash]] = b;
    }
    [self.chainManagedObjectContext performBlockAndWait:^{
        if ([[DSOptionsManager sharedInstance] keepHeaders]) {
            //only remove orphan chains
            NSArray<DSMerkleBlockEntity *> * recentOrphans = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && (height > %u) && !(blockHash in %@)",[self chainEntityInContext:self.chainManagedObjectContext],startHeight,blocks.allKeys];
            if ([recentOrphans count])  DSDLog(@"%lu recent orphans will be removed from disk",(unsigned long)[recentOrphans count]);
            [DSMerkleBlockEntity deleteObjects:recentOrphans inContext:self.chainManagedObjectContext];
        } else {
            //remember to not delete blocks needed for quorums
            NSArray<DSMerkleBlockEntity *> * oldBlockHeaders = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && masternodeList == NIL && (usedByQuorums.@count == 0) && !(blockHash in %@)",[self chainEntityInContext:self.chainManagedObjectContext],blocks.allKeys];
            [DSMerkleBlockEntity deleteObjects:oldBlockHeaders inContext:self.chainManagedObjectContext];
        }
        DSChainEntity * chainEntity = [self chainEntityInContext:self.chainManagedObjectContext];
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"blockHash in %@",blocks.allKeys]) {
            @autoreleasepool {
                [e setAttributesFromBlock:blocks[e.blockHash] forChainEntity:chainEntity];
                [blocks removeObjectForKey:e.blockHash];
            }
        }
        
        for (DSBlock *block in blocks.allValues) {
            @autoreleasepool {
                DSMerkleBlockEntity * e = [DSMerkleBlockEntity managedObjectInContext:self.chainManagedObjectContext];
                [e setAttributesFromBlock:block forChainEntity:chainEntity];
            }
        }
        
        [self.chainManagedObjectContext ds_save];
    }];
}

// MARK: Persistence Helpers

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    for (DSWallet * wallet in self.wallets) {
        [wallet prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
    }
}

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext*)context {
    for (DSWallet * wallet in self.wallets) {
        [wallet persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber inContext:context];
    }
}


// MARK: - Description

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}",self.name]];
}

@end

