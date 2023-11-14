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

#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSBIP39Mnemonic.h"
#import "DSBlock+Protected.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainInvitation+Protected.h"
#import "DSBloomFilter.h"
#import "DSChain+Protected.h"
#import "DSChainCheckpoints.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSChainsManager.h"
#import "DSCheckpoint.h"
#import "DSCreditFundingTransaction.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSDerivationPathFactory.h"
#import "DSEventManager.h"
#import "DSFullBlock.h"
#import "DSFundsDerivationPath.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSInsightManager.h"
#import "DSKeyManager.h"
#import "DSLocalMasternode+Protected.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerManager.h"
#import "DSPriceManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"
#import "DSQuorumSnapshotEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSSporkManager.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"
#import "DSTransition.h"
#import "DSWallet+Protected.h"
#import "NSCoder+Dash.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

#define FEE_PER_BYTE_KEY @"FEE_PER_BYTE"

#define CHAIN_WALLETS_KEY @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY @"REGISTERED_PEERS_KEY"

#define PROTOCOL_VERSION_LOCATION @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"MIN_PROTOCOL_VERSION_LOCATION"

#define PLATFORM_PROTOCOL_VERSION_LOCATION @"PLATFORM_PROTOCOL_VERSION_LOCATION"
#define PLATFORM_DEFAULT_MIN_PROTOCOL_VERSION_LOCATION @"PLATFORM_MIN_PROTOCOL_VERSION_LOCATION"

#define ISLOCK_QUORUM_TYPE @"ISLOCK_QUORUM_TYPE"
#define ISDLOCK_QUORUM_TYPE @"ISDLOCK_QUORUM_TYPE"
#define CHAINLOCK_QUORUM_TYPE @"CHAINLOCK_QUORUM_TYPE"
#define PLATFORM_QUORUM_TYPE @"PLATFORM_QUORUM_TYPE"

#define STANDARD_PORT_LOCATION @"STANDARD_PORT_LOCATION"
#define JRPC_PORT_LOCATION @"JRPC_PORT_LOCATION"
#define GRPC_PORT_LOCATION @"GRPC_PORT_LOCATION"

#define DPNS_CONTRACT_ID @"DPNS_CONTRACT_ID"
#define DASHPAY_CONTRACT_ID @"DASHPAY_CONTRACT_ID"

#define MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY @"MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY"

#define SPORK_PUBLIC_KEY_LOCATION @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION @"SPORK_PRIVATE_KEY_LOCATION"

#define CHAIN_VOTING_KEYS_KEY @"CHAIN_VOTING_KEYS_KEY"
#define QUORUM_ROTATION_PRESENCE_KEY @"QUORUM_ROTATION_PRESENCE_KEY"

#define LOG_PREV_BLOCKS_ON_ORPHAN 0

#define BLOCK_NO_FORK_DEPTH 25

typedef NS_ENUM(uint16_t, DSBlockPosition)
{
    DSBlockPosition_Orphan = 0,
    DSBlockPosition_Terminal = 1,
    DSBlockPosition_Sync = 2,
    DSBlockPosition_TerminalSync = DSBlockPosition_Terminal | DSBlockPosition_Sync
};

@interface DSChain ()

@property (nonatomic, strong) DSBlock *lastSyncBlock, *lastTerminalBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary<NSValue *, DSBlock *> *mSyncBlocks, *mTerminalBlocks, *mOrphans;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSCheckpoint *> *checkpointsByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DSCheckpoint *> *checkpointsByHeightDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint *> *checkpoints;
@property (nonatomic, copy) NSString *uniqueID;
@property (nonatomic, copy) NSString *networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> *mWallets;
@property (nonatomic, strong) DSAccount *viewingAccount;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<DSPeer *> *> *estimatedBlockHeights;
@property (nonatomic, assign) uint32_t cachedMinimumDifficultyBlocks;
@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;
@property (nonatomic, assign) uint32_t cachedMinProtocolVersion;
@property (nonatomic, assign) uint32_t cachedProtocolVersion;
@property (nonatomic, assign) UInt256 cachedMaxProofOfWork;
@property (nonatomic, assign) uint32_t cachedStandardPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiJRPCPort;
@property (nonatomic, assign) uint32_t cachedStandardDapiGRPCPort;
@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, assign) UInt256 cachedDpnsContractID;
@property (nonatomic, assign) UInt256 cachedDashpayContractID;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashHeights;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashTimestamps;
@property (nonatomic, strong) NSManagedObjectContext *chainManagedObjectContext;
@property (nonatomic, strong) DSCheckpoint *terminalHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint *syncHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint *lastCheckpoint;
@property (nonatomic, assign) NSTimeInterval lastNotifiedBlockDidChange;
@property (nonatomic, strong) NSTimer *lastNotifiedBlockDidChangeTimer;
@property (nonatomic, assign, getter=isTransient) BOOL transient;
@property (nonatomic, assign) BOOL cachedIsQuorumRotationPresented;
@property (nonatomic, readonly) NSString *chainWalletsKey;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.mOrphans = [NSMutableDictionary dictionary];
    self.mSyncBlocks = [NSMutableDictionary dictionary];
    self.mTerminalBlocks = [NSMutableDictionary dictionary];
    self.mWallets = [NSMutableArray array];
    self.estimatedBlockHeights = [NSMutableDictionary dictionary];
    
    self.transactionHashHeights = [NSMutableDictionary dictionary];
    self.transactionHashTimestamps = [NSMutableDictionary dictionary];
    
    self.lastNotifiedBlockDidChange = 0;
    
    if (self.checkpoints) {
        self.genesisHash = self.checkpoints[0].blockHash;
        dispatch_sync(self.networkingQueue, ^{
            self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
        });
    }
    
    self.feePerByte = DEFAULT_FEE_PER_B;
    uint64_t feePerByte = [[NSUserDefaults standardUserDefaults] doubleForKey:FEE_PER_BYTE_KEY];
    if (feePerByte >= MIN_FEE_PER_B && feePerByte <= MAX_FEE_PER_B) self.feePerByte = feePerByte;
    
    return self;
}

- (instancetype)initWithType:(ChainType)type checkpoints:(NSArray *)checkpoints {
    if (!(self = [self init])) return nil;
    NSAssert(!chain_type_is_devnet_any(type), @"DevNet should be configured with initAsDevnetWithIdentifier:version:checkpoints:port:dapiPort:dapiGRPCPort:dpnsContractID:dashpayContractID:");
    _chainType = type;
    self.standardPort = chain_standard_port(type);
    self.standardDapiJRPCPort = chain_standard_dapi_jrpc_port(type);
    self.headersMaxAmount = chain_headers_max_amount(type);
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].blockHash;
    _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
    _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
    
    return self;
}

- (instancetype)initAsDevnetWithIdentifier:(DevnetType)devnetType
                         onProtocolVersion:(uint32_t)protocolVersion
                               checkpoints:(NSArray<DSCheckpoint *> *)checkpoints {
    //for devnet the genesis checkpoint is really the second block
    if (!(self = [self init])) return nil;
    _chainType = chain_type_for_devnet_type(devnetType);
    if (!checkpoints || ![checkpoints count]) {
        DSCheckpoint *genesisCheckpoint = [DSCheckpoint genesisDevnetCheckpoint];
        DSCheckpoint *secondCheckpoint = [self createDevNetGenesisBlockCheckpointForParentCheckpoint:genesisCheckpoint withIdentifier:devnetType onProtocolVersion:protocolVersion];
        self.checkpoints = @[genesisCheckpoint, secondCheckpoint];
        self.genesisHash = secondCheckpoint.blockHash;
    } else {
        self.checkpoints = checkpoints;
        self.genesisHash = checkpoints[1].blockHash;
    }
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
    self.headersMaxAmount = chain_headers_max_amount(_chainType);
    return self;
}

- (instancetype)initAsDevnetWithIdentifier:(DevnetType)devnetType
                           protocolVersion:(uint32_t)protocolVersion
                        minProtocolVersion:(uint32_t)minProtocolVersion
                               checkpoints:(NSArray<DSCheckpoint *> *)checkpoints
                   minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                                      port:(uint32_t)port
                              dapiJRPCPort:(uint32_t)dapiJRPCPort
                              dapiGRPCPort:(uint32_t)dapiGRPCPort
                            dpnsContractID:(UInt256)dpnsContractID
                         dashpayContractID:(UInt256)dashpayContractID
                               isTransient:(BOOL)isTransient {
    //for devnet the genesis checkpoint is really the second block
    if (!(self = [self initAsDevnetWithIdentifier:devnetType onProtocolVersion:protocolVersion checkpoints:checkpoints])) return nil;
    self.standardPort = port;
    self.standardDapiJRPCPort = dapiJRPCPort;
    self.standardDapiGRPCPort = dapiGRPCPort;
    self.dpnsContractID = dpnsContractID;
    self.dashpayContractID = dashpayContractID;
    self.minimumDifficultyBlocks = minimumDifficultyBlocks;
    self.transient = isTransient;
    return self;
}

+ (DSChain *)mainnet {
    static DSChain *_mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:chain_type_from_index(ChainType_MainNet) checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array) / sizeof(*mainnet_checkpoint_array))]];
        inSetUp = TRUE;
    });
    if (inSetUp) {
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity *chainEntity = [_mainnet chainEntityInContext:[NSManagedObjectContext chainContext]];
            _mainnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _mainnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            _mainnet.lastPersistedChainSyncLocators = chainEntity.syncLocators;
            _mainnet.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            _mainnet.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            _mainnet.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
            _mainnet.lastPersistedChainSyncBlockChainWork = chainEntity.syncBlockChainWork.UInt256;
        }];
        [_mainnet setUp];
    }
    return _mainnet;
}

+ (DSChain *)testnet {
    static DSChain *_testnet = nil;
    static dispatch_once_t testnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&testnetToken, ^{
        _testnet = [[DSChain alloc] initWithType:chain_type_from_index(ChainType_TestNet) checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array) / sizeof(*testnet_checkpoint_array))]];
        inSetUp = TRUE;
    });
    if (inSetUp) {
        [[NSManagedObjectContext chainContext] performBlockAndWait:^{
            DSChainEntity *chainEntity = [_testnet chainEntityInContext:[NSManagedObjectContext chainContext]];
            _testnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _testnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
            _testnet.lastPersistedChainSyncLocators = chainEntity.syncLocators;
            _testnet.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
            _testnet.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
            _testnet.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
            _testnet.lastPersistedChainSyncBlockChainWork = chainEntity.syncBlockChainWork.UInt256;
        }];
        [_testnet setUp];
    }
    return _testnet;
}

static NSMutableDictionary *_devnetDictionary = nil;
static dispatch_once_t devnetToken = 0;

+ (DSChain *)devnetWithIdentifier:(NSString *)identifier {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain *devnetChain = [_devnetDictionary objectForKey:identifier];
    return devnetChain;
}

+ (DSChain *)recoverKnownDevnetWithIdentifier:(DevnetType)devnetType withCheckpoints:(NSArray<DSCheckpoint *> *)checkpointArray performSetup:(BOOL)performSetup {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain *devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        NSString *devnetIdentifier = [DSKeyManager NSStringFrom:chain_devnet_identifier(devnetType)];
        if (![_devnetDictionary objectForKey:devnetIdentifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:devnetType onProtocolVersion:PROTOCOL_VERSION_DEVNET checkpoints:checkpointArray];
            _devnetDictionary[devnetIdentifier] = devnetChain;
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:devnetIdentifier];
        }
    }
    if (inSetUp) {
        [devnetChain updateDevnetChainFromContext];
        if (performSetup) {
            [devnetChain setUp];
        }
    }
    return devnetChain;
}

+ (DSChain *)setUpDevnetWithIdentifier:(DevnetType)devnetType
                       protocolVersion:(uint32_t)protocolVersion
                    minProtocolVersion:(uint32_t)minProtocolVersion
                       withCheckpoints:(NSArray<DSCheckpoint *> *_Nullable)checkpointArray
           withMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                       withDefaultPort:(uint32_t)port
               withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort
               withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort
                        dpnsContractID:(UInt256)dpnsContractID
                     dashpayContractID:(UInt256)dashpayContractID
                           isTransient:(BOOL)isTransient {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain *devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        NSString *devnetIdentifier = [DSKeyManager NSStringFrom:chain_devnet_identifier(devnetType)];
        if (![_devnetDictionary objectForKey:devnetIdentifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:devnetType protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion checkpoints:checkpointArray minimumDifficultyBlocks:minimumDifficultyBlocks port:port dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID isTransient:isTransient];
            _devnetDictionary[devnetIdentifier] = devnetChain;
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:devnetIdentifier];
        }
    }
    if (inSetUp && !isTransient) {
        // note: there is no point to load anything if the chain is transient
        [devnetChain updateDevnetChainFromContext];
        [devnetChain setUp];
    }
    return devnetChain;
}

- (void)updateDevnetChainFromContext {
    [[NSManagedObjectContext chainContext] performBlockAndWait:^{
        DSChainEntity *chainEntity = [self chainEntityInContext:[NSManagedObjectContext chainContext]];
        self.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
        self.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        self.lastPersistedChainSyncLocators = chainEntity.syncLocators;
        self.lastPersistedChainSyncBlockHeight = chainEntity.syncBlockHeight;
        self.lastPersistedChainSyncBlockHash = chainEntity.syncBlockHash.UInt256;
        self.lastPersistedChainSyncBlockTimestamp = chainEntity.syncBlockTimestamp;
        self.lastPersistedChainSyncBlockChainWork = chainEntity.syncBlockChainWork.UInt256;
    }];
}

