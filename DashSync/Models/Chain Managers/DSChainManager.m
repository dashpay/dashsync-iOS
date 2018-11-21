//
//  DSChainManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/6/18.
//

#import "DSChainManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "Reachability.h"
#import "DSPriceManager.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSString+Dash.h"
#import "DSWallet.h"
#import "DashSync.h"
#include <arpa/inet.h>

#define DEVNET_CHAINS_KEY  @"DEVNET_CHAINS_KEY"
#define SPEND_LIMIT_AMOUNT_KEY  @"SPEND_LIMIT_AMOUNT"

@interface DSChainManager()

@property (nonatomic,strong) NSMutableArray * knownChains;
@property (nonatomic,strong) NSMutableArray * knownDevnetChains;
@property (nonatomic,strong) NSMutableDictionary * devnetGenesisDictionary;
@property (nonatomic,strong) Reachability *reachability;

@end

@implementation DSChainManager

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
            [self.knownDevnetChains addObject:[DSChain setUpDevnetWithIdentifier:string withCheckpoints:checkpointArray withDefaultPort:DEVNET_STANDARD_PORT withDefaultDapiPort:DEVNET_DAPI_STANDARD_PORT]];
        }
        
        self.reachability = [Reachability reachabilityForInternetConnection];
    }
    return self;
}

-(DSPeerManager*)mainnetManager {
    static id _mainnetManager = nil;
    static dispatch_once_t mainnetToken = 0;
    
    dispatch_once(&mainnetToken, ^{
        DSChain * mainnet = [DSChain mainnet];
        _mainnetManager = [[DSPeerManager alloc] initWithChain:mainnet];
        mainnet.peerManagerDelegate = _mainnetManager;
        
        [self.knownChains addObject:[DSChain mainnet]];
    });
    return _mainnetManager;
}

-(DSPeerManager*)testnetManager {
    static id _testnetManager = nil;
    static dispatch_once_t testnetToken = 0;
    
    dispatch_once(&testnetToken, ^{
        DSChain * testnet = [DSChain testnet];
        _testnetManager = [[DSPeerManager alloc] initWithChain:testnet];
        testnet.peerManagerDelegate = _testnetManager;
        [self.knownChains addObject:[DSChain testnet]];
    });
    return _testnetManager;
}


-(DSPeerManager*)devnetManagerForChain:(DSChain*)chain {
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        self.devnetGenesisDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(chain.genesisHash);
    DSPeerManager * devnetChainPeerManager = nil;
    @synchronized(self) {
        if (![self.devnetGenesisDictionary objectForKey:genesisValue]) {
            devnetChainPeerManager = [[DSPeerManager alloc] initWithChain:chain];
            chain.peerManagerDelegate = devnetChainPeerManager;
            [self.knownChains addObject:chain];
            [self.knownDevnetChains addObject:chain];
            [self.devnetGenesisDictionary setObject:devnetChainPeerManager forKey:genesisValue];
        } else {
            devnetChainPeerManager = [self.devnetGenesisDictionary objectForKey:genesisValue];
        }
    }
    return devnetChainPeerManager;
}

-(DSPeerManager*)peerManagerForChain:(DSChain*)chain {
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

-(void)updateDevnetChain:(DSChain*)chain forServiceLocations:(NSMutableOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    DSPeerManager * peerManager = [self peerManagerForChain:chain];
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
            NSLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            NSLog(@"we do not yet support IPV6");
        } else {
            NSLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiPort:dapiPort];
    }
}

-(DSChain*)registerDevnetChainWithIdentifier:(NSString*)identifier forServiceLocations:(NSMutableOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    NSError * error = nil;
    
    DSChain * chain = [DSChain setUpDevnetWithIdentifier:identifier withCheckpoints:nil withDefaultPort:standardPort withDefaultDapiPort:dapiPort];
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
    DSPeerManager * peerManager = [self peerManagerForChain:chain];
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
            NSLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            NSLog(@"we do not yet support IPV6");
        } else {
            NSLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiPort:dapiPort];
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

-(void)removeDevnetChain:(DSChain* _Nonnull)chain {
    [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"Remove Devnet?" andTouchId:FALSE alertIfLockout:NO completion:^(BOOL authenticatedOrSuccess, BOOL cancelled) {
        if (!cancelled && authenticatedOrSuccess) {
            NSError * error = nil;
            DSPeerManager * chainPeerManager = [self peerManagerForChain:chain];
            [chainPeerManager clearRegisteredPeers];
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

// MARK: - Spending Limits

// amount that can be spent using touch id without pin entry
- (uint64_t)spendingLimit
{
    // it's ok to store this in userdefaults because increasing the value only takes effect after successful pin entry
    if (! [[NSUserDefaults standardUserDefaults] objectForKey:SPEND_LIMIT_AMOUNT_KEY]) return DUFFS;
    
    return [[NSUserDefaults standardUserDefaults] doubleForKey:SPEND_LIMIT_AMOUNT_KEY];
}

- (void)setSpendingLimit:(uint64_t)spendingLimit
{
    uint64_t totalSent = 0;
    for (DSChain * chain in self.chains) {
        for (DSWallet * wallet in chain.wallets) {
            totalSent += wallet.totalSent;
        }
    }
    if (setKeychainInt((spendingLimit > 0) ? totalSent + spendingLimit : 0, SPEND_LIMIT_KEY, NO)) {
        // use setDouble since setInteger won't hold a uint64_t
        [[NSUserDefaults standardUserDefaults] setDouble:spendingLimit forKey:SPEND_LIMIT_AMOUNT_KEY];
    }
}

-(void)resetSpendingLimits {
    
    uint64_t limit = self.spendingLimit;
    uint64_t totalSent = 0;
    for (DSChain * chain in self.chains) {
        for (DSWallet * wallet in chain.wallets) {
            totalSent += wallet.totalSent;
        }
    }
    if (limit > 0) setKeychainInt(totalSent + limit, SPEND_LIMIT_KEY, NO);
    
}


@end
