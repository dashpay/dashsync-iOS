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
@property(nonatomic,strong) NSMutableDictionary * blockchainUsersDerivationPathByWallet;

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
            [derivationPath loadAddresses];
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
            [derivationPath loadAddresses];
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
            [derivationPath loadAddresses];
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
            [derivationPath loadAddresses];
            [self.providerFundsDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (DSAuthenticationKeysDerivationPath*)blockchainUsersKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t blockchainUsersDerivationPathByWalletToken = 0;
    dispatch_once(&blockchainUsersDerivationPathByWalletToken, ^{
        self.blockchainUsersDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainUsersDerivationPathByWallet objectForKey:wallet.uniqueID]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainUsersKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            [derivationPath loadAddresses];
            [self.blockchainUsersDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.blockchainUsersDerivationPathByWallet objectForKey:wallet.uniqueID];
}

- (NSArray<DSDerivationPath*>*)specializedDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet*)wallet {
    NSMutableArray * mArray = [NSMutableArray array];
    
    //Masternode Owner
    DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
    providerOwnerKeysDerivationPath.wallet = wallet;
    if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
        [mArray addObject:providerOwnerKeysDerivationPath];
    }
    
    //Masternode Operator
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
    providerOperatorKeysDerivationPath.wallet = wallet;
    if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
        [mArray addObject:providerOperatorKeysDerivationPath];
    }
    
    //Masternode Voting
    DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
    providerVotingKeysDerivationPath.wallet = wallet;
    if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
        [mArray addObject:providerVotingKeysDerivationPath];
    }
    
    //Masternode Holding
    DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
    providerFundsDerivationPath.wallet = wallet;
    if (!providerFundsDerivationPath.hasExtendedPublicKey) {
        [mArray addObject:providerFundsDerivationPath];
    }
    return [mArray copy];
}

@end
