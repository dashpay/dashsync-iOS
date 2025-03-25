//
//  DSChainManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/6/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DPContract+Protected.h"
#import "DSChainsManager.h"
#import "DSChain+Checkpoint.h"
#import "DSChain+Identity.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Wallet.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager+Protected.h"
#import "DSDashPlatform.h"
#import "DSPeerManager+Protected.h"
#import "DSReachabilityManager.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"
#include <arpa/inet.h>

#define DEVNET_CHAINS_KEY @"DEVNET_CHAINS_KEY"

@interface DSChainsManager ()

@property (nonatomic, strong) NSMutableArray *knownChains;
@property (nonatomic, strong) NSMutableArray *knownDevnetChains;
@property (nonatomic, strong) NSMutableDictionary *devnetGenesisDictionary;
@property (nonatomic, strong) DSReachabilityManager *reachability;

@end

@implementation DSChainsManager

+ (instancetype)sharedInstance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });

    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.knownChains = [NSMutableArray array];
        self.knownDevnetChains = [NSMutableArray array];
        self.reachability = [DSReachabilityManager sharedManager];
        register_rust_logger();
    }
    return self;
}

- (DSChainManager *)mainnetManager {
    static id _mainnetManager = nil;
    static dispatch_once_t mainnetToken = 0;

    dispatch_once(&mainnetToken, ^{
        DSChain *mainnet = [DSChain mainnet];
        _mainnetManager = [[DSChainManager alloc] initWithChain:mainnet];
        mainnet.chainManager = _mainnetManager;

        [self.knownChains addObject:[DSChain mainnet]];
    });
    return _mainnetManager;
}

- (DSChainManager *)testnetManager {
    static id _testnetManager = nil;
    static dispatch_once_t testnetToken = 0;

    dispatch_once(&testnetToken, ^{
        DSChain *testnet = [DSChain testnet];
        _testnetManager = [[DSChainManager alloc] initWithChain:testnet];
        testnet.chainManager = _testnetManager;
        [self.knownChains addObject:[DSChain testnet]];
    });
    return _testnetManager;
}


- (DSChainManager *)devnetManagerForChain:(DSChain *)chain {
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        self.devnetGenesisDictionary = [NSMutableDictionary dictionary];
    });
    NSValue *genesisValue = uint256_obj(chain.genesisHash);
    DSChainManager *devnetChainManager = nil;
    @synchronized(self) { // TODO avoid initialization of multiple instances for same chain
        if (![self.devnetGenesisDictionary objectForKey:genesisValue]) {
            devnetChainManager = [[DSChainManager alloc] initWithChain:chain];
            chain.chainManager = devnetChainManager;
            [self.knownChains addObject:chain];
            [self.knownDevnetChains addObject:chain];
            [self.devnetGenesisDictionary setObject:devnetChainManager forKey:genesisValue];
        } else {
            devnetChainManager = [self.devnetGenesisDictionary objectForKey:genesisValue];
        }
    }
    return devnetChainManager;
}

- (DSChainManager *)chainManagerForChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if ([chain isMainnet]) {
        return [self mainnetManager];
    } else if ([chain isTestnet]) {
        return [self testnetManager];
    } else if ([chain isDevnetAny]) {
        return [self devnetManagerForChain:chain];
    }
    return nil;
}

- (NSArray *)devnetChains {
    return [self.knownDevnetChains copy];
}

- (NSArray *)chains {
    return [self.knownChains copy];
}