+ (DSChain *)chainForNetworkName:(NSString *)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

- (void)setUp {
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
}

// MARK: - Helpers

- (BOOL)isCore19Active {
    return self.lastTerminalBlockHeight >= chain_core19_activation_height(self.chainType);
}

- (KeyKind)activeBLSType {
    return [self isCore19Active] ? KeyKind_BLSBasic : KeyKind_BLS;
}

- (NSDictionary<NSValue *, DSBlock *> *)syncBlocks {
    return [self.mSyncBlocks copy];
}

- (NSDictionary<NSValue *, DSBlock *> *)mainChainSyncBlocks {
    NSMutableDictionary *mainChainSyncBlocks = [self.mSyncBlocks mutableCopy];
    [mainChainSyncBlocks removeObjectsForKeys:[[self forkChainsSyncBlocks] allKeys]];
    return mainChainSyncBlocks;
}

- (NSDictionary<NSValue *, DSBlock *> *)forkChainsSyncBlocks {
    NSMutableDictionary *forkChainsSyncBlocks = [self.mSyncBlocks mutableCopy];
    DSBlock *b = self.lastSyncBlock;
    NSUInteger count = 0;
    while (b && b.height > 0) {
        b = self.mSyncBlocks[b.prevBlockValue];
        [forkChainsSyncBlocks removeObjectForKey:uint256_obj(b.blockHash)];
        count++;
    }
    return forkChainsSyncBlocks;
}

- (NSDictionary<NSValue *, DSBlock *> *)terminalBlocks {
    return [self.mTerminalBlocks copy];
}

- (NSDictionary<NSValue *, DSBlock *> *)mainChainTerminalBlocks {
    NSMutableDictionary *mainChainTerminalBlocks = [self.mTerminalBlocks mutableCopy];
    [mainChainTerminalBlocks removeObjectsForKeys:[[self forkChainsTerminalBlocks] allKeys]];
    return mainChainTerminalBlocks;
}

- (NSDictionary<NSValue *, DSBlock *> *)forkChainsTerminalBlocks {
    NSMutableDictionary *forkChainsTerminalBlocks = [self.mTerminalBlocks mutableCopy];
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    while (b && b.height > 0) {
        b = self.mTerminalBlocks[b.prevBlockValue];
        [forkChainsTerminalBlocks removeObjectForKey:uint256_obj(b.blockHash)];
        count++;
    }
    return forkChainsTerminalBlocks;
}

- (NSDictionary<NSValue *, DSBlock *> *)orphans {
    return [self.mOrphans copy];
}

- (DSChainManager *)chainManager {
    if (_chainManager) return _chainManager;
    return [[DSChainsManager sharedInstance] chainManagerForChain:self];
}

- (DSKeyManager *)keyManager {
    return [[self chainManager] keyManager];
}

+ (NSMutableArray *)createCheckpointsArrayFromCheckpoints:(checkpoint *)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray *checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i < checkpointCount; i++) {
        checkpoint cpt = checkpoints[i];
        NSString *merkleRootString = [NSString stringWithCString:cpt.merkleRoot encoding:NSUTF8StringEncoding];
        NSString *chainWorkString = [NSString stringWithCString:cpt.chainWork encoding:NSUTF8StringEncoding];
        uint32_t blockHeight = cpt.height;
        UInt256 blockHash = [NSString stringWithCString:cpt.checkpointHash encoding:NSUTF8StringEncoding].hexToData.reverse.UInt256;
        UInt256 chainWork = chainWorkString.hexToData.reverse.UInt256;
        UInt256 merkleRoot = [merkleRootString isEqualToString:@""] ? UINT256_ZERO : merkleRootString.hexToData.reverse.UInt256;
        DSCheckpoint *checkpoint = [DSCheckpoint checkpointForHeight:blockHeight blockHash:blockHash timestamp:cpt.timestamp target:cpt.target merkleRoot:merkleRoot chainWork:chainWork masternodeListName:[NSString stringWithCString:cpt.masternodeListPath encoding:NSUTF8StringEncoding]];
        [checkpointMutableArray addObject:checkpoint];
    }
    return [checkpointMutableArray copy];
}

- (BOOL)isEqual:(id)obj {
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], _genesisHash));
}

- (NSUInteger)hash {
    return self.genesisHash.u64[0];
}

// MARK: Devnet Helpers

- (UInt256)blockHashForDevNetGenesisBlockWithVersion:(uint32_t)version prevHash:(UInt256)prevHash merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce {
    NSMutableData *d = [NSMutableData data];
    [d appendUInt32:version];
    [d appendBytes:&prevHash length:sizeof(prevHash)];
    [d appendBytes:&merkleRoot length:sizeof(merkleRoot)];
    [d appendUInt32:timestamp];
    [d appendUInt32:target];
    [d appendUInt32:nonce];
    return [DSKeyManager x11:d];
}

- (DSCheckpoint *)createDevNetGenesisBlockCheckpointForParentCheckpoint:(DSCheckpoint *)checkpoint withIdentifier:(DevnetType)identifier onProtocolVersion:(uint32_t)protocolVersion {
    uint32_t nTime = checkpoint.timestamp + 1;
    uint32_t nBits = checkpoint.target;
    UInt256 fullTarget = setCompactLE(nBits);
    uint32_t nVersion = 4;
    UInt256 prevHash = checkpoint.blockHash;
    UInt256 merkleRoot = [DSTransaction devnetGenesisCoinbaseTxHash:identifier onProtocolVersion:protocolVersion forChain:self];
    UInt256 chainWork = @"0400000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    uint32_t nonce = UINT32_MAX; //+1 => 0;
    UInt256 blockhash;
    do {
        nonce++; //should start at 0;
        blockhash = [self blockHashForDevNetGenesisBlockWithVersion:nVersion prevHash:prevHash merkleRoot:merkleRoot timestamp:nTime target:nBits nonce:nonce];
    } while (nonce < UINT32_MAX && uint256_sup(blockhash, fullTarget));
    DSCheckpoint *block2Checkpoint = [DSCheckpoint checkpointForHeight:1 blockHash:blockhash timestamp:nTime target:nBits merkleRoot:merkleRoot chainWork:chainWork masternodeListName:nil];
    return block2Checkpoint;
}

- (dispatch_queue_t)networkingQueue {
    if (!_networkingQueue) {
        NSAssert(uint256_is_not_zero(self.genesisHash), @"genesisHash must be set");
        _networkingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.network.%@", self.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return _networkingQueue;
}

- (dispatch_queue_t)dapiMetadataQueue {
    if (!_dapiMetadataQueue) {
        NSAssert(uint256_is_not_zero(self.genesisHash), @"genesisHash must be set");
        _dapiMetadataQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.dapimeta.%@", self.uniqueID] UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return _dapiMetadataQueue;
}

// MARK: - Check Type

- (BOOL)isMainnet {
    return self.chainType.tag == ChainType_MainNet;
}

- (BOOL)isTestnet {
    return self.chainType.tag == ChainType_TestNet;
}

- (BOOL)isDevnetAny {
    return chain_type_is_devnet_any(self.chainType);
}

- (BOOL)isEvolutionEnabled {
    return NO;
    //    return [self isDevnetAny] || [self isTestnet];
}

- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    return chain_type_is_devnet_any(self.chainType) && uint256_eq([self genesisHash], genesisHash);
}

// MARK: - Keychain Strings

- (NSString *)chainWalletsKey {
    return [NSString stringWithFormat:@"%@_%@", CHAIN_WALLETS_KEY, [self uniqueID]];
}

- (NSString *)chainStandaloneDerivationPathsKey {
    return [NSString stringWithFormat:@"%@_%@", CHAIN_STANDALONE_DERIVATIONS_KEY, [self uniqueID]];
}

- (NSString *)registeredPeersKey {
    return [NSString stringWithFormat:@"%@_%@", REGISTERED_PEERS_KEY, [self uniqueID]];
}

- (NSString *)votingKeysKey {
    return [NSString stringWithFormat:@"%@_%@", CHAIN_VOTING_KEYS_KEY, [self uniqueID]];
}


// MARK: - Names and Identifiers

- (NSString *)uniqueID {
    if (!_uniqueID) {
        _uniqueID = [[NSData dataWithUInt256:[self genesisHash]] shortHexString];
    }
    return _uniqueID;
}


- (NSString *)networkName {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return @"main";
        case ChainType_TestNet:
            return @"test";
        case ChainType_DevNet:
            if (_networkName) return _networkName;
            return @"dev";
    }
    if (_networkName) return _networkName;
}

- (NSString *)name {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return @"Mainnet";
        case ChainType_TestNet:
            return @"Testnet";
        case ChainType_DevNet:
            if (_networkName) return _networkName;
            return [NSString stringWithFormat:@"Devnet - %@.%u", [DSKeyManager devnetIdentifierFor:self.chainType], devnet_version_for_chain_type(self.chainType)];
    }
    if (_networkName) return _networkName;
}

- (NSString *)localizedName {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return DSLocalizedString(@"Mainnet", nil);
        case ChainType_TestNet:
            return DSLocalizedString(@"Testnet", nil);
        case ChainType_DevNet:
            if (_networkName) return _networkName;
            return [NSString stringWithFormat:@"%@ - %@.%u", DSLocalizedString(@"Devnet", nil), [DSKeyManager devnetIdentifierFor:self.chainType], devnet_version_for_chain_type(self.chainType)];
    }
    if (_networkName) return _networkName;
}

- (void)setDevnetNetworkName:(NSString *)networkName {
    if (chain_type_is_devnet_any(self.chainType)) {
        _networkName = @"Evonet";
    }
}

// MARK: - L1 Chain Parameters

// MARK: Local Parameters

- (NSArray<DSDerivationPath *> *)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    if (accountNumber == 0) {
        return @[[DSFundsDerivationPath bip32DerivationPathForAccountNumber:accountNumber onChain:self], [DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self], [DSDerivationPath masterBlockchainIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self]];
    } else {
        //don't include BIP32 derivation path on higher accounts
        return @[[DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self], [DSDerivationPath masterBlockchainIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self]];
    }
}

- (uint16_t)transactionVersion {
    return chain_transaction_version(self.chainType);
}

- (uintptr_t)peerMisbehavingThreshold {
    return chain_peer_misbehaving_threshold(self.chainType);
}

- (BOOL)syncsBlockchain { //required for SPV wallets
    return ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_NeedsWalletSyncType) != 0;
}

- (BOOL)needsInitialTerminalHeadersSync {
    return !(self.estimatedBlockHeight == self.lastTerminalBlockHeight);
}

// This is a time interval since 1970
- (NSTimeInterval)earliestWalletCreationTime {
    if (![self.wallets count]) return BIP39_CREATION_TIME;
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    for (DSWallet *wallet in self.wallets) {
        if (timeInterval > wallet.walletCreationTime) {
            timeInterval = wallet.walletCreationTime;
        }
    }
    return timeInterval;
}

- (NSTimeInterval)startSyncFromTime {
    if ([self syncsBlockchain]) {
        return [self earliestWalletCreationTime];
    } else {
        return self.checkpoints.lastObject.timestamp;
    }
}

- (NSString *)chainTip {
    return [NSData dataWithUInt256:self.lastTerminalBlock.blockHash].shortHexString;
}

// MARK: Sync Parameters

- (uint32_t)magicNumber {
    return chain_magic_number(_chainType);
}

- (uint32_t)protocolVersion {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case ChainType_TestNet:
            return PROTOCOL_VERSION_TESTNET;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t protocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], &error);
            if (!error && protocolVersion)
                return protocolVersion;
            else
                return PROTOCOL_VERSION_DEVNET;
        }
    }
}

- (void)setProtocolVersion:(uint32_t)protocolVersion {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainInt(protocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (BOOL)isRotatedQuorumsPresented {
    if (_cachedIsQuorumRotationPresented) return _cachedIsQuorumRotationPresented;
    switch (self.chainType.tag) {
        case ChainType_MainNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
        case ChainType_TestNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
        case ChainType_DevNet: {
            NSError *error = nil;
            BOOL isPresented = (BOOL)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], &error);
            _cachedIsQuorumRotationPresented = !error && isPresented;
            break;
        }
    }
    return _cachedIsQuorumRotationPresented;
}


- (void)setIsRotatedQuorumsPresented:(BOOL)isRotatedQuorumsPresented {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"MAINNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case ChainType_TestNet:
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"TESTNET_%@", QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        case ChainType_DevNet: {
            setKeychainInt(isRotatedQuorumsPresented, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], QUORUM_ROTATION_PRESENCE_KEY], NO);
            break;
        }
    }
    _cachedIsQuorumRotationPresented = isRotatedQuorumsPresented;
}

- (uint32_t)minProtocolVersion {
    @synchronized(self) {
        if (_cachedMinProtocolVersion) return _cachedMinProtocolVersion;
        switch (self.chainType.tag) {
            case ChainType_MainNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_MAINNET;
                break;
            }
            case ChainType_TestNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_TESTNET;
                break;
            }
            case ChainType_DevNet: {
                NSError *error = nil;
                uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
                if (!error && minProtocolVersion)
                    _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
                else
                    _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_DEVNET;
                break;
            }
        }
        return _cachedMinProtocolVersion;
    }
}


