//
//  DSDerivationPathFactory.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"

@interface DSDerivationPathFactory()

@property(nonatomic,strong) NSMutableDictionary * votingKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * ownerKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * operatorKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * providerFundsDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * blockchainIdentitiesDerivationPathByWallet;

@end

@implementation DSDerivationPathFactory

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (DSAuthenticationKeysDerivationPath*)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t votingKeysDerivationPathByWalletToken = 0;
    dispatch_once(&votingKeysDerivationPathByWalletToken, ^{
        self.votingKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.votingKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (DSAuthenticationKeysDerivationPath*)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerOwnerKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOwnerKeysDerivationPathByWalletToken, ^{
        self.ownerKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.ownerKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (DSAuthenticationKeysDerivationPath*)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerOperatorKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOperatorKeysDerivationPathByWalletToken, ^{
        self.operatorKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.operatorKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (DSMasternodeHoldingsDerivationPath*)providerFundsDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerFundsDerivationPathByWalletToken = 0;
    dispatch_once(&providerFundsDerivationPathByWalletToken, ^{
        self.providerFundsDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSMasternodeHoldingsDerivationPath * derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.providerFundsDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (DSAuthenticationKeysDerivationPath*)blockchainIdentitiesKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t blockchainIdentitiesDerivationPathByWalletToken = 0;
    dispatch_once(&blockchainIdentitiesDerivationPathByWalletToken, ^{
        self.blockchainIdentitiesDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainIdentitiesDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.blockchainIdentitiesDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.blockchainIdentitiesDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (NSArray<DSDerivationPath*>*)loadedSpecializedDerivationPathsForWallet:(DSWallet*)wallet {
    NSMutableArray * mArray = [NSMutableArray array];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet]];
    if (wallet.chain.isDevnetAny) {
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] blockchainIdentitiesKeysDerivationPathForWallet:wallet]];
    }
    return mArray;
}

- (NSArray<DSDerivationPath*>*)unloadedSpecializedDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet*)wallet {
    NSMutableArray * mArray = [NSMutableArray array];
    
    for (DSDerivationPath * derivationPath in [self unloadedSpecializedDerivationPathsForWallet:wallet]) {
        if (![derivationPath hasExtendedPublicKey]) {
            [mArray addObject:derivationPath];
        }
    }
    return [mArray copy];
}

- (NSArray<DSDerivationPath*>*)unloadedSpecializedDerivationPathsForWallet:(DSWallet*)wallet {
    NSMutableArray * mArray = [NSMutableArray array];
    //Masternode Owner
    DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
    providerOwnerKeysDerivationPath.wallet = wallet;
    [mArray addObject:providerOwnerKeysDerivationPath];
    
    
    //Masternode Operator
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:wallet.chain];
    providerOperatorKeysDerivationPath.wallet = wallet;
    
    [mArray addObject:providerOperatorKeysDerivationPath];
    
    
    //Masternode Voting
    DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
    providerVotingKeysDerivationPath.wallet = wallet;
    
    [mArray addObject:providerVotingKeysDerivationPath];
    
    
    //Masternode Holding
    DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
    providerFundsDerivationPath.wallet = wallet;
    
    [mArray addObject:providerFundsDerivationPath];
    
    
    if (wallet.chain.isDevnetAny) {
        //Blockchain Identities
        DSAuthenticationKeysDerivationPath * blockchainIdentitiesDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesKeysDerivationPathForChain:wallet.chain];
        blockchainIdentitiesDerivationPath.wallet = wallet;
        
        [mArray addObject:blockchainIdentitiesDerivationPath];
        
    }
    
    return [mArray copy];
}

@end
