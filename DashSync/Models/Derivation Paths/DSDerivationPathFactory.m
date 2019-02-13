//
//  DSDerivationPathFactory.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"

@interface DSDerivationPathFactory()

@property(nonatomic,strong) NSMutableDictionary * votingKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * ownerKeysDerivationPathByWallet;
@property(nonatomic,strong) NSMutableDictionary * operatorKeysDerivationPathByWallet;

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
            NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
            NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 1 | BIP32_HARD};
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:wallet.chain];
            derivationPath.wallet = wallet;
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
            NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
            NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 2 | BIP32_HARD};
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:wallet.chain];
            derivationPath.wallet = wallet;
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
            NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
            NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 3 | BIP32_HARD};
            DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:wallet.chain];
            derivationPath.wallet = wallet;
            [self.operatorKeysDerivationPathByWallet setObject:derivationPath forKey:wallet.uniqueID];
        }
    }
    return [self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueID];
}


@end
