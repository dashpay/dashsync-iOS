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

#import <Foundation/Foundation.h>
#import "DSWallet.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Wallet)

// MARK: - Wallets

/*! @brief The wallets in the chain.  */
@property (nonatomic, readonly) NSArray<DSWallet *> *wallets;
@property (nonatomic, strong) NSMutableArray<DSWallet *> *mWallets;

/*! @brief Conveniance method. Does this walleet have a chain?  */
@property (nonatomic, readonly) BOOL hasAWallet;

/*! @brief Conveniance method. The earliest known creation time for any wallet in this chain.  */
@property (nonatomic, readonly) NSTimeInterval earliestWalletCreationTime;

/*! @brief Add a wallet to the chain. It is only temporarily in the chain if externaly added this way.  */
- (BOOL)addWallet:(DSWallet *)wallet;

/*! @brief Unregister a wallet from the chain, it will no longer be loaded or used.  */
- (void)unregisterWallet:(DSWallet *)wallet;

/*! @brief Register a wallet to the chain.  */
- (void)registerWallet:(DSWallet *)wallet;

/*! @brief Unregister all wallets from the chain, they will no longer be loaded or used.  */
- (void)unregisterAllWallets;

/*! @brief Unregister all wallets from the chain that don't have an extended public key in one of their derivation paths, they will no longer be loaded or used.  */
- (void)unregisterAllWalletsMissingExtendedPublicKeys;

// MARK: Wallet Discovery

- (DSWallet *_Nullable)walletHavingIdentityAssetLockRegistrationHash:(UInt160)hash
                                                        foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingIdentityAssetLockTopupHash:(UInt160)hash
                                                 foundAtIndex:(uint32_t *)rIndex;
- (DSWallet *_Nullable)walletHavingIdentityAssetLockInvitationHash:(UInt160)hash
                                                      foundAtIndex:(uint32_t *)rIndex;
- (DSWallet *_Nullable)walletHavingProviderVotingAuthenticationHash:(UInt160)hash
                                                       foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)hash
                                                      foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey
                                                        foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingPlatformNodeAuthenticationHash:(UInt160)hash
                                                     foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction *_Nonnull)transaction
                                                                                     foundAtIndex:(uint32_t *_Nullable)rIndex;

// MARK: - Accounts and Balances

/*! @brief The current wallet balance excluding transactions known to be invalid.  */
@property (nonatomic, readonly) uint64_t balance;

/*! @brief All accounts that contain the specified transaction hash. The transaction is also returned if it is found.  */
- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash
                                         transaction:(DSTransaction *_Nullable *_Nullable)transaction;

/*! @brief Returns the first account with a balance.   */
- (DSAccount *_Nullable)firstAccountWithBalance;

/*! @brief Returns an account to which the given transaction is or can be associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet.  */
- (DSAccount *_Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction;

/*! @brief Returns all accounts to which the given transaction is or can be associated with (even if it hasn't been registered)  */
- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *_Nonnull)transaction;
//- (NSArray *)accountsThatCanContainRustTransaction:(Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *_Nonnull)transaction;

/*! @brief Returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet.  */
- (DSAccount *_Nullable)firstAccountForTransactionHash:(UInt256)txHash
                                           transaction:(DSTransaction *_Nullable *_Nullable)transaction
                                                wallet:(DSWallet *_Nullable *_Nullable)wallet;

/*! @brief Returns an account to which the given address is contained in a derivation path.  */
- (DSAccount *_Nullable)accountContainingAddress:(NSString *)address;

/*! @brief Returns an account to which the given address is known by a dashpay outgoing derivation path.  */
- (DSAccount *_Nullable)accountContainingDashpayExternalDerivationPathAddress:(NSString *)address;

// MARK: Protected
- (void)reloadDerivationPaths;
- (void)retrieveWallets;
@end

NS_ASSUME_NONNULL_END
