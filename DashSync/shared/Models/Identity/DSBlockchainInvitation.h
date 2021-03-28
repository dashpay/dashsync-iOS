//  
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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

@class DSBlockchainIdentity, DSWallet, DSCreditFundingTransaction;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSBlockchainInvitationDidUpdateNotification;
FOUNDATION_EXPORT NSString *const DSBlockchainInvitationKey;
FOUNDATION_EXPORT NSString *const DSBlockchainInvitationUpdateEvents;
FOUNDATION_EXPORT NSString *const DSBlockchainInvitationUpdateLink;

@interface DSBlockchainInvitation : NSObject

/*! @brief This is the identity that was made from the invitation. There should always be an identity associated to a blockchain invitation. This identity might not yet be registered on Dash Platform. */
@property (nonatomic,readonly) DSBlockchainIdentity * identity;

/*! @brief This is the wallet holding the blockchain invitation. There should always be a wallet associated to a blockchain invitation. */
@property (nonatomic, weak, readonly) DSWallet *wallet;


- (void)generateBlockchainInvitationsExtendedPublicKeysWithPrompt:(NSString *)prompt completion:(void (^_Nullable)(BOOL registered))completion;

/*! @brief Register the blockchain identity to its wallet. This should only be done once on the creation of the blockchain identity.
*/
- (void)registerInWallet;

/*! @brief Unregister the blockchain identity from the wallet. This should only be used if the blockchain identity is not yet registered or if a progressive wallet wipe is happening.
    @discussion When a blockchain identity is registered on the network it is automatically retrieved from the L1 chain on resync. If a client wallet wishes to change their default blockchain identity in a wallet it should be done by marking the default blockchain identity index in the wallet. Clients should not try to delete a registered blockchain identity from a wallet.
 */
- (BOOL)unregisterLocally;

/*! @brief Register the blockchain invitation to its wallet from a credit funding registration transaction. This should only be done once on the creation of the blockchain invitation.
    @param fundingTransaction The funding transaction used to initially fund the blockchain identity.
*/
- (void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction *)fundingTransaction;


@end

NS_ASSUME_NONNULL_END