- (void)setMinProtocolVersion:(uint32_t)minProtocolVersion {
    @synchronized(self) {
        if (minProtocolVersion < MIN_VALID_MIN_PROTOCOL_VERSION || minProtocolVersion > MAX_VALID_MIN_PROTOCOL_VERSION) return;
        switch (self.chainType.tag) {
            case ChainType_MainNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET), [NSString stringWithFormat:@"MAINNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
                break;
            case ChainType_TestNet:
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET), [NSString stringWithFormat:@"TESTNET_%@", DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
                break;
            case ChainType_DevNet: {
                setKeychainInt(MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
                _cachedMinProtocolVersion = MAX(minProtocolVersion, DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
                break;
            }
        }
    }
}

- (uint32_t)standardPort {
    if (_cachedStandardPort) return _cachedStandardPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardPort = MAINNET_STANDARD_PORT;
            return MAINNET_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardPort = TESTNET_STANDARD_PORT;
            return TESTNET_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], &error);
            if (!error && cachedStandardPort) {
                _cachedStandardPort = cachedStandardPort;
                return _cachedStandardPort;
            }
            return DEVNET_STANDARD_PORT;
        }
    }
}

- (void)setStandardPort:(uint32_t)standardPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardPort = standardPort;
        setKeychainInt(standardPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], STANDARD_PORT_LOCATION], NO);
    }
}

- (uint32_t)standardDapiGRPCPort {
    if (_cachedStandardDapiGRPCPort) return _cachedStandardDapiGRPCPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardDapiGRPCPort = MAINNET_DAPI_GRPC_STANDARD_PORT;
            return MAINNET_DAPI_GRPC_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardDapiGRPCPort = TESTNET_DAPI_GRPC_STANDARD_PORT;
            return TESTNET_DAPI_GRPC_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiGRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiGRPCPort) {
                _cachedStandardDapiGRPCPort = cachedStandardDapiGRPCPort;
                return _cachedStandardDapiGRPCPort;
            } else
                return DEVNET_DAPI_GRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiGRPCPort:(uint32_t)standardDapiGRPCPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardDapiGRPCPort = standardDapiGRPCPort;
        setKeychainInt(standardDapiGRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], GRPC_PORT_LOCATION], NO);
    }
}

// MARK: Mining and Dark Gravity Wave Parameters

- (UInt256)maxProofOfWork {
    if (uint256_is_not_zero(_cachedMaxProofOfWork)) return _cachedMaxProofOfWork;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_MAINNET;
            break;
        case ChainType_TestNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_TESTNET;
            break;
        case ChainType_DevNet:
            _cachedMaxProofOfWork = MAX_PROOF_OF_WORK_DEVNET;
            break;
    }
    return _cachedMaxProofOfWork;
}

- (uint32_t)maxProofOfWorkTarget {
    return chain_max_proof_of_work_target(self.chainType);
}

- (BOOL)allowMinDifficultyBlocks {
    return chain_allow_min_difficulty_blocks(self.chainType);
}

- (uint64_t)baseReward {
    if (self.chainType.tag == ChainType_MainNet) return 5 * DUFFS;
    return 50 * DUFFS;
}

// MARK: Spork Parameters

- (NSString *)sporkPublicKeyHexString {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
        case ChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PUBLIC_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
    }
    return nil;
}

- (void)setSporkPublicKeyHexString:(NSString *)sporkPublicKey {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPublicKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PUBLIC_KEY_LOCATION], NO);
    }
}

- (NSString *)sporkPrivateKeyBase58String {
    if (chain_type_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], &error);
        if (!error && publicKey) {
            return publicKey;
        }
    }
    return nil;
}

- (void)setSporkPrivateKeyBase58String:(NSString *)sporkPrivateKey {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkPrivateKey, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_PRIVATE_KEY_LOCATION], YES);
    }
}

- (NSString *)sporkAddress {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return SPORK_ADDRESS_MAINNET;
        case ChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSString *publicKey = getKeychainString([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_ADDRESS_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
    }
    return nil;
}

- (void)setSporkAddress:(NSString *)sporkAddress {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainString(sporkAddress, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], SPORK_ADDRESS_LOCATION], NO);
    }
}

// MARK: Fee Parameters

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size {
    uint64_t standardFee = size * TX_FEE_PER_B; //!OCLINT // standard fee based on tx size
#if (!!FEE_PER_KB_URL)
    uint64_t fee = ((size * self.feePerByte + 99) / 100) * 100; // fee using feePerByte, rounded up to nearest 100 satoshi
    return (fee > standardFee) ? fee : standardFee;
#else
    return standardFee;
#endif
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount {
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT * self.feePerByte + MIN_FEE_PER_B - 1) / MIN_FEE_PER_B;
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}

// MARK: - L2 Chain Parameters

- (uint32_t)platformProtocolVersion {
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            return PLATFORM_PROTOCOL_VERSION_MAINNET; //(70216 + (self.headersMaxAmount / 2000));
        case ChainType_TestNet:
            return PLATFORM_PROTOCOL_VERSION_TESTNET;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t platformProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PLATFORM_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && platformProtocolVersion)
                return platformProtocolVersion;
            else
                return PLATFORM_PROTOCOL_VERSION_DEVNET;
        }
    }
}

- (void)setPlatformProtocolVersion:(uint32_t)platformProtocolVersion {
    if (chain_type_is_devnet_any(self.chainType)) {
        setKeychainInt(platformProtocolVersion, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], PLATFORM_PROTOCOL_VERSION_LOCATION], NO);
    }
}

- (UInt256)dpnsContractID {
    if (uint256_is_not_zero(_cachedDpnsContractID)) return _cachedDpnsContractID;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = MAINNET_DPNS_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDpnsContractID;
        case ChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDpnsContractID = TESTNET_DPNS_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDpnsContractID;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSData *cachedDpnsContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID], &error);
            if (!error && cachedDpnsContractIDData) {
                _cachedDpnsContractID = cachedDpnsContractIDData.UInt256;
                return _cachedDpnsContractID;
            }
            return UINT256_ZERO;
        }
    }
}

- (void)setDpnsContractID:(UInt256)dpnsContractID {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedDpnsContractID = dpnsContractID;
        if (uint256_is_zero(dpnsContractID)) {
            NSError *error = nil;
            NSString *identifier = [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID];
            BOOL hasDashpayContractID = (getKeychainData(identifier, &error) != nil);
            if (hasDashpayContractID) {
                setKeychainData(nil, identifier, NO);
            }
        } else {
            setKeychainData(uint256_data(dpnsContractID), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DPNS_CONTRACT_ID], NO);
        }
    }
}

- (UInt256)dashpayContractID {
    if (uint256_is_not_zero(_cachedDashpayContractID)) return _cachedDashpayContractID;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = MAINNET_DASHPAY_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDashpayContractID;
        case ChainType_TestNet:
            if (!self.isEvolutionEnabled) return UINT256_ZERO;
            _cachedDashpayContractID = TESTNET_DASHPAY_CONTRACT_ID.base58ToData.UInt256;
            return _cachedDashpayContractID;
        case ChainType_DevNet: {
            NSError *error = nil;
            NSData *cachedDashpayContractIDData = getKeychainData([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID], &error);
            if (!error && cachedDashpayContractIDData) {
                _cachedDashpayContractID = cachedDashpayContractIDData.UInt256;
                return _cachedDashpayContractID;
            }
            return UINT256_ZERO;
        }
    }
}

- (void)setDashpayContractID:(UInt256)dashpayContractID {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedDashpayContractID = dashpayContractID;
        if (uint256_is_zero(dashpayContractID)) {
            NSError *error = nil;
            NSString *identifier = [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID];
            BOOL hasDashpayContractID = (getKeychainData(identifier, &error) != nil);
            if (hasDashpayContractID) {
                setKeychainData(nil, identifier, NO);
            }
        } else {
            setKeychainData(uint256_data(dashpayContractID), [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], DASHPAY_CONTRACT_ID], NO);
        }
    }
}

- (void)setMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedMinimumDifficultyBlocks = minimumDifficultyBlocks;
        setKeychainInt(minimumDifficultyBlocks, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], NO);
    }
}

- (uint32_t)minimumDifficultyBlocks {
    if (_cachedMinimumDifficultyBlocks) return _cachedMinimumDifficultyBlocks;
    if (chain_type_is_devnet_any(self.chainType)) {
        NSError *error = nil;
        uint32_t cachedMinimumDifficultyBlocks = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], MINIMUM_DIFFICULTY_BLOCKS_COUNT_KEY], &error);
        if (!error && cachedMinimumDifficultyBlocks) {
            _cachedMinimumDifficultyBlocks = cachedMinimumDifficultyBlocks;
            return _cachedMinimumDifficultyBlocks;
        } else {
            return 0;
        }
    } else {
        _cachedMinimumDifficultyBlocks = 0;
        return 0;
    }
}


- (uint32_t)standardDapiJRPCPort {
    if (_cachedStandardDapiJRPCPort) return _cachedStandardDapiJRPCPort;
    switch (self.chainType.tag) {
        case ChainType_MainNet:
            _cachedStandardDapiJRPCPort = MAINNET_DAPI_JRPC_STANDARD_PORT;
            return MAINNET_DAPI_JRPC_STANDARD_PORT;
        case ChainType_TestNet:
            _cachedStandardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
            return TESTNET_DAPI_JRPC_STANDARD_PORT;
        case ChainType_DevNet: {
            NSError *error = nil;
            uint32_t cachedStandardDapiJRPCPort = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], &error);
            if (!error && cachedStandardDapiJRPCPort) {
                _cachedStandardDapiJRPCPort = cachedStandardDapiJRPCPort;
                return _cachedStandardDapiJRPCPort;
            } else
                return DEVNET_DAPI_JRPC_STANDARD_PORT;
        }
    }
}

- (void)setStandardDapiJRPCPort:(uint32_t)standardDapiJRPCPort {
    if (chain_type_is_devnet_any(self.chainType)) {
        _cachedStandardDapiJRPCPort = standardDapiJRPCPort;
        setKeychainInt(standardDapiJRPCPort, [NSString stringWithFormat:@"%@%@", [DSKeyManager devnetIdentifierFor:self.chainType], JRPC_PORT_LOCATION], NO);
    }
}

// MARK: - Standalone Derivation Paths

- (BOOL)hasAStandaloneDerivationPath {
    return [self.viewingAccount.fundDerivationPaths count] > 0;
}

- (DSAccount *)viewingAccount {
    if (_viewingAccount) return _viewingAccount;
    self.viewingAccount = [[DSAccount alloc] initAsViewOnlyWithAccountNumber:0 withDerivationPaths:@[] inContext:self.chainManagedObjectContext];
    return _viewingAccount;
}

- (void)retrieveStandaloneDerivationPaths {
    NSError *error = nil;
    NSArray *standaloneIdentifiers = getKeychainArray(self.chainStandaloneDerivationPathsKey, @[[NSString class]], &error);
    if (!error) {
        for (NSString *derivationPathIdentifier in standaloneIdentifiers) {
            DSDerivationPath *derivationPath = [[DSDerivationPath alloc] initWithExtendedPublicKeyIdentifier:derivationPathIdentifier onChain:self];
            if (derivationPath) {
                [self addStandaloneDerivationPath:derivationPath];
            }
        }
    }
}

- (void)unregisterAllStandaloneDerivationPaths {
    for (DSDerivationPath *standaloneDerivationPath in [self.viewingAccount.fundDerivationPaths copy]) {
        [self unregisterStandaloneDerivationPath:standaloneDerivationPath];
    }
}

- (void)unregisterStandaloneDerivationPath:(DSDerivationPath *)derivationPath {
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) return;
    [keyChainArray removeObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    [self.viewingAccount removeDerivationPath:derivationPath];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
    });
}
- (void)addStandaloneDerivationPath:(DSDerivationPath *)derivationPath {
    [self.viewingAccount addDerivationPath:derivationPath];
}

- (void)registerStandaloneDerivationPath:(DSDerivationPath *)derivationPath {
    if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]] && ![self.viewingAccount.fundDerivationPaths containsObject:(DSFundsDerivationPath *)derivationPath]) {
        [self addStandaloneDerivationPath:derivationPath];
    }
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray addObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
    });
}

- (NSArray *)standaloneDerivationPaths {
    return [self.viewingAccount fundDerivationPaths];
}

// MARK: - Probabilistic Filters

- (DSBloomFilter *)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak {
    NSMutableSet *allAddresses = [NSMutableSet set];
    NSMutableSet *allUTXOs = [NSMutableSet set];
    for (DSWallet *wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL unusedAccountGapLimit:SEQUENCE_UNUSED_GAP_LIMIT_INITIAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL internal:NO error:nil];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL unusedAccountGapLimit:SEQUENCE_UNUSED_GAP_LIMIT_INITIAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL internal:YES error:nil];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddresses addObjectsFromArray:[addresses allObjects]];
        [allUTXOs addObjectsFromArray:wallet.unspentOutputs];
        
        //we should also add the blockchain user public keys to the filter
        //[allAddresses addObjectsFromArray:[wallet blockchainIdentityAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerOwnerAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerVotingAddresses]];
        [allAddresses addObjectsFromArray:[wallet providerOperatorAddresses]];
        [allAddresses addObjectsFromArray:[wallet platformNodeAddresses]];
    }
    
    for (DSFundsDerivationPath *derivationPath in self.standaloneDerivationPaths) {
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
    
    for (DSWallet *wallet in self.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            if (tx.blockHeight != TX_UNCONFIRMED && tx.blockHeight + 100 < self.lastSyncBlockHeight) {
                //DSLog(@"Not adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
                continue; // the transaction is confirmed for at least 100 blocks, then break
            }
            
            //DSLog(@"Adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
            
            i = 0;
            
            for (DSTransactionInput *input in tx.inputs) {
                o = (DSUTXO){input.inputHash, input.index};
                DSTransaction *t = [wallet transactionForHash:o.hash];
                if (o.n < t.outputs.count && [wallet containsAddress:t.outputs[o.n].address]) {
                    [inputs addObject:dsutxo_data(o)];
                    elemCount++;
                }
            }
        }
    }
    
    DSBloomFilter *filter = [[DSBloomFilter alloc] initWithFalsePositiveRate:falsePositiveRate
                                                             forElementCount:(elemCount < 200 ? 300 : elemCount + 100)
                                                                       tweak:tweak
                                                                       flags:BLOOM_UPDATE_ALL];
    
    for (NSString *addr in allAddresses) {                    // add addresses to watch for tx receiveing money to the wallet
        if (![addr isKindOfClass:[NSString class]]) continue; //sanity check against [NSNull null] (these would be addresses that are not loaded because they were not in the gap limit, but addresses after them existed)
        NSData *hash = addr.addressToHash160;
        
        if (hash && ![filter containsData:hash]) [filter insertData:hash];
    }
    
    for (NSValue *utxo in allUTXOs) { // add UTXOs to watch for tx sending money from the wallet
        [utxo getValue:&o];
        d = dsutxo_data(o);
        if (![filter containsData:d]) [filter insertData:d];
    }
    
    for (d in inputs) { // also add TXOs spent within the last 100 blocks
        if (![filter containsData:d]) [filter insertData:d];
    }
    return filter;
}