- (void)updateDevnetChain:(DSChain *)chain
      forServiceLocations:(NSMutableOrderedSet<NSString *> *)serviceLocations
  minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
             standardPort:(uint32_t)standardPort
             dapiJRPCPort:(uint32_t)dapiJRPCPort
             dapiGRPCPort:(uint32_t)dapiGRPCPort
           dpnsContractID:(UInt256)dpnsContractID
        dashpayContractID:(UInt256)dashpayContractID
          protocolVersion:(uint32_t)protocolVersion
       minProtocolVersion:(uint32_t)minProtocolVersion
             sporkAddress:(NSString *)sporkAddress
          sporkPrivateKey:(NSString *)sporkPrivateKey {
    NSParameterAssert(chain);
    NSParameterAssert(serviceLocations);
    DSChainManager *chainManager = [self chainManagerForChain:chain];
    DSPeerManager *peerManager = chainManager.peerManager;
    [peerManager clearRegisteredPeers];
    if (protocolVersion) {
        chain.protocolVersion = protocolVersion;
    }
    if (minProtocolVersion) {
        chain.minProtocolVersion = minProtocolVersion;
    }
    if (sporkAddress && [sporkAddress isValidDashDevnetAddress]) {
        chain.sporkAddress = sporkAddress;
    }
    if (sporkPrivateKey && [sporkPrivateKey isValidDashDevnetPrivateKey]) {
        chain.sporkPrivateKeyBase58String = sporkPrivateKey;
    }
    if (standardPort && standardPort != chain.standardPort) {
        chain.standardPort = standardPort;
    }
    if (minimumDifficultyBlocks && minimumDifficultyBlocks != chain.minimumDifficultyBlocks) {
        chain.minimumDifficultyBlocks = minimumDifficultyBlocks;
    }
    if (dapiJRPCPort && dapiJRPCPort != chain.standardDapiJRPCPort) {
        chain.standardDapiJRPCPort = dapiJRPCPort;
    }
    if (dapiGRPCPort && dapiGRPCPort != chain.standardDapiGRPCPort) {
        chain.standardDapiGRPCPort = dapiGRPCPort;
    }
    if (!uint256_eq(dpnsContractID, chain.dpnsContractID)) {
        chain.dpnsContractID = dpnsContractID;
        DPContract *contract = [DSDashPlatform sharedInstanceForChain:chain].dpnsContract;
        if (uint256_is_not_zero(dpnsContractID)) {
            DSIdentity *identity = [chain identityThatCreatedContract:[DPContract localDPNSContractForChain:chain].raw_contract withContractId:dpnsContractID foundInWallet:nil];
            if (identity) {
                [contract registerCreator:identity];
                [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
            }
        } else {
            [contract unregisterCreator];
            [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
        }
    }
    if (!uint256_eq(dashpayContractID, chain.dashpayContractID)) {
        chain.dashpayContractID = dashpayContractID;
        DPContract *contract = [DSDashPlatform sharedInstanceForChain:chain].dashPayContract;
        if (uint256_is_not_zero(dashpayContractID)) {
            DSIdentity *identity = [chain identityThatCreatedContract:[DPContract localDashpayContractForChain:chain].raw_contract withContractId:dashpayContractID foundInWallet:nil];
            if (identity) {
                [contract registerCreator:identity];
                [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];
            }
        } else {
            [contract unregisterCreator];
            [contract saveAndWaitInContext:[NSManagedObjectContext platformContext]];

        }
    }
    for (NSString *serviceLocation in serviceLocations) {
        NSArray *serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString *address = serviceArray[0];
        NSString *port = ([serviceArray count] > 1) ? serviceArray[1] : nil;
        UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSLog(@"we do not yet support IPV6");
        } else {
            DSLog(@"invalid address");
        }

        [peerManager registerPeerAtLocation:ipAddress
                                       port:port ? [port intValue] : standardPort
                               dapiJRPCPort:dapiJRPCPort
                               dapiGRPCPort:dapiGRPCPort];
    }
}

- (DSChain *_Nullable)registerDevnetChainWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
                                    forServiceLocations:(NSOrderedSet<NSString *> *)serviceLocations
                            withMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                                           standardPort:(uint32_t)standardPort
                                           dapiJRPCPort:(uint32_t)dapiJRPCPort
                                           dapiGRPCPort:(uint32_t)dapiGRPCPort
                                         dpnsContractID:(UInt256)dpnsContractID
                                      dashpayContractID:(UInt256)dashpayContractID
                                        protocolVersion:(uint32_t)protocolVersion
                                     minProtocolVersion:(uint32_t)minProtocolVersion
                                           sporkAddress:(NSString *_Nullable)sporkAddress
                                        sporkPrivateKey:(NSString *_Nullable)sporkPrivateKey {
    NSParameterAssert(devnetType);
    NSParameterAssert(serviceLocations);

    NSError *error = nil;

    DSChain *chain = [DSChain setUpDevnetWithIdentifier:devnetType protocolVersion:protocolVersion?protocolVersion:PROTOCOL_VERSION_DEVNET minProtocolVersion:minProtocolVersion?minProtocolVersion:DEFAULT_MIN_PROTOCOL_VERSION_DEVNET withCheckpoints:nil withMinimumDifficultyBlocks:minimumDifficultyBlocks withDefaultPort:standardPort withDefaultDapiJRPCPort:dapiJRPCPort withDefaultDapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID isTransient:NO];
    
    if (sporkAddress && [sporkAddress isValidDashDevnetAddress]) {
        chain.sporkAddress = sporkAddress;
    }
    if (sporkPrivateKey && [sporkPrivateKey isValidDashDevnetPrivateKey]) {
        chain.sporkPrivateKeyBase58String = sporkPrivateKey;
    }
    DSChainManager *chainManager = [self chainManagerForChain:chain];
    DSPeerManager *peerManager = chainManager.peerManager;
    for (NSString *serviceLocation in serviceLocations) {
        NSArray *serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString *address = serviceArray[0];
        NSString *port = ([serviceArray count] > 1) ? serviceArray[1] : nil;
        UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSLog(@"we do not yet support IPV6");
        } else {
            DSLog(@"invalid address");
        }

        [peerManager registerPeerAtLocation:ipAddress
                                       port:port ? [port intValue] : standardPort
                               dapiJRPCPort:dapiJRPCPort
                               dapiGRPCPort:dapiGRPCPort];
    }

    NSMutableDictionary *registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, @[[NSString class], [NSArray class], [DSCheckpoint class]], &error) mutableCopy];

    if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
    char *devnet_id = dash_spv_crypto_network_chain_type_ChainType_devnet_identifier(chain.chainType);
    NSString *devnetIdentifier = [DSKeyManager NSStringFrom:devnet_id];
    if (![[registeredDevnetsDictionary allKeys] containsObject:devnetIdentifier]) {
        [registeredDevnetsDictionary setObject:chain.checkpoints forKey:devnetIdentifier];
        setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
    });
    return chain;
}

