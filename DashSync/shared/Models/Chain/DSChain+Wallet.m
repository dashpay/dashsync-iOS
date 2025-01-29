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
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Wallet.h"
#import "DSChainManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSTransactionOutput.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Protected.h"

#define CHAIN_WALLETS_KEY @"CHAIN_WALLETS_KEY"

NSString const *mWalletsKey = @"mWalletsKey";

@implementation DSChain (Wallet)

- (NSString *)chainWalletsKey {
    return [NSString stringWithFormat:@"%@_%@", CHAIN_WALLETS_KEY, [self uniqueID]];
}

// This is a time interval since 1970
- (NSTimeInterval)earliestWalletCreationTime {
    if (![self.wallets count]) return BIP39_CREATION_TIME;
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    for (DSWallet *wallet in self.wallets) {
        if (timeInterval > wallet.walletCreationTime) {
            timeInterval = wallet.walletCreationTime;
        }
    }
    return timeInterval;
}

- (void)reloadDerivationPaths {
    for (DSWallet *wallet in self.mWallets) {
        if (!wallet.isTransient) { //no need to reload transient wallets (those are for testing purposes)
            [wallet reloadDerivationPaths];
        }
    }
}

// MARK: - Wallet

- (NSMutableArray<DSWallet *> *)mWallets {
    return objc_getAssociatedObject(self, &mWalletsKey);
}
- (void)setMWallets:(NSMutableArray<DSWallet *> *)mWallets {
    objc_setAssociatedObject(self, &mWalletsKey, mWallets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (BOOL)hasAWallet {
    return [self.mWallets count] > 0;
}

- (NSArray *)wallets {
    return [self.mWallets copy];
}

- (void)unregisterAllWallets {
    for (DSWallet *wallet in [self.mWallets copy]) {
        [self unregisterWallet:wallet];
    }
}

- (void)unregisterAllWalletsMissingExtendedPublicKeys {
    for (DSWallet *wallet in [self.mWallets copy]) {
        if ([wallet hasAnExtendedPublicKeyMissing]) {
            [self unregisterWallet:wallet];
        }
    }
}

- (void)unregisterWallet:(DSWallet *)wallet {
    NSAssert(wallet.chain == self, @"the wallet you are trying to remove is not on this chain");
    [wallet wipeBlockchainInfoInContext:self.chainManagedObjectContext];
    [wallet wipeWalletInfo];
    [self.mWallets removeObject:wallet];
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueIDString];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    [self notify:DSChainWalletsDidChangeNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
}

- (BOOL)addWallet:(DSWallet *)walletToAdd {
    BOOL alreadyPresent = FALSE;
    for (DSWallet *cWallet in self.mWallets) {
        if ([cWallet.uniqueIDString isEqual:walletToAdd.uniqueIDString])
            alreadyPresent = TRUE;
    }
    if (!alreadyPresent) {
        [self.mWallets addObject:walletToAdd];
        return TRUE;
    }
    return FALSE;
}

- (void)registerWallet:(DSWallet *)wallet {
    BOOL firstWallet = !self.mWallets.count;
    if ([self.mWallets indexOfObject:wallet] == NSNotFound) {
        [self addWallet:wallet];
    }
    
    if (firstWallet) {
        //this is the first wallet, we should reset the last block height to the most recent checkpoint.
        //it will lazy load later
        [self resetLastSyncBlock];
    }
    
    NSError *error = nil;
    NSMutableArray *keyChainArray = [getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    if (![keyChainArray containsObject:wallet.uniqueIDString]) {
        [keyChainArray addObject:wallet.uniqueIDString];
        setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
        [self notify:DSChainWalletsDidChangeNotification userInfo:@{DSChainManagerNotificationChainKey: self}];
    }
}

- (void)retrieveWallets {
    NSError *error = nil;
    NSArray *walletIdentifiers = getKeychainArray(self.chainWalletsKey, @[[NSString class]], &error);
    if (!error && walletIdentifiers) {
        for (NSString *uniqueID in walletIdentifiers) {
            DSWallet *wallet = [[DSWallet alloc] initWithUniqueID:uniqueID forChain:self];
            [self addWallet:wallet];
        }
        //we should load blockchain identies after all wallets are in the chain, as blockchain identities might be on different wallets and have interactions between each other
        for (DSWallet *wallet in self.wallets) {
            [wallet loadIdentities];
        }
    }
}

// MARK: - Merging Wallets

- (DSWallet *)walletHavingIdentityAssetLockRegistrationHash:(UInt160)hash
                                               foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfIdentityAssetLockRegistrationHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingIdentityAssetLockTopupHash:(UInt160)hash
                                        foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfIdentityAssetLockTopupHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingIdentityAssetLockInvitationHash:(UInt160)hash
                                             foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfIdentityAssetLockInvitationHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *)walletHavingProviderVotingAuthenticationHash:(UInt160)hash
                                              foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderVotingAuthenticationHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)hash
                                                      foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOwningAuthenticationHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey
                                                        foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOperatorAuthenticationKey:providerOperatorAuthenticationKey];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletHavingPlatformNodeAuthenticationHash:(UInt160)hash
                                                     foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        NSUInteger index = [wallet indexOfPlatformNodeAuthenticationHash:hash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet *_Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction *_Nonnull)transaction
                                                                                     foundAtIndex:(uint32_t *)rIndex {
    for (DSWallet *wallet in self.wallets) {
        for (DSTransactionOutput *output in transaction.outputs) {
            NSString *address = output.address;
            if (!address || address == (id)[NSNull null]) continue;
            NSUInteger index = [wallet indexOfHoldingAddress:address];
            if (index != NSNotFound) {
                if (rIndex) *rIndex = (uint32_t)index;
                return wallet;
            }
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

// MARK: - Accounts

- (uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSWallet *wallet in self.wallets) {
        rBalance += wallet.balance;
    }
    for (DSDerivationPath *standaloneDerivationPath in self.standaloneDerivationPaths) {
        rBalance += standaloneDerivationPath.balance;
    }
    return rBalance;
}

- (DSAccount *_Nullable)firstAccountWithBalance {
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet firstAccountWithBalance];
        if (account) return account;
    }
    return nil;
}

