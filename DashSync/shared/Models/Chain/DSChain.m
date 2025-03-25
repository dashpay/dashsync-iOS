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

#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSBlock+Protected.h"
#import "DSBloomFilter.h"
#import "DSChain.h"
#import "DSChain+Checkpoint.h"
#import "DSChain+Identity.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainCheckpoints.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSChainsManager.h"
#import "DSCheckpoint.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSDerivationPathFactory.h"
#import "DSFullBlock.h"
#import "DSFundsDerivationPath.h"
#import "DSGapLimit.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSInsightManager.h"
#import "DSLocalMasternode+Protected.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSOptionsManager.h"
#import "DSPeerManager.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSObject+Notification.h"
#import "NSString+Bitcoin.h"

#define FEE_PER_BYTE_KEY @"FEE_PER_BYTE"

#define CHAIN_STANDALONE_DERIVATIONS_KEY @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY @"REGISTERED_PEERS_KEY"

#define ISLOCK_QUORUM_TYPE @"ISLOCK_QUORUM_TYPE"
#define ISDLOCK_QUORUM_TYPE @"ISDLOCK_QUORUM_TYPE"
#define CHAINLOCK_QUORUM_TYPE @"CHAINLOCK_QUORUM_TYPE"
#define PLATFORM_QUORUM_TYPE @"PLATFORM_QUORUM_TYPE"

#define CHAIN_VOTING_KEYS_KEY @"CHAIN_VOTING_KEYS_KEY"

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
@property (nonatomic, strong) DSAccount *viewingAccount;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<DSPeer *> *> *estimatedBlockHeights;
@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashHeights;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashTimestamps;
@property (nonatomic, strong) NSManagedObjectContext *chainManagedObjectContext;
@property (nonatomic, assign, getter=isTransient) BOOL transient;

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

- (instancetype)initWithType:(DChainType *)type checkpoints:(NSArray *)checkpoints {
    if (!(self = [self init])) return nil;
    
    NSAssert(!dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(type), @"DevNet should be configured with initAsDevnetWithIdentifier:version:checkpoints:port:dapiPort:dapiGRPCPort:dpnsContractID:dashpayContractID:");
    self.chainType = type;
    self.standardPort = dash_spv_crypto_network_chain_type_ChainType_standard_port(type);
    self.standardDapiJRPCPort = dash_spv_crypto_network_chain_type_ChainType_standard_dapi_jrpc_port(type);
    self.headersMaxAmount = dash_spv_crypto_network_chain_type_ChainType_header_max_amount(type);
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].blockHash;
    self.checkpointsByHashDictionary = [NSMutableDictionary dictionary];
    self.checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
    self.shareCore = [[DSDashSharedCore alloc] initOnChain:self];

    return self;
}

- (instancetype)initAsDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
                         onProtocolVersion:(uint32_t)protocolVersion
                               checkpoints:(NSArray<DSCheckpoint *> *)checkpoints {
    //for devnet the genesis checkpoint is really the second block
    if (!(self = [self init])) return nil;
    self.chainType = dash_spv_crypto_network_chain_type_ChainType_DevNet_ctor(devnetType);
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
    self.headersMaxAmount = dash_spv_crypto_network_chain_type_ChainType_header_max_amount(self.chainType);
    self.shareCore = [[DSDashSharedCore alloc] initOnChain:self];

    return self;
}

- (instancetype)initAsDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
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

- (Runtime *)sharedRuntime {
    return self.shareCore.runtime;
}

- (DArcProcessor *)sharedProcessor {
    return self.shareCore.processor;
}
- (DProcessor *)sharedProcessorObj {
    return self.sharedProcessor->obj;
}
//- (DArcCache *)sharedCache {
//    return self.shareCore.cache;
//}
//- (DCache *)sharedCacheObj {
//    return self.sharedCache->obj;
//}
- (DArcPlatformSDK *)sharedPlatform {
    return self.shareCore.platform;
}
- (PlatformSDK *)sharedPlatformObj {
    return self.sharedPlatform->obj;
}

- (ContactRequestManager *)sharedContactsObj {
    return self.shareCore.contactRequests->obj;
}

- (IdentitiesManager *)sharedIdentitiesObj {
    return self.shareCore.identitiesManager->obj;
}

- (DocumentsManager *)sharedDocumentsObj {
    return self.shareCore.documentsManager->obj;
}

