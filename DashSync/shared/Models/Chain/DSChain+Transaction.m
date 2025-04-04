//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSAccount.h"
#import "DSAssetLockTransaction.h"
#import "DSAssetUnlockTransaction.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSIdentity+Protected.h"
#import "DSInvitation+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Params.h"
#import "DSChain+Wallet.h"
#import "DSChainManager.h"
#import "DSDerivationPathFactory.h"
#import "DSLocalMasternode+Protected.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSWallet.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Invitation.h"
#import "DSWallet+Protected.h"

@implementation DSChain (Transaction)

// MARK: - Transactions

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    return [self transactionForHash:txHash returnWallet:nil];
}

- (DSTransaction *)transactionForHash:(UInt256)txHash returnWallet:(DSWallet **)rWallet {
    for (DSWallet *wallet in self.wallets) {
        DSTransaction *transaction = [wallet transactionForHash:txHash];
        if (transaction) {
            if (rWallet) *rWallet = wallet;
            return transaction;
        }
    }
    return nil;
}

- (NSArray<DSTransaction *> *)allTransactions {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSWallet *wallet in self.wallets) {
        [mArray addObjectsFromArray:wallet.allTransactions];
    }
    return mArray;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t received = 0;
    for (DSWallet *wallet in self.wallets) {
        received += [wallet amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t sent = 0;
    for (DSWallet *wallet in self.wallets) {
        sent += [wallet amountSentByTransaction:transaction];
    }
    return sent;
}

// MARK: - Special Transactions

//Does the chain mat
- (BOOL)transactionHasLocalReferences:(DSTransaction *)transaction {
    if ([self firstAccountThatCanContainTransaction:transaction]) return TRUE;
    
    //PROVIDERS
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *tx = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:tx.ownerKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderVotingAuthenticationHash:tx.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:tx.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self walletHavingPlatformNodeAuthenticationHash:tx.platformNodeID foundAtIndex:nil]) return TRUE;
        if ([self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:tx foundAtIndex:nil]) return TRUE;
        if ([self accountContainingAddress:tx.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *tx = (DSProviderUpdateServiceTransaction *)transaction;
        if ([self transactionForHash:tx.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:tx.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *tx = (DSProviderUpdateRegistrarTransaction *)transaction;
        if ([self walletHavingProviderVotingAuthenticationHash:tx.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:tx.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self transactionForHash:tx.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:tx.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *tx = (DSProviderUpdateRevocationTransaction *)transaction;
        if ([self transactionForHash:tx.providerRegistrationTransactionHash]) return TRUE;
        
        //BLOCKCHAIN USERS
    }
    // TODO: asset locks/unlocks/transitions?

    //    else if ([transaction isKindOfClass:[DSIdentityRegistrationTransition class]]) {
    //        DSIdentityRegistrationTransition * identityRegistrationTransaction = (DSIdentityRegistrationTransition *)transaction;
    //        if ([self walletHavingIdentityAuthenticationHash:identityRegistrationTransaction.pubkeyHash foundAtIndex:nil]) return TRUE;
    //    } else if ([transaction isKindOfClass:[DSIdentityUpdateTransition class]]) {
    //        DSIdentityUpdateTransition * identityResetTransaction = (DSIdentityUpdateTransition *)transaction;
    //        if ([self walletHavingIdentityAuthenticationHash:identityResetTransaction.replacementPublicKeyHash foundAtIndex:nil]) return TRUE;
    //        if ([self transactionForHash:identityResetTransaction.registrationTransactionHash]) return TRUE;
    //    } else if ([transaction isKindOfClass:[DSIdentityCloseTransition class]]) {
    //        DSIdentityCloseTransition * identityCloseTransaction = (DSIdentityCloseTransition *)transaction;
    //        if ([self transactionForHash:identityCloseTransaction.registrationTransactionHash]) return TRUE;
    //    } else if ([transaction isKindOfClass:[DSIdentityTopupTransition class]]) {
    //        DSIdentityTopupTransition * identityTopupTransaction = (DSIdentityTopupTransition *)transaction;
    //        if ([self transactionForHash:identityTopupTransaction.registrationTransactionHash]) return TRUE;
    //    }
    return FALSE;
}

// MARK: - Registering special transactions


- (BOOL)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)transaction
                                saveImmediately:(BOOL)saveImmediately {
    DSWallet *ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:transaction.ownerKeyHash foundAtIndex:nil];
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:transaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:transaction.operatorKey foundAtIndex:nil];
    DSWallet *holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:transaction foundAtIndex:nil];
    DSWallet *platformNodeWallet = [self walletHavingPlatformNodeAuthenticationHash:transaction.platformNodeID foundAtIndex:nil];
    DSAccount *account = [self accountContainingAddress:transaction.payoutAddress];
    BOOL registered = NO;
    registered |= [account registerTransaction:transaction saveImmediately:saveImmediately];
    registered |= [ownerWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    registered |= [votingWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    registered |= [operatorWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    registered |= [holdingWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    registered |= [platformNodeWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    
    if (ownerWallet) {
        DSAuthenticationKeysDerivationPath *ownerDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:ownerWallet];
        [ownerDerivationPath registerTransactionAddress:transaction.ownerAddress];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:transaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:transaction.operatorAddress];
    }
    
    if (holdingWallet) {
        DSMasternodeHoldingsDerivationPath *holdingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:holdingWallet];
        [holdingDerivationPath registerTransactionAddress:transaction.holdingAddress];
    }
    
    if (platformNodeWallet) {
        DSAuthenticationKeysDerivationPath *platformNodeDerivationPath = [[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:platformNodeWallet];
        [platformNodeDerivationPath registerTransactionAddress:transaction.platformNodeAddress];
    }
    
    return registered;
}

- (BOOL)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *wallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:transaction.providerRegistrationTransactionHash returnWallet:&wallet];
    DSAccount *account = [self accountContainingAddress:transaction.payoutAddress];
    BOOL registered = [account registerTransaction:transaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && wallet) {
        registered |= [wallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    }
    return registered;
}


- (BOOL)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:transaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:transaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    [operatorWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:transaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount *account = [self accountContainingAddress:transaction.payoutAddress];
    BOOL registered = [account registerTransaction:transaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet)
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];

    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:transaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:transaction.operatorAddress];
    }
    return registered;
}