- (DSAccount *_Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    if (!transaction) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet firstAccountThatCanContainTransaction:transaction];
        if (account) return account;
    }
    return nil;
}

- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSMutableArray *mArray = [NSMutableArray array];
    if (!transaction) return @[];
    for (DSWallet *wallet in self.wallets) {
        [mArray addObjectsFromArray:[wallet accountsThatCanContainTransaction:transaction]];
    }
    return [mArray copy];
}

//- (NSArray *)accountsThatCanContainRustTransaction:(Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *_Nonnull)transaction {
//    NSMutableArray *mArray = [NSMutableArray array];
//    if (!transaction) return @[];
//    for (DSWallet *wallet in self.wallets) {
//        [mArray addObjectsFromArray:[wallet accountsThatCanContainRustTransaction:transaction]];
//    }
//    return [mArray copy];
//
//}


- (DSAccount *_Nullable)accountContainingAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet accountForAddress:address];
        if (account) return account;
    }
    return nil;
}

- (DSAccount *_Nullable)accountContainingDashpayExternalDerivationPathAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet *wallet in self.wallets) {
        DSAccount *account = [wallet accountForDashpayExternalDerivationPathAddress:address];
        if (account) return account;
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount *_Nullable)firstAccountForTransactionHash:(UInt256)txHash
                                           transaction:(DSTransaction **)transaction
                                                wallet:(DSWallet **)wallet {
    for (DSWallet *lWallet in self.wallets) {
        for (DSAccount *account in lWallet.accounts) {
            DSTransaction *lTransaction = [account transactionForHash:txHash];
            if (lTransaction) {
                if (transaction) *transaction = lTransaction;
                if (wallet) *wallet = lWallet;
                return account;
            }
        }
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash
                                         transaction:(DSTransaction **)transaction {
    NSMutableArray *accounts = [NSMutableArray array];
    for (DSWallet *lWallet in self.wallets) {
        for (DSAccount *account in lWallet.accounts) {
            DSTransaction *lTransaction = [account transactionForHash:txHash];
            if (lTransaction) {
                if (transaction) *transaction = lTransaction;
                [accounts addObject:account];
            }
        }
    }
    return [accounts copy];
}
@end