- (BOOL)canConstructAFilter {
    return [self hasAStandaloneDerivationPath] || [self hasAWallet];
}

// MARK: - Checkpoints

- (BOOL)blockHeightHasCheckpoint:(uint32_t)blockHeight {
    DSCheckpoint *checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    return (checkpoint.height == blockHeight);
}

- (DSCheckpoint *)lastCheckpoint {
    if (!_lastCheckpoint) {
        _lastCheckpoint = [[self checkpoints] lastObject];
    }
    return _lastCheckpoint;
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeHeight:(uint32_t)height {
    NSUInteger genesisHeight = [self isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].height <= height)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    NSUInteger genesisHeight = [self isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].timestamp <= timestamp)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint *_Nullable)lastCheckpointHavingMasternodeList {
    NSSet *set = [self.checkpointsByHeightDictionary keysOfEntriesPassingTest:^BOOL(id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
        DSCheckpoint *checkpoint = (DSCheckpoint *)obj;
        return (checkpoint.masternodeListName && ![checkpoint.masternodeListName isEqualToString:@""]);
    }];
    NSArray *numbers = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
    if (!numbers.count) return nil;
    return self.checkpointsByHeightDictionary[numbers.lastObject];
}

- (DSCheckpoint *)checkpointForBlockHash:(UInt256)blockHash {
    return [self.checkpointsByHashDictionary objectForKey:uint256_data(blockHash)];
}

- (DSCheckpoint *)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [self.checkpointsByHeightDictionary objectForKey:@(blockHeight)];
}

- (void)useCheckpointBeforeOrOnHeightForTerminalBlocksSync:(uint32_t)blockHeight {
    DSCheckpoint *checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    self.terminalHeadersOverrideUseCheckpoint = checkpoint;
}

- (void)useCheckpointBeforeOrOnHeightForSyncingChainBlocks:(uint32_t)blockHeight {
    DSCheckpoint *checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    self.syncHeadersOverrideUseCheckpoint = checkpoint;
}


// MARK: - Wallet

- (BOOL)hasAWallet {
    return [self.mWallets count] > 0;
}

- (NSArray *)wallets {
    return [self.mWallets copy];
}

- (void)unregisterAllWallets {
    for (DSWallet *wallet in [self.mWallets copy]) {
        [self unregisterWallet:wallet];
    }
}

- (void)unregisterAllWalletsMissingExtendedPublicKeys {
    for (DSWallet *wallet in [self.mWallets copy]) {
        if ([wallet hasAnExtendedPublicKeyMissing]) {
            [self unregisterWallet:wallet];
        }
    }
}

- (void)unregisterWallet:(DSWallet *)wallet {
    NSAssert(wallet.chain == self, @"the wallet you are trying to remove is not on this chain");
    [wallet wipeBlockchainInfoInContext:self.chainManagedObjectContext];
    [wallet wipeWalletInfo];
    [self.mWallets removeObject:wallet];
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueIDString];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
    });
}

- (BOOL)addWallet:(DSWallet *)walletToAdd {
    BOOL alreadyPresent = FALSE;
    for (DSWallet *cWallet in self.mWallets) {
        if ([cWallet.uniqueIDString isEqual:walletToAdd.uniqueIDString]) {
            alreadyPresent = TRUE;
        }
    }
    if (!alreadyPresent) {
        [self.mWallets addObject:walletToAdd];
        return TRUE;
    }
    return FALSE;
}

- (void)registerWallet:(DSWallet *)wallet {
    BOOL firstWallet = !self.mWallets.count;
    if ([self.mWallets indexOfObject:wallet] == NSNotFound) {
        [self addWallet:wallet];
    }
    
    if (firstWallet) {
        //this is the first wallet, we should reset the last block height to the most recent checkpoint.
        _lastSyncBlock = nil; //it will lazy load later
    }
    
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    if (![keyChainArray containsObject:wallet.uniqueIDString]) {
        [keyChainArray addObject:wallet.uniqueIDString];
        setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        });
    }
}

- (void)retrieveWallets {
    NSError *error = nil;
    NSArray *walletIdentifiers = getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error);
    if (!error && walletIdentifiers) {
        for (NSString *uniqueID in walletIdentifiers) {
            DSWallet *wallet = [[DSWallet alloc] initWithUniqueID:uniqueID forChain:self];
            [self addWallet:wallet];
        }
        //we should load blockchain identies after all wallets are in the chain, as blockchain identities might be on different wallets and have interactions between each other
        for (DSWallet *wallet in self.wallets) {
            [wallet loadBlockchainIdentities];
        }
    }
}

// MARK: - Blocks

- (NSDictionary *)recentBlocks {
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
            b = useSyncBlocksNow ? self.mSyncBlocks[b.prevBlockValue] : self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = !useSyncBlocksNow;
            b = useSyncBlocksNow ? self.mSyncBlocks[b.prevBlockValue] : self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    if (!b) b = [[DSMerkleBlock alloc] initWithCheckpoint:[self lastCheckpointOnOrBeforeTimestamp:timestamp] onChain:self];
    return b;
}

- (void)setLastTerminalBlockFromCheckpoints {
    DSCheckpoint *checkpoint = self.terminalHeadersOverrideUseCheckpoint ? self.terminalHeadersOverrideUseCheckpoint : [self lastCheckpoint];
    if (checkpoint) {
        if (self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)]) {
            _lastTerminalBlock = self.mSyncBlocks[uint256_obj(checkpoint.blockHash)];
        } else {
            _lastTerminalBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)] = _lastTerminalBlock;
        }
    }
    
    if (_lastTerminalBlock) {
        DSLog(@"last terminal block at height %d chosen from checkpoints (hash is %@)", _lastTerminalBlock.height, [NSData dataWithUInt256:_lastTerminalBlock.blockHash].hexString);
    }
}

- (void)setLastSyncBlockFromCheckpoints {
    DSCheckpoint *checkpoint = nil;
    if (self.syncHeadersOverrideUseCheckpoint) {
        checkpoint = self.syncHeadersOverrideUseCheckpoint;
    } else if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
        NSUInteger genesisHeight = [self isDevnetAny] ? 1 : 0;
        checkpoint = self.checkpoints[genesisHeight];
    } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
        checkpoint = [self lastCheckpointOnOrBeforeHeight:[[DSOptionsManager sharedInstance] syncFromHeight]];
    } else {
        NSTimeInterval startSyncTime = self.startSyncFromTime;
        checkpoint = [self lastCheckpointOnOrBeforeTimestamp:(startSyncTime == BIP39_CREATION_TIME) ? BIP39_CREATION_TIME : startSyncTime - HEADER_WINDOW_BUFFER_TIME];
    }
    
    if (checkpoint) {
        if (self.mSyncBlocks[uint256_obj(checkpoint.blockHash)]) {
            _lastSyncBlock = self.mSyncBlocks[uint256_obj(checkpoint.blockHash)];
        } else {
            _lastSyncBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.mSyncBlocks[uint256_obj(checkpoint.blockHash)] = _lastSyncBlock;
        }
    }
    
    if (_lastSyncBlock) {
        DSLog(@"last sync block at height %d chosen from checkpoints for chain %@ (hash is %@)", _lastSyncBlock.height, self.name, [NSData dataWithUInt256:_lastSyncBlock.blockHash].hexString);
    }
}

- (DSBlock *)lastSyncBlockDontUseCheckpoints {
    return [self lastSyncBlockWithUseCheckpoints:NO];
}

- (DSBlock *)lastSyncBlock {
    return [self lastSyncBlockWithUseCheckpoints:YES];
}

- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints {
    if (_lastSyncBlock) return _lastSyncBlock;
    
    if (!_lastSyncBlock && uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) && uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) && self.lastPersistedChainSyncBlockHeight != BLOCK_UNKNOWN_HEIGHT) {
        _lastSyncBlock = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash prevBlock:UINT256_ZERO timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight chainWork:self.lastPersistedChainSyncBlockChainWork onChain:self];
    }
    
    if (!_lastSyncBlock && useCheckpoints) {
        DSLog(@"No last Sync Block, setting it from checkpoints");
        [self setLastSyncBlockFromCheckpoints];
    }
    
    return _lastSyncBlock;
}

- (NSMutableDictionary *)mSyncBlocks {
    @synchronized (_mSyncBlocks) {
        if (_mSyncBlocks.count > 0) {
            return _mSyncBlocks;
        }
    
        [self.chainManagedObjectContext performBlockAndWait:^{
            if (self->_mSyncBlocks.count > 0) return;
            if (uint256_is_not_zero(self.lastPersistedChainSyncBlockHash)) {
                self->_mSyncBlocks[uint256_obj(self.lastPersistedChainSyncBlockHash)] = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash prevBlock:UINT256_ZERO timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight chainWork:self.lastPersistedChainSyncBlockChainWork onChain:self];
            }
            
            for (DSCheckpoint *checkpoint in self.checkpoints) { // add checkpoints to the block collection
                UInt256 checkpointHash = checkpoint.blockHash;
                
                self->_mSyncBlocks[uint256_obj(checkpointHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self];
                self->_checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
                self->_checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
            }
        }];
        
        return _mSyncBlocks;
    }
}

- (NSArray<NSData *> *)chainSyncBlockLocatorArray {
    if (_lastSyncBlock && !(_lastSyncBlock.height == 1 && self.chainType.tag == ChainType_DevNet)) {
        return [self blockLocatorArrayForBlock:_lastSyncBlock];
    } else if (!_lastPersistedChainSyncLocators) {
        _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:BIP39_CREATION_TIME includeInitialTerminalBlocks:NO];
    }
    return _lastPersistedChainSyncLocators;
}

- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp includeInitialTerminalBlocks:(BOOL)includeHeaders {
    DSBlock *block = includeHeaders ? [self lastBlockOnOrBeforeTimestamp:timestamp] : [self lastChainSyncBlockOnOrBeforeTimestamp:timestamp];
    return [self blockLocatorArrayForBlock:block];
}

// this is used as part of a getblocks or getheaders request
- (NSArray<NSData *> *)blockLocatorArrayForBlock:(DSBlock *)block {
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
    DSCheckpoint *lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint *checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight && checkpoint.timestamp < b.timestamp) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.blockHash)];
    }
    return locators;
}


- (DSBlock *_Nullable)blockForBlockHash:(UInt256)blockHash {
    DSBlock *b;
    b = self.mSyncBlocks[uint256_obj(blockHash)];
    if (b) return b;
    b = self.mTerminalBlocks[uint256_obj(blockHash)];
    if (b) return b;
    if ([self allowInsightBlocksForVerification]) {
        return [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockHash)];
    }
    return nil;
}