- (ContractsManager *)sharedContractsObj {
    return self.shareCore.contractsManager->obj;
}

- (SaltedDomainHashesManager *)sharedSaltedDomainHashesObj {
    return self.shareCore.saltedDomainHashes->obj;
}


+ (DSChain *)mainnet {
    static DSChain *_mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:dash_spv_crypto_network_chain_type_ChainType_MainNet_ctor() checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array) / sizeof(*mainnet_checkpoint_array))]];
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
        _testnet = [[DSChain alloc] initWithType:dash_spv_crypto_network_chain_type_ChainType_TestNet_ctor() checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array) / sizeof(*testnet_checkpoint_array))]];
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

+ (DSChain *)recoverKnownDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
                              withCheckpoints:(NSArray<DSCheckpoint *> *)checkpointArray
                                 performSetup:(BOOL)performSetup {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain *devnetChain = nil;
    __block BOOL inSetUp = FALSE;
//    char *identifier = dash_spv_crypto_network_chain_type_DevnetType_identifier(devnetType);
    @synchronized(self) {
        NSString *devnetIdentifier = [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_DevnetType_identifier(devnetType)];
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

+ (DSChain *)setUpDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
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
        NSString *devnetIdentifier = [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_DevnetType_identifier(devnetType)];
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
- (DSMasternodeManager *)masternodeManager {
    return [[self chainManager] masternodeManager];
}


- (BOOL)isEqual:(id)obj {
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], self.genesisHash));
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

- (DSCheckpoint *)createDevNetGenesisBlockCheckpointForParentCheckpoint:(DSCheckpoint *)checkpoint
                                                         withIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)identifier
                                                      onProtocolVersion:(uint32_t)protocolVersion {
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


// MARK: - Keychain Strings


- (NSString *)chainStandaloneDerivationPathsKey {
    return [NSString stringWithFormat:@"%@_%@", CHAIN_STANDALONE_DERIVATIONS_KEY, [self uniqueID]];
}

- (NSString *)registeredPeersKey {
    return [NSString stringWithFormat:@"%@_%@", REGISTERED_PEERS_KEY, [self uniqueID]];
}


// MARK: - L1 Chain Parameters

// MARK: Local Parameters

- (NSArray<DSDerivationPath *> *)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    if (accountNumber == 0) {
        return @[[DSFundsDerivationPath bip32DerivationPathForAccountNumber:accountNumber onChain:self],
                 [DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self],
                 [DSDerivationPath masterIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self],
                 [DSFundsDerivationPath coinJoinDerivationPathForAccountNumber:accountNumber onChain:self]];
    } else {
        //don't include BIP32 derivation path on higher accounts
        return @[[DSFundsDerivationPath bip44DerivationPathForAccountNumber:accountNumber onChain:self],
                 [DSDerivationPath masterIdentityContactsDerivationPathForAccountNumber:accountNumber onChain:self],
                 [DSFundsDerivationPath coinJoinDerivationPathForAccountNumber:accountNumber onChain:self]];
    }
}


- (BOOL)syncsBlockchain { //required for SPV wallets
    return ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_NeedsWalletSyncType) != 0;
}

- (BOOL)needsInitialTerminalHeadersSync {
    return !(self.estimatedBlockHeight == self.lastTerminalBlockHeight);
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
- (uint32_t)chainTipHeight {
    return self.lastTerminalBlock.height;
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
    [self notify:DSChainStandaloneDerivationPathsDidChangeNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
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
    [self notify:DSChainStandaloneDerivationPathsDidChangeNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
}

- (NSArray *)standaloneDerivationPaths {
    return [self.viewingAccount fundDerivationPaths];
}

// MARK: - Probabilistic Filters


- (NSArray<NSString *> *)newAddressesForBloomFilter {
    NSMutableArray *allAddressesArray = [NSMutableArray array];
    for (DSWallet *wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithProlongGapLimit];
        [allAddressesArray addObjectsFromArray:[wallet allAddresses]];
    }

    for (DSFundsDerivationPath *derivationPath in self.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithSettings:[DSGapLimitFunds external:SEQUENCE_GAP_LIMIT_EXTERNAL]];
        [derivationPath registerAddressesWithSettings:[DSGapLimitFunds internal:SEQUENCE_GAP_LIMIT_INTERNAL]];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddressesArray addObjectsFromArray:addresses];
    }
    return allAddressesArray;
}

