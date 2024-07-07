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
#import "DSBlocksCache.h"
#import "DSBlocksCache+Protected.h"
#import "DSBloomFilter.h"
#import "DSChain+Blocks.h"
#import "DSChain+Checkpoints.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Wallets.h"
#import "DSChainCheckpoints.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSChainParams.h"
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


#define CHAIN_WALLETS_KEY @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY @"REGISTERED_PEERS_KEY"


#define ISLOCK_QUORUM_TYPE @"ISLOCK_QUORUM_TYPE"
#define ISDLOCK_QUORUM_TYPE @"ISDLOCK_QUORUM_TYPE"
#define CHAINLOCK_QUORUM_TYPE @"CHAINLOCK_QUORUM_TYPE"
#define PLATFORM_QUORUM_TYPE @"PLATFORM_QUORUM_TYPE"
#define CHAIN_VOTING_KEYS_KEY @"CHAIN_VOTING_KEYS_KEY"

@interface DSChain ()

@property (nonatomic, copy) NSString *uniqueID;
@property (nonatomic, copy) NSString *networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> *mWallets;
@property (nonatomic, strong) DSAccount *viewingAccount;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashHeights;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *transactionHashTimestamps;
@property (nonatomic, strong) NSManagedObjectContext *chainManagedObjectContext;
@property (nonatomic, assign, getter=isTransient) BOOL transient;
@property (nonatomic, readonly) NSString *chainWalletsKey;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.mWallets = [NSMutableArray array];
    self.transactionHashHeights = [NSMutableDictionary dictionary];
    self.transactionHashTimestamps = [NSMutableDictionary dictionary];
    
//    if ([self.blocksCache checkpointsCache].checkpoints) {
//        self.blocksCache.genesisHash = self.checkpoints[0].blockHash;
//        dispatch_sync(self.networkingQueue, ^{
//            self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
//        });
//    }
//
//    if (self.checkpoints) {
//        self.genesisHash = self.checkpoints[0].blockHash;
//        dispatch_sync(self.networkingQueue, ^{
//            self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
//        });
//    }
    return self;
}

