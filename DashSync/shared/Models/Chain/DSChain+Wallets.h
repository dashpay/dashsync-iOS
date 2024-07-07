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

#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSWallet.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Wallets)
// MARK: Wallet Discovery
- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash
                                                                      foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash
                                                               foundAtIndex:(uint32_t *)rIndex;
- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingInvitationHash:(UInt160)creditFundingInvitationHash
                                                                    foundAtIndex:(uint32_t *)rIndex;
- (DSWallet *_Nullable)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash 
                                                       foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash 
                                                      foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey 
                                                        foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletHavingPlatformNodeAuthenticationHash:(UInt160)platformNodeAuthenticationHash 
                                                     foundAtIndex:(uint32_t *_Nullable)rIndex;
- (DSWallet *_Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction *_Nonnull)transaction 
                                                                                     foundAtIndex:(uint32_t *_Nullable)rIndex;

@end

NS_ASSUME_NONNULL_END