- (DSBloomFilter *)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak {
    NSMutableSet *allAddresses = [NSMutableSet set];
    NSMutableSet *allUTXOs = [NSMutableSet set];
    for (DSWallet *wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithInitialGapLimit];
        [allUTXOs addObjectsFromArray:wallet.unspentOutputs];
        [allAddresses addObjectsFromArray:[wallet allAddresses]];
    }
    
    for (DSFundsDerivationPath *derivationPath in self.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithSettings:[DSGapLimitFunds external:SEQUENCE_GAP_LIMIT_INITIAL]];
        [derivationPath registerAddressesWithSettings:[DSGapLimitFunds internal:SEQUENCE_GAP_LIMIT_INITIAL]];
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
    DSCheckpoint *checkpoint = [self lastTerminalCheckpoint];
    if (checkpoint) {
        if (self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)]) {
            _lastTerminalBlock = self.mSyncBlocks[uint256_obj(checkpoint.blockHash)];
        } else {
            _lastTerminalBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self];
            self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)] = _lastTerminalBlock;
        }
    }
    
    if (_lastTerminalBlock) {
        DSLog(@"[%@] last terminal block at height %d chosen from checkpoints (hash is %@)", self.name, _lastTerminalBlock.height, [NSData dataWithUInt256:_lastTerminalBlock.blockHash].hexString);
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
        DSLog(@"[%@] last sync block at height %d chosen from checkpoints (hash is %@)", self.name, _lastSyncBlock.height, [NSData dataWithUInt256:_lastSyncBlock.blockHash].hexString);
    }
}

- (DSBlock *)lastSyncBlockDontUseCheckpoints {
    return [self lastSyncBlockWithUseCheckpoints:NO];
}

- (DSBlock *)lastSyncBlock {
    return [self lastSyncBlockWithUseCheckpoints:YES];
}

- (void)resetLastSyncBlock {
    _lastSyncBlock = nil;
}


- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints {
    if (_lastSyncBlock) return _lastSyncBlock;
    
    if (!_lastSyncBlock && uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) && uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) && self.lastPersistedChainSyncBlockHeight != BLOCK_UNKNOWN_HEIGHT) {
        _lastSyncBlock = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash prevBlock:UINT256_ZERO timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight chainWork:self.lastPersistedChainSyncBlockChainWork onChain:self];
    }
    
    if (!_lastSyncBlock && useCheckpoints) {
        DSLog(@"[%@] No last Sync Block, setting it from checkpoints", self.name);
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
                self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
                self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
            }
        }];
        
        return _mSyncBlocks;
    }
}

