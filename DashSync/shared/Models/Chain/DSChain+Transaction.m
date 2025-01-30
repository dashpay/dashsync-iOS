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
//#import "DSIdentityRegistrationTransition.h"
#import "DSInvitation+Protected.h"
#import "DSChain+Transaction.h"
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

//- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction {
//    const uint64_t sent = [self amountSentByTransaction:transaction];
//    const uint64_t received = [self amountReceivedFromTransaction:transaction];
//    const uint64_t fee = transaction.feeUsed;
//
//    if (sent > 0 && (received + fee) == sent) {
//        // moved
//        return DSTransactionDirection_Moved;
//    } else if (sent > 0) {
//        // sent
//        return DSTransactionDirection_Sent;
//    } else if (received > 0) {
//        // received
//        return DSTransactionDirection_Received;
//    } else {
//        // no funds moved on this account
//        return DSTransactionDirection_NotAccountFunds;
//    }
//}

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


- (BOOL)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction
                                saveImmediately:(BOOL)saveImmediately {
    DSWallet *ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil];
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil];
    DSWallet *holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil];
    DSWallet *platformNodeWallet = [self walletHavingPlatformNodeAuthenticationHash:providerRegistrationTransaction.platformNodeID foundAtIndex:nil];
    DSAccount *account = [self accountContainingAddress:providerRegistrationTransaction.payoutAddress];
    BOOL registered = NO;
    registered |= [account registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [ownerWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [votingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [operatorWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [holdingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    registered |= [platformNodeWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    
    if (ownerWallet) {
        DSAuthenticationKeysDerivationPath *ownerDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:ownerWallet];
        [ownerDerivationPath registerTransactionAddress:providerRegistrationTransaction.ownerAddress];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerRegistrationTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerRegistrationTransaction.operatorAddress];
    }
    
    if (holdingWallet) {
        DSMasternodeHoldingsDerivationPath *holdingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:holdingWallet];
        [holdingDerivationPath registerTransactionAddress:providerRegistrationTransaction.holdingAddress];
    }
    
    if (platformNodeWallet) {
        DSAuthenticationKeysDerivationPath *platformNodeDerivationPath = [[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:platformNodeWallet];
        [platformNodeDerivationPath registerTransactionAddress:providerRegistrationTransaction.platformNodeAddress];
    }
    
    return registered;
}

- (BOOL)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction *)providerUpdateServiceTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount *account = [self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    }
    return registered;
}


- (BOOL)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction *)providerUpdateRegistrarTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet *operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount *account = [self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress];
    BOOL registered = [account registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        registered |= [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath *votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath *operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.operatorAddress];
    }
    return registered;
}

- (BOOL)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction *)providerUpdateRevocationTransaction saveImmediately:(BOOL)saveImmediately {
    DSWallet *providerRegistrationWallet = nil;
    DSTransaction *providerRegistrationTransaction = [self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        return [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRevocationTransaction saveImmediately:saveImmediately];
    } else {
        return NO;
    }
}

//-(BOOL)registerTransition:(DSTransition*)transition {
//    DSWallet * identityRegistrationWallet = nil;
//    DSTransaction * identityRegistrationTransaction = [self transactionForHash:transition.registrationTransactionHash returnWallet:&identityRegistrationWallet];
//    if (identityRegistrationTransaction && identityRegistrationWallet) {
//        return [identityRegistrationWallet.specialTransactionsHolder registerTransaction:transition];
//    } else {
//        return NO;
//    }
//}

- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        return [self registerProviderRegistrationTransaction:providerRegistrationTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        return [self registerProviderUpdateServiceTransaction:providerUpdateServiceTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        return [self registerProviderUpdateRegistrarTransaction:providerUpdateRegistrarTransaction saveImmediately:saveImmediately];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        return [self registerProviderUpdateRevocationTransaction:providerUpdateRevocationTransaction saveImmediately:saveImmediately];
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
        uint32_t index;
        DSWallet *wallet = [self walletHavingIdentityAssetLockRegistrationHash:tx.creditBurnPublicKeyHash foundAtIndex:&index];
        if (wallet) {
            DSIdentity *identity = [wallet identityForUniqueId:tx.creditBurnIdentityIdentifier];
            if (!identity) {
                identity = [[DSIdentity alloc] initAtIndex:index withAssetLockTransaction:tx withUsernameDictionary:nil inWallet:wallet];
                [identity registerInWalletForAssetLockTransaction:tx];
            }
        } else {
            wallet = [self walletHavingIdentityAssetLockInvitationHash:tx.creditBurnPublicKeyHash foundAtIndex:&index];
            if (wallet) {
                DSInvitation *invitation = [wallet invitationForUniqueId:tx.creditBurnIdentityIdentifier];
                if (!invitation) {
                    invitation = [[DSInvitation alloc] initAtIndex:index withAssetLockTransaction:tx inWallet:wallet];
                    [invitation registerInWalletForAssetLockTransaction:tx];
                }
            }
        }

    }
//    else if ([transaction isKindOfClass:[DSAssetUnlockTransaction class]]) {
//        DSAssetUnlockTransaction *tx = (DSAssetUnlockTransaction *)transaction;
//    }
}

@end