- (DSBlock *)recentTerminalBlockForBlockHash:(UInt256)blockHash {
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

- (DSBlock *)recentSyncBlockForBlockHash:(UInt256)blockHash {
    DSBlock *b = [self lastSyncBlockDontUseCheckpoints];
    while (b && b.height > 0 && !uint256_eq(b.blockHash, blockHash)) {
        b = self.mSyncBlocks[b.prevBlockValue];
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
- (DSBlock *)blockAtHeightOrLastTerminal:(uint32_t)height {
    DSBlock *block = [self blockAtHeight:height];
    if (block == nil) {
        if (height > self.lastTerminalBlockHeight) {
            block = self.lastTerminalBlock;
        } else {
            return nil;
        }
    }
    return block;
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

// MARK: From Insight on Testnet
- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:blockHash
                                                 onChain:self
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
        if (!error && block) {
            [self addInsightVerifiedBlock:block forBlockHash:blockHash];
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)addInsightVerifiedBlock:(DSBlock *)block forBlockHash:(UInt256)blockHash {
    if ([self allowInsightBlocksForVerification]) {
        if (!self.insightVerifiedBlocksByHashDictionary) {
            self.insightVerifiedBlocksByHashDictionary = [NSMutableDictionary dictionary];
        }
        [self.insightVerifiedBlocksByHashDictionary setObject:block
                                                       forKey:uint256_data(blockHash)];
    }
}

// MARK: From Peer


- (BOOL)addMinedFullBlock:(DSFullBlock *)block {
    NSAssert(block.transactionHashes, @"Block must have txHashes");
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    if (!self.mSyncBlocks[prevBlock] || !self.mTerminalBlocks[prevBlock]) return NO;
    if (!uint256_eq(self.lastSyncBlock.blockHash, self.mSyncBlocks[prevBlock].blockHash)) return NO;
    if (!uint256_eq(self.lastTerminalBlock.blockHash, self.mTerminalBlocks[prevBlock].blockHash)) return NO;
    
    self.mSyncBlocks[blockHash] = block;
    self.lastSyncBlock = block;
    self.mTerminalBlocks[blockHash] = block;
    self.lastTerminalBlock = block;
    
    uint32_t txTime = block.timestamp / 2 + self.mTerminalBlocks[prevBlock].timestamp / 2;
    
    [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
    
    if (block.height > self.estimatedBlockHeight) {
        @synchronized (self) {
            _bestEstimatedBlockHeight = block.height;
        }
        [self saveBlockLocators];
        [self saveTerminalBlocks];
        
        // notify that transaction confirmations may have changed
        [self notifyBlocksChanged];
    }
    
    return TRUE;
}

//TRUE if it was added to the end of the chain
- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *)peer {
    if (peer && !self.chainManager.syncPhase) {
        DSLog(@"Block was received from peer after reset, ignoring it");
        return FALSE;
    }
    //DSLog(@"a block %@",uint256_hex(block.blockHash));
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSBlock *prev = nil;
    
    DSBlockPosition blockPosition = DSBlockPosition_Orphan;
    DSChainSyncPhase phase = self.chainManager.syncPhase;
    if (phase == DSChainSyncPhase_InitialTerminalBlocks) {
        //In this phase all received blocks are treated as terminal blocks
        prev = self.mTerminalBlocks[prevBlock];
        if (prev) {
            blockPosition = DSBlockPosition_Terminal;
        }
    } else {
        prev = self.mSyncBlocks[prevBlock];
        if (!prev) {
            prev = self.mTerminalBlocks[prevBlock];
            if (prev) {
                blockPosition = DSBlockPosition_Terminal;
            }
        } else if (self.mTerminalBlocks[prevBlock]) {
            //lets see if we are at the chain tip
            if (self.mTerminalBlocks[blockHash]) {
                //we already had this block, we are not at chain tip
                blockPosition = DSBlockPosition_Sync;
            } else {
                //we do not have this block as a terminal block, we are at chain tip
                blockPosition = DSBlockPosition_TerminalSync;
            }
            
        } else {
            blockPosition = DSBlockPosition_Sync;
        }
    }
    
    
    if (!prev) { // header is an orphan
#if LOG_PREV_BLOCKS_ON_ORPHAN
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        for (DSBlock *merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            DSLog(@"printing previous block at height %d : %@", merkleBlock.height, merkleBlock.blockHashValue);
        }
#endif
        DSLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", peer.host ? peer.host : @"TEST", peer.port,
              uint256_reverse_hex(block.blockHash), uint256_reverse_hex(block.prevBlock), block.height, uint256_reverse_hex(self.lastTerminalBlock.blockHash), self.lastSyncBlockHeight, [NSDate dateWithTimeIntervalSince1970:block.timestamp]);
        
        if (peer) {
            [self.chainManager chain:self receivedOrphanBlock:block fromPeer:peer];
            [peer receivedOrphanBlock];
        }
        
        self.mOrphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return FALSE;
    }
    
    BOOL syncDone = NO;
    
    @synchronized (block) {
        block.height = prev.height + 1;
    }
    UInt256 target = setCompactLE(block.target);
    NSAssert(uint256_is_not_zero(prev.chainWork), @"previous block should have aggregate work set");
    block.chainWork = uInt256AddLE(prev.chainWork, uInt256AddOneLE(uInt256DivideLE(uint256_inverse(target), uInt256AddOneLE(target))));
    NSAssert(uint256_is_not_zero(block.chainWork), @"block should have aggregate work set");
    uint32_t txTime = block.timestamp / 2 + prev.timestamp / 2;
    
    if ((blockPosition & DSBlockPosition_Terminal) && ((block.height % 10000) == 0 || ((block.height == self.estimatedBlockHeight) && (block.height % 100) == 0))) { //free up some memory from time to time
        //[self saveTerminalBlocks];
        DSBlock *b = block;
        
        for (uint32_t i = 0; b && i < KEEP_RECENT_TERMINAL_BLOCKS; i++) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        NSMutableArray *blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:b.blockHashValue];
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        [self.mTerminalBlocks removeObjectsForKeys:blocksToRemove];
    }
    if ((blockPosition & DSBlockPosition_Sync) && ((block.height % 1000) == 0)) { //free up some memory from time to time
        DSBlock *b = block;
        
        for (uint32_t i = 0; b && i < KEEP_RECENT_SYNC_BLOCKS; i++) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        NSMutableArray *blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:b.blockHashValue];
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        [self.mSyncBlocks removeObjectsForKeys:blocksToRemove];
    }
    
    // verify block difficulty if block is past last checkpoint
    DSCheckpoint *lastCheckpoint = [self lastCheckpoint];
    
    DSBlock *equivalentTerminalBlock = nil;
    
    if ((blockPosition & DSBlockPosition_Sync) && (self.lastSyncBlockHeight + 1 >= lastCheckpoint.height)) {
        equivalentTerminalBlock = self.mTerminalBlocks[blockHash];
    }
    
    if (!equivalentTerminalBlock && ((blockPosition & DSBlockPosition_Terminal) || [block canCalculateDifficultyWithPreviousBlocks:self.mSyncBlocks])) { //no need to check difficulty if we already have terminal blocks
        uint32_t foundDifficulty = 0;
        if ((block.height > self.minimumDifficultyBlocks) && (block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
            ![block verifyDifficultyWithPreviousBlocks:(blockPosition & DSBlockPosition_Terminal) ? self.mTerminalBlocks : self.mSyncBlocks rDifficulty:&foundDifficulty]) {
            DSLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
                  block.height, block.target, foundDifficulty, blockHash);
            
            if (peer) {
                [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
        
        UInt256 difficulty = setCompactLE(block.target);
        if (uint256_sup(block.blockHash, difficulty)) {
            DSLog(@"%@:%d relayed block with invalid block hash %d target %x, blockHash: %@ difficulty: %@", peer.host, peer.port,
                  block.height, block.target, uint256_bin(block.blockHash), uint256_bin(difficulty));
            
            if (peer) {
                [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
    }
    
    DSCheckpoint *checkpoint = [self.checkpointsByHeightDictionary objectForKey:@(block.height)];
    
    if ((!equivalentTerminalBlock) && (checkpoint && !uint256_eq(block.blockHash, checkpoint.blockHash))) {
        // verify block chain checkpoints
        DSLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              peer.host, peer.port, block.height, blockHash, uint256_hex(checkpoint.blockHash));
        if (peer) {
            [self.chainManager chain:self badBlockReceivedFromPeer:peer];
        }
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    uint32_t h = block.height;
    if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && uint256_eq(block.prevBlock, self.lastSyncBlockHash)) { // new block extends sync chain
        if ((block.height % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"[%@: %@] + sync block at: %d: %@", self.name, peer.host ? peer.host : @"TEST", h, uint256_hex(block.blockHash));
        }
        self.mSyncBlocks[blockHash] = block;
        if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
            [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
        }
        self.lastSyncBlock = block;
        
        if (!equivalentTerminalBlock && uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) {
            if ((h % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
                DSLog(@"[%@: %@] + terminal block (caught up) at: %d: %@", self.name, peer.host ? peer.host : @"TEST", h, uint256_hex(block.blockHash));
            }
            self.mTerminalBlocks[blockHash] = block;
            self.lastTerminalBlock = block;
        }
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }
        if (h == self.estimatedBlockHeight) syncDone = YES;
        [self setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
        onMainChain = TRUE;
        
        if ([self blockHeightHasCheckpoint:h] ||
            ((h % 1000 == 0) && (h + BLOCK_NO_FORK_DEPTH < self.lastTerminalBlockHeight) && !self.chainManager.masternodeManager.hasMasternodeListCurrentlyBeingSaved)) {
            [self saveBlockLocators];
        }
        
    } else if (uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) { // new block extends terminal chain
        if ((h % 500) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"[%@: %@] + terminal block at: %d: %@", self.name, peer.host ? peer.host : @"TEST", h, uint256_hex(block.blockHash));
        }
        self.mTerminalBlocks[blockHash] = block;
        self.lastTerminalBlock = block;
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }
        if (h == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    } else if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && self.mSyncBlocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@:%d relayed existing sync block at height %d", peer.host, peer.port, h);
        }
        self.mSyncBlocks[blockHash] = block;
        if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
            [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
        }
        
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }

        DSBlock *b = self.lastSyncBlock;
        
        while (b && b.height > h) b = self.mSyncBlocks[b.prevBlockValue]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:h andTimestamp:txTime forTransactionHashes:txHashes];
            if (h == self.lastSyncBlockHeight) self.lastSyncBlock = block;
        }
    } else if (self.mTerminalBlocks[blockHash] != nil && (blockPosition & DSBlockPosition_Terminal)) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@:%d relayed existing terminal block at height %d (last sync height %d)", peer.host, peer.port, h, self.lastSyncBlockHeight);
        }
        self.mTerminalBlocks[blockHash] = block;
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }

        DSBlock *b = self.lastTerminalBlock;
        
        while (b && b.height > h) b = self.mTerminalBlocks[b.prevBlockValue]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:h andTimestamp:txTime forTransactionHashes:txHashes];
            if (h == self.lastTerminalBlockHeight) self.lastTerminalBlock = block;
        }
    } else {                                                // new block is on a fork
        if (h <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            DSLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@", h, blockHash);
            return TRUE;
        }
        
        if (h <= self.lastChainLock.height) {
            DSLog(@"ignoring block on fork when main chain is chainlocked: %d, blockHash: %@", h, blockHash);
            return TRUE;
        }
        
        DSLog(@"potential chain fork to height %d blockPosition %d", block.height, blockPosition);
        if (!(blockPosition & DSBlockPosition_Sync)) {
            //this is only a reorg of the terminal blocks
            self.mTerminalBlocks[blockHash] = block;
            if (uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSLog(@"found potential chain fork on height %d", block.height);
            
            DSBlock *b = block, *b2 = self.lastTerminalBlock;
            
            while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                b = self.mTerminalBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
            }
            
            if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                DSLog(@"no reorganizing chain to height %d because of chainlock at height %d", h, b2.height);
                return TRUE;
            }
            
            DSLog(@"reorganizing terminal chain from height %d, new height is %d", b.height, h);
            
            self.lastTerminalBlock = block;
            @synchronized(peer) {
                if (peer) {
                    peer.currentBlockHeight = h; //might be download peer instead
                }
            }
            if (h == self.estimatedBlockHeight) syncDone = YES;
        } else {
            if (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) {
                self.mTerminalBlocks[blockHash] = block;
            }
            self.mSyncBlocks[blockHash] = block;

            if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
                [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
            }
            
            if (uint256_supeq(self.lastSyncBlock.chainWork, block.chainWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSLog(@"found sync chain fork on height %d", h);
            if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && !uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) {
                DSBlock *b = block, *b2 = self.lastTerminalBlock;
                
                while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                    b = self.mTerminalBlocks[b.prevBlockValue];
                    if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
                }
                
                if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                    DSLog(@"no reorganizing chain to height %d because of chainlock at height %d", h, b2.height);
                } else {
                    DSLog(@"reorganizing terminal chain from height %d, new height is %d", b.height, h);
                    self.lastTerminalBlock = block;
                    @synchronized(peer) {
                        if (peer) {
                            peer.currentBlockHeight = h; //might be download peer instead
                        }
                    }
                }
            }
            
            DSBlock *b = block, *b2 = self.lastSyncBlock;
            
            while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                b = self.mSyncBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mSyncBlocks[b2.prevBlockValue];
            }
            
            if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                DSLog(@"no reorganizing sync chain to height %d because of chainlock at height %d", h, b2.height);
                return TRUE;
            }
            
            DSLog(@"reorganizing sync chain from height %d, new height is %d", b.height, h);
            
            NSMutableArray *txHashes = [NSMutableArray array];
            // mark transactions after the join point as unconfirmed
            for (DSWallet *wallet in self.wallets) {
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
                txTime = b.timestamp / 2 + ((DSBlock *)self.mSyncBlocks[b.prevBlockValue]).timestamp / 2;
            }
            
            self.lastSyncBlock = block;
            if (h == self.estimatedBlockHeight) syncDone = YES;
        }
    }
    
    if ((blockPosition & DSBlockPosition_Terminal) && checkpoint && checkpoint == [self lastCheckpointHavingMasternodeList]) {
        [self.chainManager.masternodeManager loadFileDistributedMasternodeLists];
    }
    
    BOOL savedBlockLocators = NO;
    BOOL savedTerminalBlocks = NO;
    if (syncDone) { // chain download is complete
        if (blockPosition & DSBlockPosition_Terminal) {
            [self saveTerminalBlocks];
            savedTerminalBlocks = YES;
            if (peer) {
                [self.chainManager chainFinishedSyncingInitialHeaders:self fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainInitialHeadersDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
            });
        }
        if ((blockPosition & DSBlockPosition_Sync) && (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced)) {
            //we should only save
            [self saveBlockLocators];
            savedBlockLocators = YES;
            if (peer) {
                [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
            });
        }
    }
    
    if (((blockPosition & DSBlockPosition_Terminal) && block.height > self.estimatedBlockHeight) || ((blockPosition & DSBlockPosition_Sync) && block.height >= self.lastTerminalBlockHeight)) {
        @synchronized (self) {
            _bestEstimatedBlockHeight = block.height;
        }
        if (peer && (blockPosition & DSBlockPosition_Sync) && !savedBlockLocators) {
            [self saveBlockLocators];
        }
        if ((blockPosition & DSBlockPosition_Terminal) && !savedTerminalBlocks) {
            [self saveTerminalBlocks];
        }
        if (peer) {
            [self.chainManager chain:self wasExtendedWithBlock:block fromPeer:peer];
        }
        
        // notify that transaction confirmations may have changed
        [self setupBlockChangeTimer:^{
            [self notifyBlocksChanged];
        }];
    } else {
        //we should avoid dispatching this message too frequently
        [self setupBlockChangeTimer:^{
            [self notifyBlocksChanged:blockPosition];
        }];
    }
    
    // check if the next block was received as an orphan
    if (block == self.lastTerminalBlock && self.mOrphans[blockHash]) {
        DSBlock *b = self.mOrphans[blockHash];
        
        [self.mOrphans removeObjectForKey:blockHash];
        [self addBlock:b receivedAsHeader:YES fromPeer:peer]; //revisit this
    }
    return TRUE;
}