- (NSArray<NSData *> *)chainSyncBlockLocatorArray {
    
    if (_lastSyncBlock && !(_lastSyncBlock.height == 1 && dash_spv_crypto_network_chain_type_ChainType_is_devnet_any(self.chainType))) {
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
- (DSBlock *_Nullable)blockUntilGetInsightForBlockHeight:(uint32_t)blockHeight {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block DSBlock *b = NULL;
    [[DSInsightManager sharedInstance] blockForBlockHeight:blockHeight onChain:self completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
        if (!error && block) {
            [self addInsightVerifiedBlock:block forBlockHash:block.blockHash];
            b = block;
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return b;
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
        self.chainManager.syncState.estimatedBlockHeight = _bestEstimatedBlockHeight;
        // notify that transaction confirmations may have changed
        [self.chainManager notifySyncStateChanged];
    }
    
    return TRUE;
}

//TRUE if it was added to the end of the chain
- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *)peer {
    NSString *prefix = [NSString stringWithFormat:@"[%@: %@:%d]", self.name, peer.host ? peer.host : @"TEST", peer.port];
    if (peer && !self.chainManager.syncPhase) {
        DSLog(@"%@ Block was received from peer after reset, ignoring it", prefix);
        return FALSE;
    }
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSBlock *prev = nil;
    DSLog(@"[%@] + block (asHeader: %u) %@ prev: %@", self.name, isHeaderOnly, uint256_hex(block.blockHash), uint256_hex(block.prevBlock));

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
            DSLog(@"%@ printing previous block at height %d : %@", prefix, merkleBlock.height, merkleBlock.blockHashValue);
        }
#endif
        DSLog(@"%@ relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", prefix,
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
            DSLog(@"%@ relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", prefix,
                  block.height, block.target, foundDifficulty, blockHash);
            
            if (peer) {
                [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
        
        UInt256 difficulty = setCompactLE(block.target);
        if (uint256_sup(block.blockHash, difficulty)) {
            DSLog(@"%@ relayed block with invalid block hash %d target %x, blockHash: %@ difficulty: %@", prefix,
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
        DSLog(@"%@ relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              prefix, block.height, blockHash, uint256_hex(checkpoint.blockHash));
        if (peer) {
            [self.chainManager chain:self badBlockReceivedFromPeer:peer];
        }
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    uint32_t h = block.height;
    if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && uint256_eq(block.prevBlock, self.lastSyncBlockHash)) { // new block extends sync chain
        if ((block.height % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ + sync block at: %d: %@", prefix, h, uint256_hex(block.blockHash));
        }
        self.mSyncBlocks[blockHash] = block;
        if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
            [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
        }
        self.lastSyncBlock = block;
        self.chainManager.syncState.lastSyncBlockHeight = block.height;
        if (!equivalentTerminalBlock && uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) {
            if ((h % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
                DSLog(@"%@ + terminal block (caught up) at: %d: %@", prefix, h, uint256_hex(block.blockHash));
            }
            self.mTerminalBlocks[blockHash] = block;
            self.lastTerminalBlock = block;
            self.chainManager.syncState.lastTerminalBlockHeight = block.height;
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
            ((h % 1000 == 0) && (h + BLOCK_NO_FORK_DEPTH < self.lastTerminalBlockHeight) && !self.shareCore.hasMasternodeListCurrentlyBeingSaved)) {
            [self saveBlockLocators];
        }
        
    } else if (uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) { // new block extends terminal chain
        if ((h % 500) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ + terminal block at: %d: %@", prefix, h, uint256_hex(block.blockHash));
        }
        self.mTerminalBlocks[blockHash] = block;
        self.lastTerminalBlock = block;
        self.chainManager.syncState.estimatedBlockHeight = self.estimatedBlockHeight;
        self.chainManager.syncState.lastTerminalBlockHeight = block.height;

        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }
        if (h == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    } else if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && self.mSyncBlocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ relayed existing sync block at height %d", prefix, h);
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
            if (h == self.lastSyncBlockHeight) {
                self.lastSyncBlock = block;
                self.chainManager.syncState.estimatedBlockHeight = self.estimatedBlockHeight;
                self.chainManager.syncState.lastSyncBlockHeight = block.height;
            }
        }
    } else if (self.mTerminalBlocks[blockHash] != nil && (blockPosition & DSBlockPosition_Terminal)) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ relayed existing terminal block at height %d (last sync height %d)", prefix, h, self.lastSyncBlockHeight);
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
            if (h == self.lastTerminalBlockHeight) {
                self.lastTerminalBlock = block;
                self.chainManager.syncState.lastTerminalBlockHeight = block.height;
            }
        }
    } else {                                                // new block is on a fork
        if (h <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            DSLog(@"%@ ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@", prefix, h, blockHash);
            return TRUE;
        }
        
        if (h <= DChainLockBlockHeight(self.lastChainLock.lock)) {
            DSLog(@"%@ ignoring block on fork when main chain is chainlocked: %d, blockHash: %@", prefix, h, blockHash);
            return TRUE;
        }
        
        DSLog(@"%@ potential chain fork to height %d blockPosition %d", prefix, block.height, blockPosition);
        if (!(blockPosition & DSBlockPosition_Sync)) {
            //this is only a reorg of the terminal blocks
            self.mTerminalBlocks[blockHash] = block;
            if (uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSLog(@"%@ found potential chain fork on height %d", prefix, block.height);
            
            DSBlock *b = block, *b2 = self.lastTerminalBlock;
            
            while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                b = self.mTerminalBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
            }
            
            if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                DSLog(@"%@ no reorganizing chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                return TRUE;
            }
            
            DSLog(@"%@ reorganizing terminal chain from height %d, new height is %d", prefix, b.height, h);
            
            self.lastTerminalBlock = block;
            self.chainManager.syncState.lastTerminalBlockHeight = block.height;
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
            DSLog(@"%@ found sync chain fork on height %d", prefix, h);
            if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && !uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) {
                DSBlock *b = block, *b2 = self.lastTerminalBlock;
                
                while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                    b = self.mTerminalBlocks[b.prevBlockValue];
                    if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
                }
                
                if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                    DSLog(@"%@ no reorganizing chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                } else {
                    DSLog(@"%@ reorganizing terminal chain from height %d, new height is %d", prefix, b.height, h);
                    self.lastTerminalBlock = block;
                    self.chainManager.syncState.lastTerminalBlockHeight = block.height;
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
                DSLog(@"%@ no reorganizing sync chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                return TRUE;
            }
            
            DSLog(@"%@ reorganizing sync chain from height %d, new height is %d", prefix, b.height, h);
            
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
            self.chainManager.syncState.lastSyncBlockHeight = block.height;
            if (h == self.estimatedBlockHeight) syncDone = YES;
        }
    }
    
    if ((blockPosition & DSBlockPosition_Terminal) && checkpoint && checkpoint == [self lastCheckpointHavingMasternodeList]) {
        [self.chainManager.masternodeManager restoreState];
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
            [self notify:DSChainInitialHeadersDidFinishSyncingNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
        }
        if ((blockPosition & DSBlockPosition_Sync) && (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced)) {
            //we should only save
            [self saveBlockLocators];
            savedBlockLocators = YES;
            if (peer) {
                [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self fromPeer:peer onMainChain:onMainChain];
            }
            [self notify:DSChainBlocksDidFinishSyncingNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
        }
    }
    
    if (((blockPosition & DSBlockPosition_Terminal) && block.height > self.estimatedBlockHeight) || ((blockPosition & DSBlockPosition_Sync) && block.height >= self.lastTerminalBlockHeight)) {
        @synchronized (self) {
            _bestEstimatedBlockHeight = block.height;
            self.chainManager.syncState.estimatedBlockHeight = _bestEstimatedBlockHeight;
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
    }
    [self.chainManager notifySyncStateChanged];
    // check if the next block was received as an orphan
    if (block == self.lastTerminalBlock && self.mOrphans[blockHash]) {
        DSBlock *b = self.mOrphans[blockHash];
        
        [self.mOrphans removeObjectForKey:blockHash];
        [self addBlock:b receivedAsHeader:YES fromPeer:peer]; //revisit this
    }
    return TRUE;
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
                self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
                self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
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
                DSLog(@"[%@] last terminal block at height %d recovered from db (hash is %@)", self.name, lastTerminalBlock.height, [NSData dataWithUInt256:lastTerminalBlock.blockHash].hexString);
            }
        }
    }];

    @synchronized (self) {
        if (!_lastTerminalBlock) {
            // if we don't have any headers yet, use the latest checkpoint
            DSCheckpoint *lastCheckpoint = [self lastTerminalCheckpoint];
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
    DSBlock *terminalBlock = self.mTerminalBlocks[uint256_obj(chainLock.blockHashData.UInt256)];
    [terminalBlock setChainLockedWithChainLock:chainLock];
    if ((terminalBlock.chainLocked) && (![self recentTerminalBlockForBlockHash:terminalBlock.blockHash])) {
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        DSLog(@"[%@] Added a chain lock for block %@ that was not on the main terminal chain ending in %@, reorginizing", self.name, terminalBlock, self.lastSyncBlock);
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
            DSLog(@"[%@] Cancelling terminal reorg because block %@ is already chain locked", self.name, tbmc);
        } else {
            DSLog(@"[%@] Reorginizing to height %d", self.name, clb.height);
            
            self.lastTerminalBlock = terminalBlock;
            self.chainManager.syncState.lastTerminalBlockHeight = terminalBlock.height;
            [self.chainManager notifySyncStateChanged];
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
    DSBlock *syncBlock = self.mSyncBlocks[uint256_obj(chainLock.blockHashData.UInt256)];
    [syncBlock setChainLockedWithChainLock:chainLock];
    DSBlock *sbmc = self.lastSyncBlockDontUseCheckpoints;
    if (sbmc && (syncBlock.chainLocked) && ![self recentSyncBlockForBlockHash:syncBlock.blockHash]) { //!OCLINT
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        DSLog(@"[%@] Added a chain lock for block %@ that was not on the main sync chain ending in %@, reorginizing", self.name, syncBlock, self.lastSyncBlock);
        
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
            DSLog(@"[%@] Cancelling sync reorg because block %@ is already chain locked", self.name, sbmc);
        } else {
            self.lastSyncBlock = syncBlock;
            self.chainManager.syncState.lastSyncBlockHeight = syncBlock.height;
            [self.chainManager notifySyncStateChanged];
            DSLog(@"[%@] Reorginizing to height %d (last sync block %@)", self.name, clb.height, self.lastSyncBlock);
            
            
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
    return NO;
//    return !self.isMainnet;
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
        }
        dispatch_once(&onceToken, ^{
            self.chainManager.syncState.estimatedBlockHeight = finalEstimatedBlockHeight;
        });
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
            self.chainManager.syncState.estimatedBlockHeight = 0;
        }
    }
}





// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context {
    DSLog(@"[%@] Wiping Blockchain Info", self.name);
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeIdentitiesPersistedDataInContext:context];
    [self wipeInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalIdentities];
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
    DSLog(@"[%@] Wiping Blockchain Non Terminal Info", self.name);
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeIdentitiesPersistedDataInContext:context];
    [self wipeInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalIdentities];
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
    DSLog(@"[%@] Wiping Masternode Info", self.name);
    DSChainEntity *chainEntity = [self chainEntityInContext:context];
    [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
    [self.chainManager wipeMasternodeInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@", self.uniqueID, LAST_SYNCED_MASTERNODE_LIST]];
}

- (void)wipeWalletsAndDerivatives {
    DSLog(@"[%@] Wiping Wallets and Derivatives", self.name);
    [self unregisterAllWallets];
    [self unregisterAllStandaloneDerivationPaths];
    self.mWallets = [NSMutableArray array];
    self.viewingAccount = nil;
}





- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(DMasternodeEntryList *)simplifiedMasternodeEntries {
    for (int i = 0; i < simplifiedMasternodeEntries->count; i++) {
        DMasternodeEntry *entry = simplifiedMasternodeEntries->values[i];
        NSString *votingAddress = [DSKeyManager NSStringFrom:DMasternodeEntryVotingAddress(entry->masternode_list_entry->key_id_voting, self.chainType)];
        NSString *operatorAddress = [DSKeyManager NSStringFrom:DMasternodeEntryOperatorPublicKeyAddress(entry->masternode_list_entry->operator_public_key, self.chainType)];
        NSString *platformNodeAddress = nil;
        switch (entry->masternode_list_entry->mn_type->tag) {
            case dashcore_sml_masternode_list_entry_EntryMasternodeType_Regular:
                break;
            case dashcore_sml_masternode_list_entry_EntryMasternodeType_HighPerformance:
                platformNodeAddress = [DSKeyManager NSStringFrom:DMasternodeEntryEvoNodeAddress(entry->masternode_list_entry->mn_type->high_performance.platform_node_id, self.chainType)];
                break;
        }
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
            DSLogPrivate(@"[%@] blockHeight is %u for %@", self.name, e.blockHeight, e.txHash);
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
            if ([recentOrphans count]) DSLog(@"[%@] %lu recent orphans will be removed from disk", self.name, (unsigned long)[recentOrphans count]);
            for (DSMerkleBlockEntity *e in recentOrphans) {
                DSLog(@"[%@] remove orphan MerkleBlockEntity: %u: %@", self.name, e.height, e.blockHash.hexString);
            }
            [DSMerkleBlockEntity deleteObjects:recentOrphans inContext:self.chainManagedObjectContext];
        } else {

            //remember to not delete blocks needed for quorums
            // TODO: check how this change really affects in runtime
            NSSet<NSData *> *blockSet = [[self.masternodeManager blockHashesUsedByMasternodeLists] setByAddingObjectsFromArray:blocks.allKeys];
            NSArray<DSMerkleBlockEntity *> *oldBlockHeaders = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && !(blockHash in %@)", [self chainEntityInContext:self.chainManagedObjectContext], blockSet];
//            NSArray<DSMerkleBlockEntity *> *oldBlockHeaders = [DSMerkleBlockEntity objectsInContext:self.chainManagedObjectContext matching:@"(chain == %@) && masternodeList == NIL && (usedByQuorums.@count == 0) && !(blockHash in %@)", [self chainEntityInContext:self.chainManagedObjectContext], blocks.allKeys];
//            for (DSMerkleBlockEntity *e in oldBlockHeaders) {
//                DSLog(@"[%@] remove MerkleBlockEntity: %u: %@", self.name, e.height, e.blockHash.hexString);
//            }
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
