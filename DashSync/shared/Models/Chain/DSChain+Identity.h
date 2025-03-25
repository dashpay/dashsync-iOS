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
#import "DSIdentity.h"
#import "DSChain.h"
#import "DSWallet+Identity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Identity)

// MARK: - Identities

/*! @brief Returns a count of local blockchain identities.  */
@property (nonatomic, readonly) uint32_t localIdentitiesCount;

/*! @brief Returns a count of blockchain invitations that have been created locally.  */
@property (nonatomic, readonly) uint32_t localInvitationsCount;

/*! @brief Returns an array of all local blockchain identities.  */
@property (nonatomic, readonly) NSArray<DSIdentity *> *localIdentities;

/*! @brief Returns a dictionary of all local blockchain identities keyed by uniqueId.  */
@property (nonatomic, readonly) NSDictionary<NSData *, DSIdentity *> *localIdentitiesByUniqueIdDictionary;

/*! @brief Returns a blockchain identity by uniqueId, if it exists.  */
- (DSIdentity *_Nullable)identityForUniqueId:(UInt256)uniqueId;

/*! @brief Returns a blockchain identity that could have created this contract.  */
- (DSIdentity *_Nullable)identityThatCreatedContract:(DDataContract *)contract
                                      withContractId:(UInt256)contractId
                                       foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet;

- (DSIdentity *_Nullable)identityForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key
                                        foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet;

/*! @brief Returns a private key that is paired with this identity public key .  */
- (DMaybeOpaqueKey *_Nullable)identityPrivateKeyForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key;

/*! @brief Returns a blockchain identity by uniqueId, if it exists. Also returns the wallet it was found in.  */
- (DSIdentity *_Nullable)identityForUniqueId:(UInt256)uniqueId
                               foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet;

/*! @brief Returns a blockchain identity by uniqueId, if it exists. Also returns the wallet it was found in. Allows to search foreign blockchain identities too  */
- (DSIdentity *)identityForUniqueId:(UInt256)uniqueId
                      foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet
           includeForeignIdentities:(BOOL)includeForeignIdentities;

- (void)wipeIdentitiesPersistedDataInContext:(NSManagedObjectContext *)context;
- (void)wipeInvitationsPersistedDataInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
