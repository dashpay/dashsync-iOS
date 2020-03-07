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

#import "DSChainsManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSReachabilityManager.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSString+Dash.h"
#import "DSWallet.h"
#import "DashSync.h"
#include <arpa/inet.h>
#import "DSDashPlatform.h"

#define DEVNET_CHAINS_KEY  @"DEVNET_CHAINS_KEY"
#define SPEND_LIMIT_AMOUNT_KEY  @"SPEND_LIMIT_AMOUNT"

@interface DSChainsManager()

@property (nonatomic,strong) NSMutableArray * knownChains;
@property (nonatomic,strong) NSMutableArray * knownDevnetChains;
@property (nonatomic,strong) NSMutableDictionary * devnetGenesisDictionary;
@property (nonatomic,strong) DSReachabilityManager *reachability;

@end

@implementation DSChainsManager

+ (instancetype)sharedInstance
{
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
        NSError * error = nil;
        NSMutableDictionary * registeredDevnetIdentifiers = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
        self.knownDevnetChains = [NSMutableArray array];
        for (NSString * string in registeredDevnetIdentifiers) {
            NSArray<DSCheckpoint*>* checkpointArray = registeredDevnetIdentifiers[string];
            [self.knownDevnetChains addObject:[DSChain recoverKnownDevnetWithIdentifier:string withCheckpoints:checkpointArray]];
        }
        
        self.reachability = [DSReachabilityManager sharedManager];
    }
    return self;
}

-(DSChainManager*)mainnetManager {
    static id _mainnetManager = nil;
    static dispatch_once_t mainnetToken = 0;
    
    dispatch_once(&mainnetToken, ^{
        DSChain * mainnet = [DSChain mainnet];
        _mainnetManager = [[DSChainManager alloc] initWithChain:mainnet];
        mainnet.chainManager = _mainnetManager;
        
        [self.knownChains addObject:[DSChain mainnet]];
    });
    return _mainnetManager;
}

-(DSChainManager*)testnetManager {
    static id _testnetManager = nil;
    static dispatch_once_t testnetToken = 0;
    
    dispatch_once(&testnetToken, ^{
        DSChain * testnet = [DSChain testnet];
        _testnetManager = [[DSChainManager alloc] initWithChain:testnet];
        testnet.chainManager = _testnetManager;
        [self.knownChains addObject:[DSChain testnet]];
    });
    return _testnetManager;
}


-(DSChainManager*)devnetManagerForChain:(DSChain*)chain {
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        self.devnetGenesisDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(chain.genesisHash);
    DSChainManager * devnetChainManager = nil;
    @synchronized(self) {
        if (![self.devnetGenesisDictionary objectForKey:genesisValue]) {
            devnetChainManager = [[DSChainManager alloc] initWithChain:chain];
            chain.chainManager = devnetChainManager;
            [self.knownChains addObject:chain];
            [self.devnetGenesisDictionary setObject:devnetChainManager forKey:genesisValue];
        } else {
            devnetChainManager = [self.devnetGenesisDictionary objectForKey:genesisValue];
        }
    }
    return devnetChainManager;
}

-(DSChainManager *)chainManagerForChain:(DSChain*)chain {
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

-(NSArray*)devnetChains {
    return [self.knownDevnetChains copy];
}

-(NSArray*)chains {
    return [self.knownChains copy];
}

-(void)updateDevnetChain:(DSChain*)chain forServiceLocations:(NSMutableOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    NSParameterAssert(chain);
    NSParameterAssert(serviceLocations);
    
    DSChainManager * chainManager = [self chainManagerForChain:chain];
    DSPeerManager * peerManager = chainManager.peerManager;
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
        chain.sporkPrivateKey = sporkPrivateKey;
    }
    if (standardPort && standardPort != chain.standardPort) {
        chain.standardPort = standardPort;
    }
    if (dapiJRPCPort && dapiJRPCPort != chain.standardDapiJRPCPort) {
        chain.standardDapiJRPCPort = dapiJRPCPort;
    }
    if (dapiGRPCPort && dapiGRPCPort != chain.standardDapiGRPCPort) {
        chain.standardDapiGRPCPort = dapiGRPCPort;
    }
    if (!uint256_eq(dpnsContractID, chain.dpnsContractID)) {
        chain.dpnsContractID = dpnsContractID;
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:chain].dpnsContract;
        DSBlockchainIdentity * blockchainIdentity = [chain blockchainIdentityForUniqueId:dpnsContractID];
        [contract registerCreator:blockchainIdentity];
    }
    if (!uint256_eq(dashpayContractID, chain.dashpayContractID)) {
        chain.dashpayContractID = dashpayContractID;
        DPContract * contract = [DSDashPlatform sharedInstanceForChain:chain].dashPayContract;
        DSBlockchainIdentity * blockchainIdentity = [chain blockchainIdentityForUniqueId:dashpayContractID];
        [contract registerCreator:blockchainIdentity];
    }
    for (NSString * serviceLocation in serviceLocations) {
        NSArray * serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString * address = serviceArray[0];
        NSString * port = ([serviceArray count] > 1)? serviceArray[1]:nil;
        UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSDLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSDLog(@"we do not yet support IPV6");
        } else {
            DSDLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort];
    }
}