- (void)setupBlockChangeTimer:(void (^ __nullable)(void))completion {
    //we should avoid dispatching this message too frequently
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    if (!self.lastNotifiedBlockDidChange || (timestamp - self.lastNotifiedBlockDidChange > 0.1)) {
        self.lastNotifiedBlockDidChange = timestamp;
        if (self.lastNotifiedBlockDidChangeTimer) {
            [self.lastNotifiedBlockDidChangeTimer invalidate];
            self.lastNotifiedBlockDidChangeTimer = nil;
        }
        completion();
    } else if (!self.lastNotifiedBlockDidChangeTimer) {
        self.lastNotifiedBlockDidChangeTimer = [NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *_Nonnull timer) {
            completion();
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.lastNotifiedBlockDidChangeTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)notifyBlocksChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
    });
}

- (void)notifyBlocksChanged:(DSBlockPosition)blockPosition {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (blockPosition & DSBlockPosition_Terminal) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        }
        if (blockPosition & DSBlockPosition_Sync) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        }
        
    });
}

// MARK: Terminal Blocks
- (NSMutableDictionary *)mTerminalBlocks {
    @synchronized (_mTerminalBlocks) {
        if (_mTerminalBlocks.count > 0) {
            return _mTerminalBlocks;
        }
        [self.chainManagedObjectContext performBlockAndWait:^{
            if (self->_mTerminalBlocks.count > 0) return;
            for (DSCheckpoint *checkpoint in self.checkpoints) { // add checkpoints to the block collection
                UInt256 checkpointHash = checkpoint.blockHash;
                
                self->_mTerminalBlocks[uint256_obj(checkpointHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self];
                self->_checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
                self->_checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
            }
            for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastTerminalBlocks:KEEP_RECENT_TERMINAL_BLOCKS onChainEntity:[self chainEntityInContext:self.chainManagedObjectContext]]) {
                @autoreleasepool {
                    DSMerkleBlock *b = e.merkleBlock;
                    if (b) self->_mTerminalBlocks[b.blockHashValue] = b;
                }
            };
        }];
        
        return _mTerminalBlocks;
    }
}

- (DSBlock *)lastTerminalBlock {
    @synchronized (self) {
        if (_lastTerminalBlock) return _lastTerminalBlock;
    }
    [self.chainManagedObjectContext performBlockAndWait:^{
        NSArray *lastTerminalBlocks = [DSMerkleBlockEntity lastTerminalBlocks:1 onChainEntity:[self chainEntityInContext:self.chainManagedObjectContext]];
        DSMerkleBlock *lastTerminalBlock = [[lastTerminalBlocks firstObject] merkleBlock];
        @synchronized (self) {
            self->_lastTerminalBlock = lastTerminalBlock;
            if (lastTerminalBlock) {
                DSLog(@"last terminal block at height %d recovered from db (hash is %@)", lastTerminalBlock.height, [NSData dataWithUInt256:lastTerminalBlock.blockHash].hexString);
            }
        }
    }];

    @synchronized (self) {
        if (!_lastTerminalBlock) {
            // if we don't have any headers yet, use the latest checkpoint
            DSCheckpoint *lastCheckpoint = self.terminalHeadersOverrideUseCheckpoint ? self.terminalHeadersOverrideUseCheckpoint : self.lastCheckpoint;
            uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
            
            if (lastCheckpoint.height >= lastSyncBlockHeight) {
                [self setLastTerminalBlockFromCheckpoints];
            } else {
                _lastTerminalBlock = self.lastSyncBlock;
            }
        }
        
        if (_lastTerminalBlock.height > self.estimatedBlockHeight) _bestEstimatedBlockHeight = _lastTerminalBlock.height;
        
        return _lastTerminalBlock;
    }
}

- (NSArray *)terminalBlocksLocatorArray {
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSBlock *b = self.lastTerminalBlock;
    uint32_t lastHeight = b.height;
    NSDictionary *terminalBlocks = [self.mTerminalBlocks copy];
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = terminalBlocks[b.prevBlockValue];
        }
    }
    DSCheckpoint *lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this header
    for (DSCheckpoint *checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.blockHash)];
    }
    return locators;
}


// MARK: Orphans

- (void)clearOrphans {
    [self.mOrphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

// MARK: Chain Locks

- (BOOL)addChainLock:(DSChainLock *)chainLock {
    DSBlock *terminalBlock = self.mTerminalBlocks[uint256_obj(chainLock.blockHash)];
    [terminalBlock setChainLockedWithChainLock:chainLock];
    if ((terminalBlock.chainLocked) && (![self recentTerminalBlockForBlockHash:terminalBlock.blockHash])) {
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        NSLog(@"Added a chain lock for block %@ that was not on the main terminal chain ending in %@, reorginizing", terminalBlock, self.lastSyncBlock);
        //clb chain locked block
        //tbmc terminal block
        DSBlock *clb = terminalBlock, *tbmc = self.lastTerminalBlock;
        BOOL cancelReorg = FALSE;
        
        while (clb && tbmc && !uint256_eq(clb.blockHash, tbmc.blockHash)) { // walk back to where the fork joins the main chain
            if (tbmc.chainLocked) {
                //if a block is already chain locked then do not reorg
                cancelReorg = TRUE;
            }
            if (clb.height < tbmc.height) {
                tbmc = self.mTerminalBlocks[tbmc.prevBlockValue];
            } else if (clb.height > tbmc.height) {
                clb = self.mTerminalBlocks[clb.prevBlockValue];
            } else {
                tbmc = self.mTerminalBlocks[tbmc.prevBlockValue];
                clb = self.mTerminalBlocks[clb.prevBlockValue];
            }
        }
        
        if (cancelReorg) {
            NSLog(@"Cancelling terminal reorg because block %@ is already chain locked", tbmc);
        } else {
            NSLog(@"Reorginizing to height %d", clb.height);
            
            self.lastTerminalBlock = terminalBlock;
            NSMutableDictionary *forkChainsTerminalBlocks = [[self forkChainsTerminalBlocks] mutableCopy];
            NSMutableArray *addedBlocks = [NSMutableArray array];
            BOOL done = FALSE;
            while (!done) {
                BOOL found = NO;
                for (NSValue *blockHash in forkChainsTerminalBlocks) {
                    if ([addedBlocks containsObject:blockHash]) continue;
                    DSBlock *potentialNextTerminalBlock = self.mTerminalBlocks[blockHash];
                    if (uint256_eq(potentialNextTerminalBlock.prevBlock, self.lastTerminalBlock.blockHash)) {
                        [self addBlock:potentialNextTerminalBlock receivedAsHeader:YES fromPeer:nil];
                        [addedBlocks addObject:blockHash];
                        found = TRUE;
                        break;
                    }
                }
                if (!found) {
                    done = TRUE;
                }
            }
        }
    }
    DSBlock *syncBlock = self.mSyncBlocks[uint256_obj(chainLock.blockHash)];
    [syncBlock setChainLockedWithChainLock:chainLock];
    DSBlock *sbmc = self.lastSyncBlockDontUseCheckpoints;
    if (sbmc && (syncBlock.chainLocked) && ![self recentSyncBlockForBlockHash:syncBlock.blockHash]) { //!OCLINT
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        NSLog(@"Added a chain lock for block %@ that was not on the main sync chain ending in %@, reorginizing", syncBlock, self.lastSyncBlock);
        
        //clb chain locked block
        //sbmc sync block main chain
        DSBlock *clb = syncBlock;
        BOOL cancelReorg = FALSE;
        
        while (clb && sbmc && !uint256_eq(clb.blockHash, sbmc.blockHash)) { // walk back to where the fork joins the main chain
            if (sbmc.chainLocked) {
                //if a block is already chain locked then do not reorg
                cancelReorg = TRUE;
            } else if (clb.height < sbmc.height) {
                sbmc = self.mSyncBlocks[sbmc.prevBlockValue];
            } else if (clb.height > sbmc.height) {
                clb = self.mSyncBlocks[clb.prevBlockValue];
            } else {
                sbmc = self.mSyncBlocks[sbmc.prevBlockValue];
                clb = self.mSyncBlocks[clb.prevBlockValue];
            }
        }
        
        if (cancelReorg) {
            NSLog(@"Cancelling sync reorg because block %@ is already chain locked", sbmc);
        } else {
            self.lastSyncBlock = syncBlock;
            
            NSLog(@"Reorginizing to height %d (last sync block %@)", clb.height, self.lastSyncBlock);
            
            
            NSMutableArray *txHashes = [NSMutableArray array];
            // mark transactions after the join point as unconfirmed
            for (DSWallet *wallet in self.wallets) {
                for (DSTransaction *tx in wallet.allTransactions) {
                    if (tx.blockHeight <= clb.height) break;
                    [txHashes addObject:uint256_obj(tx.txHash)];
                }
            }
            
            [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTransactionHashes:txHashes];
            clb = syncBlock;
            
            while (clb.height > sbmc.height) { // set transaction heights for new main chain
                DSBlock *prevBlock = self.mSyncBlocks[clb.prevBlockValue];
                NSTimeInterval txTime = prevBlock ? ((prevBlock.timestamp + clb.timestamp) / 2) : clb.timestamp;
                [self setBlockHeight:clb.height andTimestamp:txTime forTransactionHashes:clb.transactionHashes];
                clb = prevBlock;
            }
            
            NSMutableDictionary *forkChainsTerminalBlocks = [[self forkChainsSyncBlocks] mutableCopy];
            NSMutableArray *addedBlocks = [NSMutableArray array];
            BOOL done = FALSE;
            while (!done) {
                BOOL found = NO;
                for (NSValue *blockHash in forkChainsTerminalBlocks) {
                    if ([addedBlocks containsObject:blockHash]) continue;
                    DSBlock *potentialNextTerminalBlock = self.mSyncBlocks[blockHash];
                    if (uint256_eq(potentialNextTerminalBlock.prevBlock, self.lastSyncBlock.blockHash)) {
                        [self addBlock:potentialNextTerminalBlock receivedAsHeader:NO fromPeer:nil];
                        [addedBlocks addObject:blockHash];
                        found = TRUE;
                        break;
                    }
                }
                if (!found) {
                    done = TRUE;
                }
            }
        }
    }
    return (terminalBlock && terminalBlock.chainLocked) || (syncBlock && syncBlock.chainLocked);
}

- (BOOL)blockHeightChainLocked:(uint32_t)height {
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

- (NSTimeInterval)lastSyncBlockTimestamp {
    return _lastSyncBlock ? _lastSyncBlock.timestamp : (self.lastPersistedChainSyncBlockTimestamp ? self.lastPersistedChainSyncBlockTimestamp : self.lastSyncBlock.timestamp);
}

- (uint32_t)lastSyncBlockHeight {
    @synchronized (_lastSyncBlock) {
        if (_lastSyncBlock) {
            return _lastSyncBlock.height;
        } else if (self.lastPersistedChainSyncBlockHeight) {
            return self.lastPersistedChainSyncBlockHeight;
        } else {
            return self.lastSyncBlock.height;
        }
    }
}

- (UInt256)lastSyncBlockHash {
    return _lastSyncBlock ? _lastSyncBlock.blockHash : (uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) ? self.lastPersistedChainSyncBlockHash : self.lastSyncBlock.blockHash);
}

- (UInt256)lastSyncBlockChainWork {
    return _lastSyncBlock ? _lastSyncBlock.chainWork : (uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) ? self.lastPersistedChainSyncBlockChainWork : self.lastSyncBlock.chainWork);
}

- (uint32_t)lastTerminalBlockHeight {
    return self.lastTerminalBlock.height;
}

- (BOOL)allowInsightBlocksForVerification {
    return !self.isMainnet;
}

- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash {
    DSCheckpoint *checkpoint = [self.checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    @synchronized (_mSyncBlocks) {
        DSBlock *syncBlock = [_mSyncBlocks objectForKey:uint256_obj(blockhash)];
        if (syncBlock && (syncBlock.height != UINT32_MAX)) {
            return syncBlock.height;
        }
    }
    @synchronized (_mTerminalBlocks) {
        DSBlock *terminalBlock = [_mTerminalBlocks objectForKey:uint256_obj(blockhash)];
        if (terminalBlock && (terminalBlock.height != UINT32_MAX)) {
            return terminalBlock.height;
        }
    }

    for (DSCheckpoint *checkpoint in self.checkpoints) {
        if (uint256_eq(checkpoint.blockHash, blockhash)) {
            return checkpoint.height;
        }
    }
    //DSLog(@"Requesting unknown quick blockhash %@", uint256_reverse_hex(blockhash));
    return UINT32_MAX;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    DSCheckpoint *checkpoint = [self.checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    @synchronized (_mSyncBlocks) {
        DSBlock *syncBlock = [_mSyncBlocks objectForKey:uint256_obj(blockhash)];
        if (syncBlock && (syncBlock.height != UINT32_MAX)) {
            return syncBlock.height;
        }
    }
    @synchronized (_mTerminalBlocks) {
        DSBlock *terminalBlock = [_mTerminalBlocks objectForKey:uint256_obj(blockhash)];
        if (terminalBlock && (terminalBlock.height != UINT32_MAX)) {
            return terminalBlock.height;
        }
    }

    DSBlock *b = self.lastTerminalBlock;
    
    if (!b) {
        b = self.lastSyncBlock;
    }
    
    while (b && b.height > 0) {
        if (uint256_eq(b.blockHash, blockhash)) {
            return b.height;
        }
        b = self.mTerminalBlocks[b.prevBlockValue];
        if (!b) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
    }

    for (DSCheckpoint *checkpoint in self.checkpoints) {
        if (uint256_eq(checkpoint.blockHash, blockhash)) {
            return checkpoint.height;
        }
    }
    if ([self allowInsightBlocksForVerification] && [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockhash)]) {
        b = [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockhash)];
        return b.height;
    }
    //DSLog(@"Requesting unknown blockhash %@ on chain %@ (it's probably being added asyncronously)", uint256_reverse_hex(blockhash), self.name);
    return UINT32_MAX;
}

// seconds since reference date, 00:00:00 01/01/01 GMT
// NOTE: this is only accurate for the last two weeks worth of blocks, other timestamps are estimated from checkpoints
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight {
    if (blockHeight == TX_UNCONFIRMED) return (self.lastTerminalBlock.timestamp) + 2.5 * 60; //next block
    
    if (blockHeight >= self.lastTerminalBlockHeight) { // future block, assume 2.5 minutes per block after last block
        return (self.lastTerminalBlock.timestamp) + (blockHeight - self.lastTerminalBlockHeight) * 2.5 * 60;
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
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp) *
            (blockHeight - self.checkpoints[i].height) / (h - self.checkpoints[i].height);
            return t;
        }
        
        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }
    
    return self.checkpoints[0].timestamp;
}

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray<NSValue *> *)transactionHashes {
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) _bestBlockHeight = height;
    NSMutableArray *updatedTransactions = [NSMutableArray array];
    if ([transactionHashes count]) {
        //need to reverify this works
        for (NSValue *transactionHash in transactionHashes) {
            [self.transactionHashHeights setObject:@(height) forKey:uint256_data_from_obj(transactionHash)];
        }
        for (NSValue *transactionHash in transactionHashes) {
            [self.transactionHashTimestamps setObject:@(timestamp) forKey:uint256_data_from_obj(transactionHash)];
        }
        for (DSWallet *wallet in self.wallets) {
            [updatedTransactions addObjectsFromArray:[wallet setBlockHeight:height
                                                               andTimestamp:timestamp
                                                       forTransactionHashes:transactionHashes]];
        }
    } else {
        for (DSWallet *wallet in self.wallets) {
            [wallet chainUpdatedBlockHeight:height];
        }
    }
    
    [self.chainManager chain:self
           didSetBlockHeight:height
                andTimestamp:timestamp
        forTransactionHashes:transactionHashes
         updatedTransactions:updatedTransactions];
}

