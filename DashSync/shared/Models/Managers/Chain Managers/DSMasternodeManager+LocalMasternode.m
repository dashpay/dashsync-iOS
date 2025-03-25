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
#import "DSChain+Wallet.h"
#import "DSChainManager+Protected.h"
#import "DSLocalMasternode+Protected.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import <objc/runtime.h>

NSString const *localMasternodesDictionaryKey = @"localMasternodesDictionaryKey";

@implementation DSMasternodeManager (LocalMasternode)

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
    return [self createNewMasternodeWithIPAddress:ipAddress
                                           onPort:port
                                    inFundsWallet:wallet
                                 inOperatorWallet:wallet
                                    inOwnerWallet:wallet
                                   inVotingWallet:wallet
                             inPlatformNodeWallet:wallet];
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *)fundsWallet
                                       inOperatorWallet:(DSWallet *)operatorWallet
                                          inOwnerWallet:(DSWallet *)ownerWallet
                                         inVotingWallet:(DSWallet *)votingWallet
                                   inPlatformNodeWallet:(DSWallet *)platformNodeWallet {
    return [[DSLocalMasternode alloc] initWithIPAddress:ipAddress
                                                                               onPort:port
                                                                        inFundsWallet:fundsWallet
                                                                     inOperatorWallet:operatorWallet
                                                                        inOwnerWallet:ownerWallet
                                                                       inVotingWallet:votingWallet
                                                                 inPlatformNodeWallet:platformNodeWallet];
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
    return [[DSLocalMasternode alloc] initWithIPAddress:ipAddress
                                                 onPort:port
                                          inFundsWallet:fundsWallet
                                       fundsWalletIndex:fundsWalletIndex
                                       inOperatorWallet:operatorWallet
                                    operatorWalletIndex:operatorWalletIndex
                                          inOwnerWallet:ownerWallet
                                       ownerWalletIndex:ownerWalletIndex
                                         inVotingWallet:votingWallet
                                      votingWalletIndex:votingWalletIndex
                                   inPlatformNodeWallet:platformNodeWallet
                                platformNodeWalletIndex:platformNodeWalletIndex];
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress
                                                 onPort:(uint32_t)port
                                          inFundsWallet:(DSWallet *_Nullable)fundsWallet
                                       fundsWalletIndex:(uint32_t)fundsWalletIndex
                                       inOperatorWallet:(DSWallet *_Nullable)operatorWallet
                                    operatorWalletIndex:(uint32_t)operatorWalletIndex
                                      operatorPublicKey:(DOpaqueKey *)operatorPublicKey
                                          inOwnerWallet:(DSWallet *_Nullable)ownerWallet
                                       ownerWalletIndex:(uint32_t)ownerWalletIndex
                                        ownerPrivateKey:(DOpaqueKey *)ownerPrivateKey
                                         inVotingWallet:(DSWallet *_Nullable)votingWallet
                                      votingWalletIndex:(uint32_t)votingWalletIndex
                                              votingKey:(DOpaqueKey *)votingKey
                                   inPlatformNodeWallet:(DSWallet *_Nullable)platformNodeWallet
                                platformNodeWalletIndex:(uint32_t)platformNodeWalletIndex
                                        platformNodeKey:(DOpaqueKey *)platformNodeKey {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress
                                                                               onPort:port
                                                                        inFundsWallet:fundsWallet
                                                                     fundsWalletIndex:fundsWalletIndex
                                                                     inOperatorWallet:operatorWallet
                                                                  operatorWalletIndex:operatorWalletIndex
                                                                        inOwnerWallet:ownerWallet
                                                                     ownerWalletIndex:ownerWalletIndex
                                                                       inVotingWallet:votingWallet
                                                                    votingWalletIndex:votingWalletIndex
                                                                 inPlatformNodeWallet:platformNodeWallet
                                                              platformNodeWalletIndex:platformNodeWalletIndex];

    if (operatorWalletIndex == UINT32_MAX && operatorPublicKey)
        [localMasternode forceOperatorPublicKey:operatorPublicKey];
    if (ownerWalletIndex == UINT32_MAX && ownerPrivateKey)
        [localMasternode forceOwnerPrivateKey:ownerPrivateKey];
    if (votingWalletIndex == UINT32_MAX && votingKey)
        [localMasternode forceVotingKey:votingKey];
    if (platformNodeWalletIndex == UINT32_MAX && platformNodeKey)
        [localMasternode forcePlatformNodeKey:platformNodeKey];
    return localMasternode;
}

