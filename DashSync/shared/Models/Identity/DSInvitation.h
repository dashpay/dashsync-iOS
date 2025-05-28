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

#import "DSAssetLockTransaction.h"
#import "DSIdentity.h"
#import <Foundation/Foundation.h>

@class DSIdentity, DSWallet;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSInvitationDidUpdateNotification;
FOUNDATION_EXPORT NSString *const DSInvitationKey;
FOUNDATION_EXPORT NSString *const DSInvitationUpdateEvents;
FOUNDATION_EXPORT NSString *const DSInvitationUpdateEventLink;

@interface DSInvitation : NSObject

/*! @brief Initialized with an invitation link. The wallet must be on a chain that supports platform features.
 */
- (instancetype)initWithInvitationLink:(NSString *)invitationLink inWallet:(DSWallet *)wallet;

/*! @brief This is the identity that was made from the invitation. There should always be an identity associated to a blockchain invitation. This identity might not yet be registered on Dash Platform. */
@property (nonatomic, readonly) DSIdentity *identity;

/*! @brief This is an invitation that was created locally. */
@property (nonatomic, readonly) BOOL createdLocally;

/*! @brief This is an invitation that was created with an external link, and has not yet retrieved the identity. */
@property (nonatomic, readonly) BOOL needsIdentityRetrieval;

/*! @brief This is the wallet holding the blockchain invitation. There should always be a wallet associated to a blockchain invitation. */
@property (nonatomic, weak, readonly) DSWallet *wallet;

/*! @brief A name for locally created invitation. */
@property (nonatomic, nullable, copy) NSString *name;

/*! @brief A tag for locally created invitation. */
@property (nonatomic, copy) NSString *tag;

/*! @brief Verifies the current invitation link in the invitation was created with a link. If the invitation is valid a transaction will be returned, as well as if the transaction has already been spent.
    TODO:Spent currently does not work
 */
- (void)verifyInvitationLinkWithCompletion:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion
                           completionQueue:(dispatch_queue_t)completionQueue;

/*! @brief Verifies an invitation link. The chain must support platform features. If the invitation is valid a transaction will be returned, as well as if the transaction has already been spent.
    TODO:Spent currently does not work
 */
+ (void)verifyInvitationLink:(NSString *)invitationLink
                     onChain:(DSChain *)chain
                  completion:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion
             completionQueue:(dispatch_queue_t)completionQueue;

/*! @brief Registers the blockchain identity if the invitation was created with an invitation link. The blockchain identity is then associated with the invitation. */
- (void)acceptInvitationUsingWalletIndex:(uint32_t)index setDashpayUsername:(NSString *)dashpayUsername authenticationPrompt:(NSString *)authenticationMessage identityRegistrationSteps:(DSIdentityRegistrationStep)identityRegistrationSteps stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion completionQueue:(dispatch_queue_t)completionQueue;

/*! @brief Generates blockchain invitations' extended public keys by asking the user to authentication with the prompt. */
- (void)generateInvitationsExtendedPublicKeysWithPrompt:(NSString *)prompt completion:(void (^_Nullable)(BOOL registered))completion;

/*! @brief Register the blockchain identity to its wallet. This should only be done once on the creation of the blockchain identity.
*/
- (void)registerInWallet;

/*! @brief Update the blockchain identity to its wallet.
 */
- (void)updateInWallet;

/*! @brief Unregister the blockchain identity from the wallet. This should only be used if the blockchain identity is not yet registered or if a progressive wallet wipe is happening.
    @discussion When a blockchain identity is registered on the network it is automatically retrieved from the L1 chain on resync. If a client wallet wishes to change their default blockchain identity in a wallet it should be done by marking the default blockchain identity index in the wallet. Clients should not try to delete a registered blockchain identity from a wallet.
 */
- (BOOL)unregisterLocally;

/*! @brief Register the blockchain invitation to its wallet from a asset lock registration transaction. This should only be done once on the creation of the blockchain invitation.
    @param transaction The asset lock transaction used to initially fund the blockchain identity.
*/
- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)transaction;

/*! @brief Create the invitation full link and mark the "fromIdentity" as the source of the invitation.
    @param identity The source of the invitation.
*/
- (void)createInvitationFullLinkFromIdentity:(DSIdentity *)identity completion:(void (^_Nullable)(BOOL cancelled, NSString *_Nullable invitationFullLink))completion;


@end

NS_ASSUME_NONNULL_END
