//
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSChain+Protected.h"
#import "DSChain.h"
#import "DSChainManager+Protected.h"
#import "DSLocalMasternode+Protected.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSSimplifiedMasternodeEntry.h"
#import <objc/runtime.h>

NSString const *localMasternodesDictionaryKey = @"localMasternodesDictionaryKey";

@interface DSMasternodeManager (LocalMasternode)
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSLocalMasternode *> *localMasternodesDictionaryByRegistrationTransactionHash;
@end

@implementation DSMasternodeManager (LocalMasternode)

@dynamic localMasternodesDictionaryByRegistrationTransactionHash;

- (void)setLocalMasternodesDictionaryByRegistrationTransactionHash:(NSMutableDictionary<NSData *, DSLocalMasternode *> *)dictionary {
    objc_setAssociatedObject(self, &localMasternodesDictionaryKey, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSData *, DSLocalMasternode *> *)localMasternodesDictionaryByRegistrationTransactionHash {
    NSMutableDictionary<NSData *, DSLocalMasternode *> *dictionary = objc_getAssociatedObject(self, &localMasternodesDictionaryKey);
    if (!dictionary) {
        self.localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    }
    return objc_getAssociatedObject(self, &localMasternodesDictionaryKey);
}

// MARK: - Local Masternodes

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    return [self createNewMasternodeWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet inVotingWallet:wallet inPlatformNodeWallet:wallet];
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *)fundsWallet
                                       inOperatorWallet:(DSWallet *)operatorWallet
                                          inOwnerWallet:(DSWallet *)ownerWallet
                                         inVotingWallet:(DSWallet *)votingWallet
                                   inPlatformNodeWallet:(DSWallet *)platformNodeWallet {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet inOperatorWallet:operatorWallet inOwnerWallet:ownerWallet inVotingWallet:votingWallet inPlatformNodeWallet:platformNodeWallet];
    return localMasternode;
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       fundsWalletIndex:(uint32_t)fundsWalletIndex
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                    operatorWalletIndex:(uint32_t)operatorWalletIndex
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                       ownerWalletIndex:(uint32_t)ownerWalletIndex
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                      votingWalletIndex:(uint32_t)votingWalletIndex
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet
                                platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet fundsWalletIndex:fundsWalletIndex inOperatorWallet:operatorWallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerWalletIndex inVotingWallet:votingWallet votingWalletIndex:votingWalletIndex inPlatformNodeWallet:platformNodeWallet platformNodeWalletIndex:platformNodeWalletIndex];
    return localMasternode;
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       fundsWalletIndex:(uint32_t)fundsWalletIndex
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                    operatorWalletIndex:(uint32_t)operatorWalletIndex
                                      operatorPublicKey:(OpaqueKey *)operatorPublicKey
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                       ownerWalletIndex:(uint32_t)ownerWalletIndex
                                        ownerPrivateKey:(OpaqueKey *)ownerPrivateKey
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                      votingWalletIndex:(uint32_t)votingWalletIndex
                                              votingKey:(OpaqueKey *)votingKey
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet
                                platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex
                                        platformNodeKey:(OpaqueKey *)platformNodeKey {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet fundsWalletIndex:fundsWalletIndex inOperatorWallet:operatorWallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerWalletIndex inVotingWallet:votingWallet votingWalletIndex:votingWalletIndex inPlatformNodeWallet:platformNodeWallet platformNodeWalletIndex:platformNodeWalletIndex];

    if (operatorWalletIndex == UINT32_MAX && operatorPublicKey) {
        [localMasternode forceOperatorPublicKey:operatorPublicKey];
    }

    if (ownerWalletIndex == UINT32_MAX && ownerPrivateKey) {
        [localMasternode forceOwnerPrivateKey:ownerPrivateKey];
    }

    if (votingWalletIndex == UINT32_MAX && votingKey) {
        [localMasternode forceVotingKey:votingKey];
    }
    
    if (platformNodeWalletIndex == UINT32_MAX && platformNodeKey) {
        [localMasternode forcePlatformNodeKey:platformNodeKey];
    }

    return localMasternode;
}