- (void)reloadDerivationPaths {
    for (DSWallet *wallet in self.mWallets) {
        if (!wallet.isTransient) { //no need to reload transient wallets (those are for testing purposes)
            [wallet reloadDerivationPaths];
        }
    }
}

- (uint32_t)estimatedBlockHeight {
    @synchronized (self) {
        if (_bestEstimatedBlockHeight) return _bestEstimatedBlockHeight;
            _bestEstimatedBlockHeight = [self decideFromPeerSoftConsensusEstimatedBlockHeight];
        return _bestEstimatedBlockHeight;
    }
}

- (uint32_t)decideFromPeerSoftConsensusEstimatedBlockHeight {
    uint32_t maxCount = 0;
    uint32_t tempBestEstimatedBlockHeight = 0;
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSArray *announcers = self.estimatedBlockHeights[height];
        if (announcers.count > maxCount) {
            tempBestEstimatedBlockHeight = [height intValue];
            maxCount = (uint32_t)announcers.count;
        } else if (announcers.count == maxCount && tempBestEstimatedBlockHeight < [height intValue]) {
            //use the latest if deadlocked
            tempBestEstimatedBlockHeight = [height intValue];
        }
    }
    return tempBestEstimatedBlockHeight;
}

- (NSUInteger)countEstimatedBlockHeightAnnouncers {
    NSMutableSet *announcers = [NSMutableSet set];
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSArray<DSPeer *> *announcersAtHeight = self.estimatedBlockHeights[height];
        [announcers addObjectsFromArray:announcersAtHeight];
    }
    return [announcers count];
}

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer *)peer thresholdPeerCount:(uint32_t)thresholdPeerCount {
    uint32_t oldEstimatedBlockHeight = self.estimatedBlockHeight;
    
    //remove from other heights
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        if ([height intValue] == estimatedBlockHeight) continue;
        NSMutableArray *announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if ((![announcers count]) && (self.estimatedBlockHeights[height])) {
            [self.estimatedBlockHeights removeObjectForKey:height];
        }
    }
    if (![self estimatedBlockHeights][@(estimatedBlockHeight)]) {
        [self estimatedBlockHeights][@(estimatedBlockHeight)] = [NSMutableArray arrayWithObject:peer];
    } else {
        NSMutableArray *peersAnnouncingHeight = [self estimatedBlockHeights][@(estimatedBlockHeight)];
        if (![peersAnnouncingHeight containsObject:peer]) {
            [peersAnnouncingHeight addObject:peer];
        }
    }
    if ([self countEstimatedBlockHeightAnnouncers] > thresholdPeerCount) {
        static dispatch_once_t onceToken;
        uint32_t finalEstimatedBlockHeight = [self decideFromPeerSoftConsensusEstimatedBlockHeight];
        if (finalEstimatedBlockHeight > oldEstimatedBlockHeight) {
            _bestEstimatedBlockHeight = finalEstimatedBlockHeight;
            dispatch_once(&onceToken, ^{
                [self.chainManager assignSyncWeights];
            });
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainManagerSyncParametersUpdatedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
            });
        } else {
            dispatch_once(&onceToken, ^{
                [self.chainManager assignSyncWeights];
            });
        }
    }
}

- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer {
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSMutableArray *announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if ((![announcers count]) && (self.estimatedBlockHeights[height])) {
            [self.estimatedBlockHeights removeObjectForKey:height];
        }
        //keep best estimate if no other peers reporting on estimate
        if ([self.estimatedBlockHeights count] && ([height intValue] == _bestEstimatedBlockHeight)) {
            _bestEstimatedBlockHeight = 0;
        }
    }
}

// MARK: - Accounts

- (uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSWallet *wallet in self.wallets) {
        rBalance += wallet.balance;
    }
    for (DSDerivationPath *standaloneDerivationPath in self.standaloneDerivationPaths) {
        rBalance += standaloneDerivationPath.balance;
    }
    return rBalance;
}

- (DSAccount *_Nullable)firstAccountWithBalance {
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet firstAccountWithBalance];
        if (account) return account;
    }
    return nil;
}

- (DSAccount *_Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    if (!transaction) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet firstAccountThatCanContainTransaction:transaction];
        if (account) return account;
    }
    return nil;
}

- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSMutableArray *mArray = [NSMutableArray array];
    if (!transaction) return @[];
    for (DSWallet *wallet in self.wallets) {
        [mArray addObjectsFromArray:[wallet accountsThatCanContainTransaction:transaction]];
    }
    return [mArray copy];
}

- (DSAccount *_Nullable)accountContainingAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet accountForAddress:address];
        if (account) return account;
    }
    return nil;
}

- (DSAccount *_Nullable)accountContainingDashpayExternalDerivationPathAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet accountForDashpayExternalDerivationPathAddress:address];
        if (account) return account;
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount *_Nullable)firstAccountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction wallet:(DSWallet **)wallet {
    for (DSWallet *lWallet in self.wallets) {
        for (DSAccount *account in lWallet.accounts) {
            DSTransaction *lTransaction = [account transactionForHash:txHash];
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
    NSMutableArray *accounts = [NSMutableArray array];
    for (DSWallet *lWallet in self.wallets) {
        for (DSAccount *account in lWallet.accounts) {
            DSTransaction *lTransaction = [account transactionForHash:txHash];
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

- (DSTransaction *)transactionForHash:(UInt256)txHash returnWallet:(DSWallet **)rWallet {
    for (DSWallet *wallet in self.wallets) {
        DSTransaction *transaction = [wallet transactionForHash:txHash];
        if (transaction) {
            if (rWallet) *rWallet = wallet;
            return transaction;
        }
    }
    return nil;
}

- (NSArray<DSTransaction *> *)allTransactions {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSWallet *wallet in self.wallets) {
        [mArray addObjectsFromArray:wallet.allTransactions];
    }
    return mArray;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t received = 0;
    for (DSWallet *wallet in self.wallets) {
        received += [wallet amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t sent = 0;
    for (DSWallet *wallet in self.wallets) {
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
    } else if (sent > 0) {
        // sent
        return DSTransactionDirection_Sent;
    } else if (received > 0) {
        // received
        return DSTransactionDirection_Received;
    } else {
        // no funds moved on this account
        return DSTransactionDirection_NotAccountFunds;
    }
}

// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context {
    DSLog(@"Wiping Blockchain Info");
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self wipeBlockchainInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    @synchronized (_mSyncBlocks) {
        _mSyncBlocks = [NSMutableDictionary dictionary];
    }
    @synchronized (_mTerminalBlocks) {
        _mTerminalBlocks = [NSMutableDictionary dictionary];
    }
    _lastSyncBlock = nil;
    _lastTerminalBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockChainWork = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastTerminalBlockFromCheckpoints];
    [self setLastSyncBlockFromCheckpoints];
    [self.chainManager chainWasWiped:self];
}

- (void)wipeBlockchainNonTerminalInfoInContext:(NSManagedObjectContext *)context {
    DSLog(@"Wiping Blockchain Non Terminal Info");
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self wipeBlockchainInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    @synchronized (_mSyncBlocks) {
        _mSyncBlocks = [NSMutableDictionary dictionary];
    }
    _lastSyncBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockChainWork = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastSyncBlockFromCheckpoints];
    [self.chainManager chainWasWiped:self];
}

- (void)wipeMasternodesInContext:(NSManagedObjectContext *)context {
    DSLog(@"Wiping Masternode Info");
    DSChainEntity *chainEntity = [self chainEntityInContext:context];
    [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
    [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
    [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
    [DSMasternodeListEntity deleteAllOnChainEntity:chainEntity];
    [DSQuorumSnapshotEntity deleteAllOnChainEntity:chainEntity];
    [self.chainManager wipeMasternodeInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@", self.uniqueID, LAST_SYNCED_MASTERNODE_LIST]];
}

- (void)wipeWalletsAndDerivatives {
    DSLog(@"Wiping Wallets and Derivatives");
    [self unregisterAllWallets];
    [self unregisterAllStandaloneDerivationPaths];
    self.mWallets = [NSMutableArray array];
    self.viewingAccount = nil;
}

// MARK: - Identities

- (uint32_t)localBlockchainIdentitiesCount {
    uint32_t blockchainIdentitiesCount = 0;
    for (DSWallet *lWallet in self.wallets) {
        blockchainIdentitiesCount += [lWallet blockchainIdentitiesCount];
    }
    return blockchainIdentitiesCount;
}

- (NSArray<DSBlockchainIdentity *> *)localBlockchainIdentities {
    NSMutableArray *rAllBlockchainIdentities = [NSMutableArray array];
    for (DSWallet *wallet in self.wallets) {
        [rAllBlockchainIdentities addObjectsFromArray:[wallet.blockchainIdentities allValues]];
    }
    return rAllBlockchainIdentities;
}

- (NSDictionary<NSData *, DSBlockchainIdentity *> *)localBlockchainIdentitiesByUniqueIdDictionary {
    NSMutableDictionary *rAllBlockchainIdentities = [NSMutableDictionary dictionary];
    for (DSWallet *wallet in self.wallets) {
        for (DSBlockchainIdentity *blockchainIdentity in [wallet.blockchainIdentities allValues]) {
            rAllBlockchainIdentities[blockchainIdentity.uniqueIDData] = blockchainIdentity;
        }
    }
    return rAllBlockchainIdentities;
}


- (DSBlockchainIdentity *)blockchainIdentityForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    return [self blockchainIdentityForUniqueId:uniqueId foundInWallet:nil includeForeignBlockchainIdentities:NO];
}

- (DSBlockchainIdentity *)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet **)foundInWallet {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    return [self blockchainIdentityForUniqueId:uniqueId foundInWallet:foundInWallet includeForeignBlockchainIdentities:NO];
}

- (DSBlockchainIdentity *_Nullable)blockchainIdentityThatCreatedContract:(DPContract *)contract withContractId:(UInt256)contractId foundInWallet:(DSWallet **)foundInWallet {
    NSAssert(uint256_is_not_zero(contractId), @"contractId must not be null");
    for (DSWallet *wallet in self.wallets) {
        DSBlockchainIdentity *blockchainIdentity = [wallet blockchainIdentityThatCreatedContract:contract withContractId:contractId];
        if (blockchainIdentity) {
            if (foundInWallet) {
                *foundInWallet = wallet;
            }
            return blockchainIdentity;
        }
    }
    return nil;
}

- (DSBlockchainIdentity *)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet **)foundInWallet includeForeignBlockchainIdentities:(BOOL)includeForeignBlockchainIdentities {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    for (DSWallet *wallet in self.wallets) {
        DSBlockchainIdentity *blockchainIdentity = [wallet blockchainIdentityForUniqueId:uniqueId];
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

- (void)wipeBlockchainIdentitiesPersistedDataInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        NSArray *objects = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@", [self chainEntityInContext:context]];
        [DSBlockchainIdentityEntity deleteObjects:objects inContext:context];
    }];
}

// MARK: - Invitations

- (uint32_t)localBlockchainInvitationsCount {
    uint32_t blockchainInvitationsCount = 0;
    for (DSWallet *lWallet in self.wallets) {
        blockchainInvitationsCount += [lWallet blockchainInvitationsCount];
    }
    return blockchainInvitationsCount;
}

- (void)wipeBlockchainInvitationsPersistedDataInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        NSArray *objects = [DSBlockchainInvitationEntity objectsInContext:context matching:@"chain == %@", [self chainEntityInContext:context]];
        [DSBlockchainInvitationEntity deleteObjects:objects inContext:context];
    }];
}