- (DSLocalMasternode *)localMasternodeFromSimplifiedMasternodeEntry:(DMasternodeEntry *)simplifiedMasternodeEntry
                                             claimedWithOwnerWallet:(DSWallet *)ownerWallet
                                                      ownerKeyIndex:(uint32_t)ownerKeyIndex
                                                            onChain:(DSChain *)chain {
    NSParameterAssert(simplifiedMasternodeEntry);
    NSParameterAssert(ownerWallet);
    dashcore_sml_masternode_list_entry_MasternodeListEntry *entry = simplifiedMasternodeEntry->masternode_list_entry;
    u256 *pro_reg_tx_hash = dashcore_hash_types_ProTxHash_inner(entry->pro_reg_tx_hash);
    DSLocalMasternode *localMasternode = [self localMasternodeHavingProviderRegistrationTransactionHash:u256_cast(pro_reg_tx_hash)];
    u256_dtor(pro_reg_tx_hash);
    if (localMasternode) return localMasternode;
    u160 *key_id_voting = dashcore_hash_types_PubkeyHash_inner(entry->key_id_voting);
    uint32_t votingIndex;
    DSWallet *votingWallet = [chain walletHavingProviderVotingAuthenticationHash:u160_cast(key_id_voting) foundAtIndex:&votingIndex];
    u160_dtor(key_id_voting);
    UInt384 operatorPublicKey = u384_cast(entry->operator_public_key->_0);
    uint32_t operatorIndex;
    DSWallet *operatorWallet = [chain walletHavingProviderOperatorAuthenticationKey:operatorPublicKey foundAtIndex:&operatorIndex];
    UInt160 platformNodeID = UINT160_ZERO;
    switch (entry->mn_type->tag) {
        case dashcore_sml_masternode_list_entry_EntryMasternodeType_HighPerformance: {
            u160 *platform_node_id = dashcore_hash_types_PubkeyHash_inner(entry->mn_type->high_performance.platform_node_id);
            platformNodeID = u160_cast(platform_node_id);
            u160_dtor(platform_node_id);
            break;
        }
        default:
            break;
    }
    uint32_t platformNodeIndex;
    DSWallet *platformNodeWallet = [chain walletHavingPlatformNodeAuthenticationHash:platformNodeID foundAtIndex:&platformNodeIndex];

    u128 *ip_address = DSocketAddrIp(entry->service_address);
    UInt128 ipAddress = u128_cast(ip_address);
    uint16_t port = DSocketAddrPort(entry->service_address);
    return votingWallet || operatorWallet
        ? [[DSLocalMasternode alloc] initWithIPAddress:ipAddress
                                                onPort:port
                                         inFundsWallet:nil
                                      fundsWalletIndex:0
                                      inOperatorWallet:operatorWallet
                                   operatorWalletIndex:operatorIndex
                                         inOwnerWallet:ownerWallet
                                      ownerWalletIndex:ownerKeyIndex
                                        inVotingWallet:votingWallet
                                     votingWalletIndex:votingIndex
                                  inPlatformNodeWallet:platformNodeWallet
                               platformNodeWalletIndex:platformNodeIndex]
        : nil;
}

- (DSLocalMasternode *)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction
                                                                     save:(BOOL)save {
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
    return self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransactionHash)];
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
    if (derivationPath.reference == DSDerivationPathReference_ProviderFunds || derivationPath.reference == DSDerivationPathReference_ProviderOwnerKeys)
        return nil;

    NSMutableArray *localMasternodes = [NSMutableArray array];

    for (DSLocalMasternode *localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && [localMasternode.previousOperatorWalletIndexes containsIndex:index])
                    [localMasternodes addObject:localMasternode];
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && [localMasternode.previousVotingWalletIndexes containsIndex:index])
                    [localMasternodes addObject:localMasternode];
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