-(DSChain*)registerDevnetChainWithIdentifier:(NSString*)identifier forServiceLocations:(NSOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    NSParameterAssert(identifier);
    NSParameterAssert(serviceLocations);
    
    NSError * error = nil;
    
    DSChain * chain = [DSChain setUpDevnetWithIdentifier:identifier withCheckpoints:nil withDefaultPort:standardPort withDefaultDapiJRPCPort:dapiJRPCPort withDefaultDapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID];
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
        chain.sporkPrivateKey = sporkPrivateKey;
    }
    DSChainManager * chainManager = [self chainManagerForChain:chain];
    DSPeerManager * peerManager = chainManager.peerManager;
    for (NSString * serviceLocation in serviceLocations) {
        NSArray * serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString * address = serviceArray[0];
        NSString * port = ([serviceArray count] > 1)? serviceArray[1]:nil;
        UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSDLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSDLog(@"we do not yet support IPV6");
        } else {
            DSDLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort];
    }
    
    NSMutableDictionary * registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
    
    if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
    if (![[registeredDevnetsDictionary allKeys] containsObject:identifier]) {
        [registeredDevnetsDictionary setObject:chain.checkpoints forKey:identifier];
        setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
    });
    return chain;
}

-(void)removeDevnetChain:(DSChain *)chain {
    NSParameterAssert(chain);
    
    [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"Remove Devnet?" usingBiometricAuthentication:FALSE alertIfLockout:NO completion:^(BOOL authenticatedOrSuccess, BOOL cancelled) {
        if (!cancelled && authenticatedOrSuccess) {
            NSError * error = nil;
            DSChainManager * chainManager = [self chainManagerForChain:chain];
            DSPeerManager * peerManager = chainManager.peerManager;
            [peerManager clearRegisteredPeers];
            NSMutableDictionary * registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
            
            if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
            if ([[registeredDevnetsDictionary allKeys] containsObject:chain.devnetIdentifier]) {
                [registeredDevnetsDictionary removeObjectForKey:chain.devnetIdentifier];
                setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
            }
            [chain wipeWalletsAndDerivatives];
            [[DashSync sharedSyncController] wipePeerDataForChain:chain];
            [[DashSync sharedSyncController] wipeBlockchainDataForChain:chain];
            [[DashSync sharedSyncController] wipeSporkDataForChain:chain];
            [[DashSync sharedSyncController] wipeMasternodeDataForChain:chain];
            [[DashSync sharedSyncController] wipeGovernanceDataForChain:chain];
            [[DashSync sharedSyncController] wipeWalletDataForChain:chain forceReauthentication:NO]; //this takes care of blockchain info as well;
            [self.knownDevnetChains removeObject:chain];
            [self.knownChains removeObject:chain];
            NSValue * genesisValue = uint256_obj(chain.genesisHash);
            [self.devnetGenesisDictionary removeObjectForKey:genesisValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
            });
        }
    }];
    
}

-(BOOL)hasAWallet {
    for (DSChain * chain in self.knownChains) {
        if (chain.hasAWallet) return TRUE;
    }
    return FALSE;
}

-(NSArray*)allWallets {
    NSMutableArray * mAllWallets = [NSMutableArray array];
    for (DSChain * chain in self.knownChains) {
        if (chain.wallets) [mAllWallets addObjectsFromArray:chain.wallets];
    }
    return [mAllWallets copy];
}

// MARK: - Spending Limits

// amount that can be spent using touch id without pin entry
- (uint64_t)spendingLimit
{
    // it's ok to store this in userdefaults because increasing the value only takes effect after successful pin entry
    if (! [[NSUserDefaults standardUserDefaults] objectForKey:SPEND_LIMIT_AMOUNT_KEY]) return DUFFS;
    
    return [[NSUserDefaults standardUserDefaults] doubleForKey:SPEND_LIMIT_AMOUNT_KEY];
}

- (BOOL)setSpendingLimitIfAuthenticated:(uint64_t)spendingLimit
{
    if (![[DSAuthenticationManager sharedInstance] didAuthenticate]) return FALSE;
    uint64_t totalSent = 0;
    for (DSChain * chain in self.chains) {
        for (DSWallet * wallet in chain.wallets) {
            totalSent += wallet.totalSent;
        }
    }
    if (setKeychainInt((spendingLimit > 0) ? totalSent + spendingLimit : 0, SPEND_LIMIT_KEY, NO)) {
        // use setDouble since setInteger won't hold a uint64_t
        [[NSUserDefaults standardUserDefaults] setDouble:spendingLimit forKey:SPEND_LIMIT_AMOUNT_KEY];
        return TRUE;
    }
    return FALSE;
}

-(BOOL)resetSpendingLimitsIfAuthenticated {
    if (![[DSAuthenticationManager sharedInstance] didAuthenticate]) return FALSE;
    uint64_t limit = self.spendingLimit;
    uint64_t totalSent = 0;
    for (DSChain * chain in self.chains) {
        for (DSWallet * wallet in chain.wallets) {
            totalSent += wallet.totalSent;
        }
    }
    if (limit > 0) setKeychainInt(totalSent + limit, SPEND_LIMIT_KEY, NO);
    return TRUE;
}


@end
