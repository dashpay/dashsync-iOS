//
//  DSChainManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/6/18.
//

#import "DSChainManager.h"

@interface DSChainManager()

@property (nonatomic,strong) NSMutableArray * knownChains;

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

-(id)init {
    if ([super init] == self) {
        self.knownChains = [NSMutableArray array];
    }
    return self;
}

-(DSChainPeerManager*)mainnetManager {
    static id _mainnetManager = nil;
    static dispatch_once_t mainnetToken = 0;
    
    dispatch_once(&mainnetToken, ^{
        _mainnetManager = [[DSChainPeerManager alloc] initWithChain:[DSChain mainnet]];
        [DSChain mainnet].peerManagerDelegate = _mainnetManager;
        [self.knownChains addObject:[DSChain mainnet]];
    });
    return _mainnetManager;
}

-(DSChainPeerManager*)testnetManager {
    static id _testnetManager = nil;
    static dispatch_once_t testnetToken = 0;
    
    dispatch_once(&testnetToken, ^{
        _testnetManager = [[DSChainPeerManager alloc] initWithChain:[DSChain testnet]];
        [DSChain mainnet].peerManagerDelegate = _testnetManager;
        [self.knownChains addObject:[DSChain testnet]];
    });
    return _testnetManager;
}

-(DSChainPeerManager*)devnetManagerForChain:(DSChain*)chain {
    static NSMutableDictionary * _devnetDictionary = nil;
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(chain.genesisHash);
    DSChainPeerManager * devnetChainPeerManager = nil;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:genesisValue]) {
            devnetChainPeerManager = [[DSChainPeerManager alloc] initWithChain:chain];
            chain.peerManagerDelegate = devnetChainPeerManager;
            [self.knownChains addObject:chain];
            [_devnetDictionary setObject:devnetChainPeerManager forKey:genesisValue];
        } else {
            devnetChainPeerManager = [_devnetDictionary objectForKey:genesisValue];
        }
    }
    return devnetChainPeerManager;
}

-(DSChainPeerManager*)peerManagerForChain:(DSChain*)chain {
    if ([chain isMainnet]) {
        return [self mainnetManager];
    } else if ([chain isTestnet]) {
        return [self testnetManager];
    } else if ([chain isDevnetAny]) {
        return [self devnetManagerForChain:chain];
    }
    return nil;
}

-(NSArray*)chains {
    return [self.knownChains copy];
}

-(void)removeAllWalletsFromChains {
    for (DSChain * chain in self.chains) {
        chain.wallet = nil;
    }
}

@end