// MARK: - Registering special transactions


- (BOOL)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil];
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil];
    DSWallet *holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil];
    DSWallet *platformNodeWallet = [self walletHavingPlatformNodeAuthenticationHash:providerRegistrationTransaction.platformNodeID foundAtIndex:nil];
    DSAccount *account = [self accountContainingAddress:providerRegistrationTransaction.payoutAddress];
    BOOL registered = NO;
    registered |= [account registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [ownerWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [votingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [operatorWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [holdingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [platformNodeWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    
    if (ownerWallet) {
        DSAuthenticationKeysDerivationPath *ownerDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:ownerWallet];
        [ownerDerivationPath registerTransactionAddress:providerRegistrationTransaction.ownerAddress];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerRegistrationTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerRegistrationTransaction.operatorAddress];
    }
    
    if (holdingWallet) {
        DSMasternodeHoldingsDerivationPath *holdingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:holdingWallet];
        [holdingDerivationPath registerTransactionAddress:providerRegistrationTransaction.holdingAddress];
    }
    
    if (platformNodeWallet) {
        DSAuthenticationKeysDerivationPath *platformNodeDerivationPath = [[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:platformNodeWallet];
        [platformNodeDerivationPath registerTransactionAddress:providerRegistrationTransaction.platformNodeAddress];
    }
    
    return registered;
}

- (BOOL)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)providerUpdateServiceTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount *account = [self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    }
    return registered;
}


- (BOOL)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)providerUpdateRegistrarTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount *account = [self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.operatorAddress];
    }
    return registered;
}

- (BOOL)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)providerUpdateRevocationTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
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

- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        return [self registerProviderRegistrationTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        return [self registerProviderUpdateServiceTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        return [self registerProviderUpdateRegistrarTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        return [self registerProviderUpdateRevocationTransaction:providerUpdateRevocationTransaction saveImmediately:saveImmediately];
    }
    return FALSE;
}

// MARK: - Special Transactions

//Does the chain mat
- (BOOL)transactionHasLocalReferences:(DSTransaction *)transaction {
    if ([self firstAccountThatCanContainTransaction:transaction]) return TRUE;
    
    //PROVIDERS
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self walletHavingPlatformNodeAuthenticationHash:providerRegistrationTransaction.platformNodeID foundAtIndex:nil]) return TRUE;
        if ([self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil]) return TRUE;
        if ([self accountContainingAddress:providerRegistrationTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        if ([self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        if ([self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
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

- (void)triggerUpdatesForLocalReferences:(DSTransaction *)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil] ||
            [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil] ||
            [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil] ||
            [self walletHavingPlatformNodeAuthenticationHash:providerRegistrationTransaction.platformNodeID foundAtIndex:nil]) {
            [self.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:TRUE];
        }
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateServiceTransaction:providerUpdateServiceTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRegistrarTransaction:providerUpdateRegistrarTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRevocationTransaction:providerUpdateRevocationTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSCreditFundingTransaction class]]) {
        DSCreditFundingTransaction *creditFundingTransaction = (DSCreditFundingTransaction *)transaction;
        uint32_t index;
        DSWallet *wallet = [self walletHavingBlockchainIdentityCreditFundingRegistrationHash:creditFundingTransaction.creditBurnPublicKeyHash foundAtIndex:&index];
        if (wallet) {
            DSBlockchainIdentity *blockchainIdentity = [wallet blockchainIdentityForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];
            if (!blockchainIdentity) {
                blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:creditFundingTransaction withUsernameDictionary:nil inWallet:wallet];
                [blockchainIdentity registerInWalletForRegistrationFundingTransaction:creditFundingTransaction];
            }
        } else {
            wallet = [self walletHavingBlockchainIdentityCreditFundingInvitationHash:creditFundingTransaction.creditBurnPublicKeyHash foundAtIndex:&index];
            if (wallet) {
                DSBlockchainInvitation *blockchainInvitation = [wallet blockchainInvitationForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];
                if (!blockchainInvitation) {
                    blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:index withFundingTransaction:creditFundingTransaction inWallet:wallet];
                    [blockchainInvitation registerInWalletForRegistrationFundingTransaction:creditFundingTransaction];
                }
            }
        }
    }
}

- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(NSArray *)simplifiedMasternodeEntries {
    for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in simplifiedMasternodeEntries) {
        NSString *votingAddress = simplifiedMasternodeEntry.votingAddress;
        NSString *operatorAddress = simplifiedMasternodeEntry.operatorAddress;
        NSString *platformNodeAddress = simplifiedMasternodeEntry.platformNodeAddress;
        for (DSWallet *wallet in self.wallets) {
            DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
            if ([providerOperatorKeysDerivationPath containsAddress:operatorAddress]) {
                [providerOperatorKeysDerivationPath registerTransactionAddress:operatorAddress];
            }
            DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
            if ([providerVotingKeysDerivationPath containsAddress:votingAddress]) {
                [providerVotingKeysDerivationPath registerTransactionAddress:votingAddress];
            }
            DSAuthenticationKeysDerivationPath *platformNodeKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:wallet];
            if ([platformNodeKeysDerivationPath containsAddress:platformNodeAddress]) {
                [platformNodeKeysDerivationPath registerTransactionAddress:platformNodeAddress];
            }
        }
    }
}

// MARK: - Merging Wallets

- (DSWallet *)walletHavingBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainIdentityCreditFundingRegistrationHash:creditFundingRegistrationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainIdentityCreditFundingTopupHash:creditFundingTopupHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingBlockchainIdentityCreditFundingInvitationHash:(UInt160)creditFundingInvitationHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainIdentityCreditFundingInvitationHash:creditFundingInvitationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderVotingAuthenticationHash:votingAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOwningAuthenticationHash:owningAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOperatorAuthenticationKey:providerOperatorAuthenticationKey];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingPlatformNodeAuthenticationHash:(UInt160)platformNodeAuthenticationHash foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfPlatformNodeAuthenticationHash:platformNodeAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction *_Nonnull)transaction foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        for (DSTransactionOutput *output in transaction.outputs) {
            NSString *address = output.address;
            if (!address || address == (id)[NSNull null]) continue;
            NSUInteger index = [wallet indexOfHoldingAddress:address];
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

- (DSChainEntity *)chainEntityInContext:(NSManagedObjectContext *)context {
    NSParameterAssert(context);
    __block DSChainEntity *chainEntity = nil;
    [context performBlockAndWait:^{
        chainEntity = [DSChainEntity chainEntityForType:self.chainType checkpoints:self.checkpoints inContext:context];
    }];
    return chainEntity;
}

- (void)save {
    if (self.isTransient) return;
    [self saveInContext:self.chainManagedObjectContext];
}

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSChainEntity *entity = [self chainEntityInContext:context];
        entity.totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        entity.baseBlockHash = [NSData dataWithUInt256:self.masternodeBaseBlockHash];
        [context ds_save];
    }];
}

- (void)saveBlockLocators {
    if (self.isTransient) return;
    //    NSAssert(self.chainManager.syncPhase == DSChainSyncPhase_ChainSync || self.chainManager.syncPhase == DSChainSyncPhase_Synced,@"This should only be happening in chain sync phase");
    [self prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:self.lastSyncBlockHeight];
    DSBlock *lastBlock = self.lastSyncBlock;
    UInt256 lastBlockHash = lastBlock.blockHash;
    uint32_t lastBlockHeight = lastBlock.height;
    [self.chainManagedObjectContext performBlockAndWait:^{
        DSChainEntity *chainEntity = [self chainEntityInContext:self.chainManagedObjectContext];
        
        chainEntity.syncBlockHash = uint256_data(lastBlockHash);
        chainEntity.syncBlockHeight = lastBlockHeight;
        chainEntity.syncBlockTimestamp = lastBlock.timestamp;
        chainEntity.syncBlockChainWork = uint256_data(lastBlock.chainWork);
        NSArray *array = [self chainSyncBlockLocatorArray];
        _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:BIP39_CREATION_TIME includeInitialTerminalBlocks:NO];
        chainEntity.syncLocators = array;
        
        NSMutableSet *entities = [NSMutableSet set];
        
        [self persistIncomingTransactionsAttributesForBlockSaveWithNumber:lastBlockHeight inContext:self.chainManagedObjectContext];
        
        for (DSTransactionHashEntity *e in [DSTransactionHashEntity objectsInContext:self.chainManagedObjectContext matching:@"txHash in %@", [self.transactionHashHeights allKeys]]) {
            e.blockHeight = [self.transactionHashHeights[e.txHash] intValue];
            e.timestamp = [self.transactionHashTimestamps[e.txHash] intValue];
            ;
            [entities addObject:e];
        }
        for (DSTransactionHashEntity *e in entities) {
            DSLogPrivate(@"blockHeight is %u for %@", e.blockHeight, e.txHash);
        }
        self.transactionHashHeights = [NSMutableDictionary dictionary];
        self.transactionHashTimestamps = [NSMutableDictionary dictionary];
        
        [self.chainManagedObjectContext ds_save];
    }];
}

- (void)saveTerminalBlocks {
    if (self.isTransient) return;
    NSMutableDictionary<NSData *, DSBlock *> *blocks = [NSMutableDictionary dictionary];
    DSBlock *b = self.lastTerminalBlock;
    uint32_t endHeight = b.height;
    uint32_t startHeight = b.height;
    NSDictionary *terminalBlocks = [self.mTerminalBlocks copy];
    while (b && (startHeight > self.lastCheckpoint.height) && (endHeight - startHeight < KEEP_RECENT_TERMINAL_BLOCKS)) {
        blocks[[NSData dataWithUInt256:b.blockHash]] = b;
        startHeight = b.height;
        b = terminalBlocks[b.prevBlockValue];
    }
    if (startHeight == b.height) { //only save last one then
        blocks[[NSData dataWithUInt256:b.blockHash]] = b;
    }
    [self.chainManagedObjectContext performBlockAndWait:^{
        if ([[DSOptionsManager sharedInstance] keepHeaders]) {
            //only remove orphan chains
            NSArray<DSMerkleBlockEntity *> *recentOrphans = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && (height > %u) && !(blockHash in %@)", [self chainEntityInContext:self.chainManagedObjectContext], startHeight, blocks.allKeys];
            if ([recentOrphans count]) DSLog(@"%lu recent orphans will be removed from disk", (unsigned long)[recentOrphans count]);
            [DSMerkleBlockEntity deleteObjects:recentOrphans inContext:self.chainManagedObjectContext];
        } else {
            //remember to not delete blocks needed for quorums
            NSArray<DSMerkleBlockEntity *> *oldBlockHeaders = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && masternodeList == NIL && (usedByQuorums.@count == 0) && !(blockHash in %@)", [self chainEntityInContext:self.chainManagedObjectContext], blocks.allKeys];
            /*for (DSMerkleBlockEntity *e in oldBlockHeaders) {
             DSLog(@"• remove Merkle block: %u: %@", e.height, e.blockHash.hexString);
             }*/
            [DSMerkleBlockEntity deleteObjects:oldBlockHeaders inContext:self.chainManagedObjectContext];
        }
        DSChainEntity *chainEntity = [self chainEntityInContext:self.chainManagedObjectContext];
        NSArray<DSMerkleBlockEntity *> *blockEntities = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"blockHash in %@", blocks.allKeys];
        for (DSMerkleBlockEntity *e in blockEntities) {
            @autoreleasepool {
                NSData *blockHash = e.blockHash;
                [e setAttributesFromBlock:blocks[blockHash] forChainEntity:chainEntity];
                //DSLog(@"+ add Merkle block.1: %u: %@", e.height, e.blockHash.hexString);
                [blocks removeObjectForKey:blockHash];
            }
        }
        
        for (DSBlock *block in blocks.allValues) {
            @autoreleasepool {
                DSMerkleBlockEntity *e = [DSMerkleBlockEntity managedObjectInBlockedContext:self.chainManagedObjectContext];
                [e setAttributesFromBlock:block forChainEntity:chainEntity];
                //DSLog(@"+ add Merkle block.2: %u: %@", e.height, e.blockHash.hexString);
            }
        }
        
        [self.chainManagedObjectContext ds_save];
    }];
}

// MARK: Persistence Helpers

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    for (DSWallet *wallet in self.wallets) {
        [wallet prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
    }
}

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context {
    for (DSWallet *wallet in self.wallets) {
        [wallet persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber inContext:context];
    }
}


// MARK: - Description

- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}", self.name]];
}

@end
