//
//  DSDerivationPathFactory.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSCreditFundingDerivationPath+Protected.h"

@interface DSDerivationPathFactory()

@property(nonatomic,strong) NSMutableDictionary * votingKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * ownerKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * operatorKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * providerFundsDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * blockchainIdentityRegistrationFundingDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * blockchainIdentityTopupFundingDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * blockchainIdentityBLSDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * blockchainIdentityECDSADerivationPathByWallet;

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
        if (![self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.votingKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath*)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerOwnerKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOwnerKeysDerivationPathByWalletToken, ^{
        self.ownerKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.ownerKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath*)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerOperatorKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOperatorKeysDerivationPathByWalletToken, ^{
        self.operatorKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.operatorKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSMasternodeHoldingsDerivationPath*)providerFundsDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t providerFundsDerivationPathByWalletToken = 0;
    dispatch_once(&providerFundsDerivationPathByWalletToken, ^{
        self.providerFundsDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSMasternodeHoldingsDerivationPath * derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.providerFundsDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

// MARK: - Blockchain Identity Funding

- (DSCreditFundingDerivationPath*)blockchainIdentityRegistrationFundingDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t blockchainIdentityRegistrationFundingDerivationPathByWalletToken = 0;
    dispatch_once(&blockchainIdentityRegistrationFundingDerivationPathByWalletToken, ^{
        self.blockchainIdentityRegistrationFundingDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainIdentityRegistrationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSCreditFundingDerivationPath * derivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.blockchainIdentityRegistrationFundingDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.blockchainIdentityRegistrationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSCreditFundingDerivationPath*)blockchainIdentityTopupFundingDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t blockchainIdentityTopupFundingDerivationPathByWalletToken = 0;
    dispatch_once(&blockchainIdentityTopupFundingDerivationPathByWalletToken, ^{
        self.blockchainIdentityTopupFundingDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainIdentityTopupFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSCreditFundingDerivationPath * derivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.blockchainIdentityTopupFundingDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.blockchainIdentityTopupFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

// MARK: - Blockchain Identity Authentication

- (DSAuthenticationKeysDerivationPath*)blockchainIdentityBLSKeysDerivationPathForWallet:(DSWallet*)wallet {
    static dispatch_once_t blockchainIdentityBLSDerivationPathByWalletToken = 0;
    dispatch_once(&blockchainIdentityBLSDerivationPathByWalletToken, ^{
        self.blockchainIdentityBLSDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainIdentityBLSDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityBLSKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPrivateKey || (derivationPath.hasExtendedPublicKey && !derivationPath.usesHardenedKeys)) {
                [derivationPath loadAddresses];
            }
            [self.blockchainIdentityBLSDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.blockchainIdentityBLSDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath*)blockchainIdentityECDSAKeysDerivationPathForWallet:(DSWallet*)wallet {
    NSParameterAssert(wallet);
    static dispatch_once_t blockchainIdentityECDSADerivationPathByWalletToken = 0;
    dispatch_once(&blockchainIdentityECDSADerivationPathByWalletToken, ^{
        self.blockchainIdentityECDSADerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.blockchainIdentityECDSADerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityECDSAKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPrivateKey || (derivationPath.hasExtendedPublicKey && !derivationPath.usesHardenedKeys)) {
                [derivationPath loadAddresses];
            }
            [self.blockchainIdentityECDSADerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueIDString];
        }
    }
    return [self.blockchainIdentityECDSADerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (NSArray<DSDerivationPath*>*)loadedSpecializedDerivationPathsForWallet:(DSWallet*)wallet {
    NSMutableArray * mArray = [NSMutableArray array];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet]];
    if (wallet.chain.isEvolutionEnabled) {
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] blockchainIdentityRegistrationFundingDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] blockchainIdentityTopupFundingDerivationPathForWallet:wallet]];
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
        DSAuthenticationKeysDerivationPath * blockchainIdentitiesECDSADerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityECDSAKeysDerivationPathForChain:wallet.chain];
        blockchainIdentitiesECDSADerivationPath.wallet = wallet;
        
        [mArray addObject:blockchainIdentitiesECDSADerivationPath];
        
        DSAuthenticationKeysDerivationPath * blockchainIdentitiesBLSDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityBLSKeysDerivationPathForChain:wallet.chain];
        blockchainIdentitiesBLSDerivationPath.wallet = wallet;
        
        [mArray addObject:blockchainIdentitiesBLSDerivationPath];
        
        DSCreditFundingDerivationPath * blockchainIdentitiesRegistrationDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForChain:wallet.chain];
        blockchainIdentitiesRegistrationDerivationPath.wallet = wallet;
        
        [mArray addObject:blockchainIdentitiesRegistrationDerivationPath];
        
        DSCreditFundingDerivationPath * blockchainIdentitiesTopupDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForChain:wallet.chain];
        blockchainIdentitiesTopupDerivationPath.wallet = wallet;
        
        [mArray addObject:blockchainIdentitiesTopupDerivationPath];
        
    }
    
    return [mArray copy];
}

@end