- (void)removeDevnetChain:(DSChain *)chain {
    NSParameterAssert(chain);

    [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"Remove Devnet?"
                                        usingBiometricAuthentication:FALSE
                                                      alertIfLockout:NO
                                                          completion:^(BOOL authenticatedOrSuccess, BOOL usedBiometrics, BOOL cancelled) {
        if (!cancelled && authenticatedOrSuccess) {
            NSError *error = nil;
            DSChainManager *chainManager = [self chainManagerForChain:chain];
            DSPeerManager *peerManager = chainManager.peerManager;
            [peerManager clearRegisteredPeers];
            NSMutableDictionary *registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, @[[NSString class], [NSArray class], [DSCheckpoint class]], &error) mutableCopy];

            if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
            NSString *devnetIdentifier = [DSKeyManager devnetIdentifierFor:chain.chainType];
            if ([[registeredDevnetsDictionary allKeys] containsObject:devnetIdentifier]) {
                [registeredDevnetsDictionary removeObjectForKey:devnetIdentifier];
                setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
            }
            [chain wipeWalletsAndDerivatives];
            NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
            [[DashSync sharedSyncController] wipePeerDataForChain:chain inContext:context];
            [[DashSync sharedSyncController] wipeBlockchainDataForChain:chain inContext:context];
            [[DashSync sharedSyncController] wipeSporkDataForChain:chain inContext:context];
            [[DashSync sharedSyncController] wipeMasternodeDataForChain:chain inContext:context];
            [[DashSync sharedSyncController] wipeGovernanceDataForChain:chain inContext:context];
            [[DashSync sharedSyncController] wipeWalletDataForChain:chain forceReauthentication:NO inContext:context]; //this takes care of blockchain info as well;
            [self.knownDevnetChains removeObject:chain];
            [self.knownChains removeObject:chain];
            NSValue *genesisValue = uint256_obj(chain.genesisHash);
            [self.devnetGenesisDictionary removeObjectForKey:genesisValue];
          
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
            });
        }
    }];
}

- (BOOL)hasAWallet {
    for (DSChain *chain in self.knownChains) {
        if (chain.hasAWallet) return TRUE;
    }
    return FALSE;
}

- (NSArray *)allWallets {
    NSMutableArray *mAllWallets = [NSMutableArray array];
    for (DSChain *chain in self.knownChains) {
        if (chain.wallets) [mAllWallets addObjectsFromArray:chain.wallets];
    }
    return [mAllWallets copy];
}

@end