- (instancetype)initWithType:(ChainType)type checkpoints:(NSArray *)checkpoints {
    if (!(self = [self init])) return nil;
    NSAssert(!chain_type_is_devnet_any(type), @"DevNet should be configured with initAsDevnetWithIdentifier:version:checkpoints:port:dapiPort:dapiGRPCPort:dpnsContractID:dashpayContractID:");
    _chainType = type;
    self.params = [[DSChainParams alloc] initWithChainType:type];
    self.blocksCache = [[DSBlocksCache alloc] initWithFirstCheckpoint:checkpoints onChain:self];
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
    self.params = [[DSChainParams alloc] initWithChainType:_chainType];
    self.blocksCache = [[DSBlocksCache alloc] initWithDevnet:devnetType checkpoints:checkpoints onProtocolVersion:protocolVersion forChain:self];
    dispatch_sync(self.networkingQueue, ^{
        self.chainManagedObjectContext = [NSManagedObjectContext chainContext];
    });
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
            [_mainnet.blocksCache setLastPersistedSyncBlockHeight:chainEntity.syncBlockHeight
                                                        blockHash:chainEntity.syncBlockHash.UInt256
                                                        timestamp:chainEntity.syncBlockTimestamp
                                                        chainWork:chainEntity.syncBlockChainWork.UInt256
                                                         locators:chainEntity.syncLocators];
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
            [_testnet.blocksCache setLastPersistedSyncBlockHeight:chainEntity.syncBlockHeight
                                                        blockHash:chainEntity.syncBlockHash.UInt256
                                                        timestamp:chainEntity.syncBlockTimestamp
                                                        chainWork:chainEntity.syncBlockChainWork.UInt256 
                                                         locators:chainEntity.syncLocators];
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
        [self.blocksCache setLastPersistedSyncBlockHeight:chainEntity.syncBlockHeight
                                                blockHash:chainEntity.syncBlockHash.UInt256
                                                timestamp:chainEntity.syncBlockTimestamp
                                                chainWork:chainEntity.syncBlockChainWork.UInt256
                                                 locators:chainEntity.syncLocators];
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

- (BOOL)isCore20Active {
    return self.lastTerminalBlockHeight >= chain_core20_activation_height(self.chainType);
}

- (KeyKind)activeBLSType {
    return [self isCore19Active] ? KeyKind_BLSBasic : KeyKind_BLS;
}

- (NSDictionary<NSValue *, DSBlock *> *)orphans {
    return [self.blocksCache orphans];
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
    return self == obj || ([obj isKindOfClass:[DSChain class]] && [obj blocksCache] == _blocksCache);
}

- (NSUInteger)hash {
    return self.blocksCache.genesisHash.u64[0];
}

- (dispatch_queue_t)networkingQueue {
    if (!_networkingQueue) {
        NSAssert([self.blocksCache isGenesisExist], @"genesisHash must be set");
        _networkingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.network.%@", self.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return _networkingQueue;
}

- (dispatch_queue_t)dapiMetadataQueue {
    if (!_dapiMetadataQueue) {
        NSAssert([self.blocksCache isGenesisExist], @"genesisHash must be set");
        _dapiMetadataQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.dapimeta.%@", self.uniqueID] UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return _dapiMetadataQueue;
}


- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    return chain_type_is_devnet_any(self.chainType) && uint256_eq([self.blocksCache genesisHash], genesisHash);
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

- (UInt256)genesisHash {
    return [self.blocksCache genesisHash];
}

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
        return [self.blocksCache.checkpointsCache lastCheckpointTimestamp];
    }
}

- (NSString *)chainTip {
    return [NSData dataWithUInt256:self.lastTerminalBlock.blockHash].shortHexString;
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
    
    
    [self.blocksCache clearOrphans];
    
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
        //it will lazy load later
        [self.blocksCache resetLastSyncBlock];
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

- (void)setBlockHeight:(int32_t)height 
          andTimestamp:(NSTimeInterval)timestamp
  forTransactionHashes:(NSArray<NSValue *> *)transactionHashes {
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

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer *)peer thresholdPeerCount:(uint32_t)thresholdPeerCount {
    DSBlockEstimationResult estimation = [self.blocksCache setEstimatedBlockHeight:estimatedBlockHeight fromPeer:peer thresholdPeerCount:thresholdPeerCount];
    static dispatch_once_t onceToken;
    if (estimation == DSBlockEstimationResult_NewBest) {
        dispatch_once(&onceToken, ^{
            [self.chainManager assignSyncWeights];
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainManagerSyncParametersUpdatedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
        });
    } else if (estimation == DSBlockEstimationResult_None) {
        dispatch_once(&onceToken, ^{
            [self.chainManager assignSyncWeights];
        });
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

- (void)markTransactionsUnconfirmedAboveBlockHeight:(uint32_t)blockHeight {
    NSMutableArray *txHashes = [NSMutableArray array];
    // mark transactions after the join point as unconfirmed
    for (DSWallet *wallet in self.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) {
            if (tx.blockHeight <= blockHeight) break;
            [txHashes addObject:uint256_obj(tx.txHash)];
        }
    }
    [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTransactionHashes:txHashes];
}

// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context {
    DSLog(@"[%@] Wiping Blockchain Info", self.name);
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self wipeBlockchainInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    [self.blocksCache wipeBlockchainInfo];
    [self.chainManager chainWasWiped:self];
}

- (void)wipeBlockchainNonTerminalInfoInContext:(NSManagedObjectContext *)context {
    DSLog(@"[%@] Wiping Blockchain Non Terminal Info", self.name);
    for (DSWallet *wallet in self.wallets) {
        [wallet wipeBlockchainInfoInContext:context];
    }
    [self wipeBlockchainIdentitiesPersistedDataInContext:context];
    [self wipeBlockchainInvitationsPersistedDataInContext:context];
    [self.viewingAccount wipeBlockchainInfo];
    [self.chainManager.identitiesManager clearExternalBlockchainIdentities];
    _bestBlockHeight = 0;
    [self.blocksCache wipeBlockchainNonTerminalInfo];
    [self.chainManager chainWasWiped:self];
}

- (void)wipeMasternodesInContext:(NSManagedObjectContext *)context {
    DSLog(@"[%@] Wiping Masternode Info", self.name);
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
    DSLog(@"[%@] Wiping Wallets and Derivatives", self.name);
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
    DSBlock *lastBlock = [self.blocksCache lastSyncBlock];
    UInt256 lastBlockHash = lastBlock.blockHash;
    uint32_t lastBlockHeight = lastBlock.height;
    [self.chainManagedObjectContext performBlockAndWait:^{
        DSChainEntity *chainEntity = [self chainEntityInContext:self.chainManagedObjectContext];
        
        chainEntity.syncBlockHash = uint256_data(lastBlockHash);
        chainEntity.syncBlockHeight = lastBlockHeight;
        chainEntity.syncBlockTimestamp = lastBlock.timestamp;
        chainEntity.syncBlockChainWork = uint256_data(lastBlock.chainWork);
        chainEntity.syncLocators = [self.blocksCache cacheBlockLocators];
        
        NSMutableSet *entities = [NSMutableSet set];
        
        [self persistIncomingTransactionsAttributesForBlockSaveWithNumber:lastBlockHeight inContext:self.chainManagedObjectContext];
        
        for (DSTransactionHashEntity *e in [DSTransactionHashEntity objectsInContext:self.chainManagedObjectContext matching:@"txHash in %@", [self.transactionHashHeights allKeys]]) {
            e.blockHeight = [self.transactionHashHeights[e.txHash] intValue];
            e.timestamp = [self.transactionHashTimestamps[e.txHash] intValue];
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
    NSDictionary *terminalBlocks = [self.blocksCache terminalBlocks];
    while (b && (startHeight > self.blocksCache.checkpointsCache.lastCheckpoint.height) && (endHeight - startHeight < KEEP_RECENT_TERMINAL_BLOCKS)) {
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

- (void)loadFileDistributedMasternodeLists {
    [self.chainManager.masternodeManager loadFileDistributedMasternodeLists];
}

- (BOOL)hasMasternodeListCurrentlyBeingSaved {
    return [self.chainManager.masternodeManager hasMasternodeListCurrentlyBeingSaved];
}


// MARK: - Description

- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}", self.name]];
}

@end