- (BOOL)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *wallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:transaction.providerRegistrationTransactionHash returnWallet:&wallet];
    if (providerRegistrationTransaction && wallet) {
        return [wallet.specialTransactionsHolder registerTransaction:transaction saveImmediately:saveImmediately];
    } else {
        return NO;
    }
}
- (BOOL)registerAssetLockTransaction:(DSAssetLockTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    DSAssetLockTransaction *assetLockTransaction = (DSAssetLockTransaction *)transaction;
    UInt160 creditBurnPublicKeyHash = assetLockTransaction.creditBurnPublicKeyHash;
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"[%@] Registered AssetLockTX: creditBurnPublicKeyHash: %@, txHash: %@", self.name, uint160_hex(creditBurnPublicKeyHash), uint256_hex(assetLockTransaction.txHash)];
    BOOL isNewIdentity = FALSE;
    DSIdentity *identity = nil;
    uint32_t index;
    DSWallet *wallet = [self walletHavingIdentityAssetLockRegistrationHash:creditBurnPublicKeyHash foundAtIndex:&index];
    if (!wallet)
        wallet = [self walletHavingIdentityAssetLockTopupHash:creditBurnPublicKeyHash foundAtIndex:&index];
    
    if (wallet) {
        identity = [wallet identityForUniqueId:assetLockTransaction.creditBurnIdentityIdentifier];
        [debugString appendFormat:@" (Found wallet: %@, identity: %@)", wallet.uniqueIDString, identity];
    }
    
    if (!identity) {
        [self triggerUpdatesForLocalReferences:assetLockTransaction];
        if (wallet) {
            identity = [wallet identityForUniqueId:assetLockTransaction.creditBurnIdentityIdentifier];
//                [debugString appendFormat:@" (Found wallet after trigger updates: %@, identity: %@)", wallet.uniqueIDString, identity];
            if (identity) isNewIdentity = TRUE;
        }
    } else if (identity && !identity.registrationAssetLockTransaction) {
//            [debugString appendFormat:@" (identity: %@ is known but has no asset lock tx)", identity];
        identity.registrationAssetLockTransactionHash = assetLockTransaction.txHash;
    } else if (identity && ![identity containsTopupTransaction:transaction]) {
        // TODO: what about topup transactions? how to distinguish them from registration
        // TODO: For now use this solution
        [identity.topupAssetLockTransactionHashes addObject:uint256_data(transaction.txHash)];
    }
    DSLog(@"%@:", debugString);
    if (!saveImmediately && identity && isNewIdentity) {
        NSTimeInterval walletCreationTime = [identity.wallet walletCreationTime];
        if ((walletCreationTime == BIP39_WALLET_UNKNOWN_CREATION_TIME || walletCreationTime == BIP39_CREATION_TIME) && [identity isDefault]) {
            [identity.wallet setGuessedWalletCreationTime:self.lastSyncBlockTimestamp - HOUR_TIME_INTERVAL - (DAY_TIME_INTERVAL / arc4random() % DAY_TIME_INTERVAL)];
        }
        [self.chainManager.identitiesManager checkAssetLockTransactionForPossibleNewIdentity:assetLockTransaction];
    }
    return isNewIdentity;
}

- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        return [self registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)transaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        return [self registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)transaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        return [self registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)transaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        return [self registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)transaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSAssetLockTransaction class]]) {
        return [self registerAssetLockTransaction:(DSAssetLockTransaction *)transaction saveImmediately:saveImmediately];
    }
    return FALSE;
}


- (void)triggerUpdatesForLocalReferences:(DSTransaction *)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil] ||
            [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil] ||
            [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil] ||
            [self walletHavingPlatformNodeAuthenticationHash:providerRegistrationTransaction.platformNodeID foundAtIndex:nil]) {
            [self.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:TRUE];
        }
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *tx = (DSProviderUpdateServiceTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:tx.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateServiceTransaction:tx save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *tx = (DSProviderUpdateRegistrarTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:tx.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRegistrarTransaction:tx save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *tx = (DSProviderUpdateRevocationTransaction *)transaction;
        DSLocalMasternode *localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:tx.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRevocationTransaction:tx save:TRUE];
    } else if ([transaction isKindOfClass:[DSAssetLockTransaction class]]) {
        DSAssetLockTransaction *tx = (DSAssetLockTransaction *)transaction;
        UInt160 creditBurnPublicKeyHash = tx.creditBurnPublicKeyHash;
        uint32_t index;
        DSWallet *wallet = [self walletHavingIdentityAssetLockRegistrationHash:creditBurnPublicKeyHash foundAtIndex:&index];
        UInt256 identityId = tx.creditBurnIdentityIdentifier;
        if (wallet) {
            DSIdentity *identity = [wallet identityForUniqueId:identityId];
            if (!identity) {
                identity = [[DSIdentity alloc] initAtIndex:index withAssetLockTransaction:tx inWallet:wallet];
                [identity registerInWalletForAssetLockTransaction:tx];
            }
        } else {
            wallet = [self walletHavingIdentityAssetLockTopupHash:creditBurnPublicKeyHash foundAtIndex:&index];
            if (wallet) {
                DSIdentity *identity = [wallet identityForUniqueId:identityId];
                if (identity) {
                    [identity registerInWalletForAssetLockTopupTransaction:tx];
                } else {
                    NSAssert(NO, @"Topup unknown identity %@", uint256_hex(identityId));
                }
                
            } else {
                wallet = [self walletHavingIdentityAssetLockInvitationHash:creditBurnPublicKeyHash foundAtIndex:&index];
                if (wallet) {
                    DSInvitation *invitation = [wallet invitationForUniqueId:identityId];
                    if (!invitation) {
                        invitation = [[DSInvitation alloc] initAtIndex:index withAssetLockTransaction:tx inWallet:wallet];
                        [invitation registerInWalletForAssetLockTransaction:tx];
                    }
                }
            }
        }
            
    }
//    else if ([transaction isKindOfClass:[DSAssetUnlockTransaction class]]) {
//        DSAssetUnlockTransaction *tx = (DSAssetUnlockTransaction *)transaction;
//    }
}

@end
