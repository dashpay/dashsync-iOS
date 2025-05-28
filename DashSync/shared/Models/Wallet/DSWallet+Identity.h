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
#import "DSWallet.h"
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSWallet (Identity)

@property (nonatomic, readonly) NSDictionary<NSData *, DSIdentity *> *identities;
@property (nonatomic, readonly, nullable) DSIdentity *defaultIdentity;
@property (nonatomic, readonly) NSArray<NSString *> *identityAddresses;
// the first unused index for blockchain identity registration funding
@property (nonatomic, readonly) uint32_t unusedIdentityIndex;
// the amount of known blockchain identities
@property (nonatomic, readonly) uint32_t identitiesCount;

- (void)setup;
- (void)setupIdentities;
- (void)loadIdentities;

- (void)unregisterIdentity:(DSIdentity *)identity;
- (void)addIdentities:(NSArray<DSIdentity *> *)identities;
- (void)addIdentity:(DSIdentity *)identity;

// Verify makes sure the keys for the blockchain identity are good
- (BOOL)registerIdentities:(NSArray<DSIdentity *> *)identities verify:(BOOL)verify;
- (BOOL)registerIdentity:(DSIdentity *)identity verify:(BOOL)verify;
- (BOOL)registerIdentity:(DSIdentity *)identity;
- (BOOL)containsIdentity:(DSIdentity *)identity;

- (DSIdentity *)createIdentity;
- (DSIdentity *)createIdentityUsingDerivationIndex:(uint32_t)index;
- (DSIdentity *)createIdentityForUsername:(NSString *_Nullable)username;
- (DSIdentity *)createIdentityForUsername:(NSString *_Nullable)username usingDerivationIndex:(uint32_t)index;
- (DSIdentity *_Nullable)identityThatCreatedContract:(DDataContract *)contract withContractId:(UInt256)contractId;
- (DSIdentity *_Nullable)identityForUniqueId:(UInt256)uniqueId;
- (DSIdentity *_Nullable)identityForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key;
//- (DMaybeOpaqueKey *_Nullable)identityPrivateKeyForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key;
- (DOpaqueKey *_Nullable)identityPrivateKeyForIdentityPublicKey:(DIdentityPublicKey *)identity_public_key;

//- (NSUInteger)indexOfIdentityAuthenticationHash:(UInt160)hash;
- (NSUInteger)indexOfIdentityAssetLockRegistrationHash:(UInt160)hash;
- (NSUInteger)indexOfIdentityAssetLockTopupHash:(UInt160)hash;
- (NSUInteger)indexOfIdentityAssetLockInvitationHash:(UInt160)hash;

// Protected
- (void)wipeIdentitiesInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