- (DSLocalMasternode *)localMasternodeFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry claimedWithOwnerWallet:(DSWallet *)ownerWallet ownerKeyIndex:(uint32_t)ownerKeyIndex {
    NSParameterAssert(simplifiedMasternodeEntry);
    NSParameterAssert(ownerWallet);

    DSLocalMasternode *localMasternode = [self localMasternodeHavingProviderRegistrationTransactionHash:simplifiedMasternodeEntry.providerRegistrationTransactionHash];

    if (localMasternode) return localMasternode;

    uint32_t votingIndex;
    DSWallet *votingWallet = [simplifiedMasternodeEntry.chain walletHavingProviderVotingAuthenticationHash:simplifiedMasternodeEntry.keyIDVoting foundAtIndex:&votingIndex];

    uint32_t operatorIndex;
    DSWallet *operatorWallet = [simplifiedMasternodeEntry.chain walletHavingProviderOperatorAuthenticationKey:simplifiedMasternodeEntry.operatorPublicKey foundAtIndex:&operatorIndex];
    
    uint32_t platformNodeIndex;
    DSWallet *platformNodeWallet = [simplifiedMasternodeEntry.chain walletHavingPlatformNodeAuthenticationHash:simplifiedMasternodeEntry.platformNodeID foundAtIndex:&platformNodeIndex];

    if (votingWallet || operatorWallet) {
        return [[DSLocalMasternode alloc] initWithIPAddress:simplifiedMasternodeEntry.address onPort:simplifiedMasternodeEntry.port inFundsWallet:nil fundsWalletIndex:0 inOperatorWallet:operatorWallet operatorWalletIndex:operatorIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerKeyIndex inVotingWallet:votingWallet votingWalletIndex:votingIndex inPlatformNodeWallet:platformNodeWallet platformNodeWalletIndex:platformNodeIndex];
    } else {
        return nil;
    }
}

- (DSLocalMasternode *)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction save:(BOOL)save {
    NSParameterAssert(providerRegistrationTransaction);

    //First check to see if we have a local masternode for this provider registration hash

    @synchronized(self) {
        DSLocalMasternode *localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransaction.txHash)];

        if (localMasternode) {
            //We do
            //todo Update keys
            return localMasternode;
        }
        //We don't
        localMasternode = [[DSLocalMasternode alloc] initWithProviderTransactionRegistration:providerRegistrationTransaction];
        if (localMasternode.noLocalWallet) return nil;
        [self.localMasternodesDictionaryByRegistrationTransactionHash setObject:localMasternode forKey:uint256_data(providerRegistrationTransaction.txHash)];
        if (save) {
            [localMasternode save];
        }
        return localMasternode;
    }
}

- (DSLocalMasternode *)localMasternodeHavingProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    DSLocalMasternode *localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransactionHash)];
    return localMasternode;
}

- (DSLocalMasternode *)localMasternodeUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath {
    NSParameterAssert(derivationPath);
    for (DSLocalMasternode *localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderFunds:
                if (localMasternode.holdingKeysWallet == derivationPath.wallet && localMasternode.holdingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOwnerKeys:
                if (localMasternode.ownerKeysWallet == derivationPath.wallet && localMasternode.ownerWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && localMasternode.operatorWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && localMasternode.votingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            default:
                break;
        }
    }
    return nil;
}

- (NSArray<DSLocalMasternode *> *)localMasternodesPreviouslyUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath {
    NSParameterAssert(derivationPath);
    if (derivationPath.reference == DSDerivationPathReference_ProviderFunds || derivationPath.reference == DSDerivationPathReference_ProviderOwnerKeys) {
        return nil;
    }

    NSMutableArray *localMasternodes = [NSMutableArray array];

    for (DSLocalMasternode *localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && [localMasternode.previousOperatorWalletIndexes containsIndex:index]) {
                    [localMasternodes addObject:localMasternode];
                }
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && [localMasternode.previousVotingWalletIndexes containsIndex:index]) {
                    [localMasternodes addObject:localMasternode];
                }
                break;
            default:
                break;
        }
    }
    return [localMasternodes copy];
}

- (NSUInteger)localMasternodesCount {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash count];
}

- (NSArray<DSLocalMasternode *> *)localMasternodes {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash allValues];
}

- (void)wipeLocalMasternodeInfo {
    [self.localMasternodesDictionaryByRegistrationTransactionHash removeAllObjects];
}

@end
