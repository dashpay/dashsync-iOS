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

#import "DSChain+Identity.h"
#import "DSChain+Wallet.h"
#import "DSWallet+Invitation.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainInvitationEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSIdentitiesManager+CoreData.h"
#import "NSManagedObject+Sugar.h"

@implementation DSChain (Identity)

// MARK: - Identities

- (uint32_t)localIdentitiesCount {
    uint32_t identitiesCount = 0;
    for (DSWallet *lWallet in self.wallets) {
        identitiesCount += [lWallet identitiesCount];
    }
    return identitiesCount;
}

- (NSArray<DSIdentity *> *)localIdentities {
    NSMutableArray *rAllIdentities = [NSMutableArray array];
    for (DSWallet *wallet in self.wallets) {
        [rAllIdentities addObjectsFromArray:[wallet.identities allValues]];
    }
    return rAllIdentities;
}

- (NSDictionary<NSData *, DSIdentity *> *)localIdentitiesByUniqueIdDictionary {
    NSMutableDictionary *rAllIdentities = [NSMutableDictionary dictionary];
    for (DSWallet *wallet in self.wallets) {
        for (DSIdentity *identity in [wallet.identities allValues]) {
            rAllIdentities[identity.uniqueIDData] = identity;
        }
    }
    return rAllIdentities;
}


- (DSIdentity *)identityForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    return [self identityForUniqueId:uniqueId foundInWallet:nil includeForeignIdentities:NO];
}

- (DSIdentity *)identityForUniqueId:(UInt256)uniqueId
                      foundInWallet:(DSWallet **)foundInWallet {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    return [self identityForUniqueId:uniqueId foundInWallet:foundInWallet includeForeignIdentities:NO];
}

- (DSIdentity *_Nullable)identityThatCreatedContract:(DDataContract *)contract
                                      withContractId:(UInt256)contractId
                                       foundInWallet:(DSWallet **)foundInWallet {
    NSAssert(uint256_is_not_zero(contractId), @"contractId must not be null");
    for (DSWallet *wallet in self.wallets) {
        DSIdentity *identity = [wallet identityThatCreatedContract:contract withContractId:contractId];
        if (identity) {
            if (foundInWallet)
                *foundInWallet = wallet;
            return identity;
        }
    }
    return nil;
}

- (DSIdentity *)identityForUniqueId:(UInt256)uniqueId
                      foundInWallet:(DSWallet **)foundInWallet
           includeForeignIdentities:(BOOL)includeForeignIdentities {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    for (DSWallet *wallet in self.wallets) {
        DSIdentity *identity = [wallet identityForUniqueId:uniqueId];
        if (identity) {
            if (foundInWallet)
                *foundInWallet = wallet;
            return identity;
        }
    }
    return includeForeignIdentities ? [self.chainManager.identitiesManager foreignIdentityWithUniqueId:uniqueId] : nil;
}

- (DSIdentity *)identityForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key
                               foundInWallet:(DSWallet **)foundInWallet  {
    for (DSWallet *wallet in self.wallets) {
        DSIdentity *identity = [wallet identityForIdentityPublicKey:identity_public_key];
        if (identity) {
            if (foundInWallet)
                *foundInWallet = wallet;
            return identity;
        }
    }
    return nil;
}

- (DOpaqueKey *_Nullable)identityPrivateKeyForIdentityPublicKey:(DIdentityPublicKey *)identity_public_key {
    for (DSWallet *wallet in self.wallets) {
        DOpaqueKey *identity_private_key = [wallet identityPrivateKeyForIdentityPublicKey:identity_public_key];
        if (identity_private_key)
            return identity_private_key;
    }
    return nil;
}

- (void)wipeIdentitiesPersistedDataInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        NSArray *objects = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@", [self chainEntityInContext:context]];
        [DSBlockchainIdentityEntity deleteObjects:objects inContext:context];
    }];
}

// MARK: - Invitations

- (uint32_t)localInvitationsCount {
    uint32_t invitationsCount = 0;
    for (DSWallet *lWallet in self.wallets) {
        invitationsCount += [lWallet invitationsCount];
    }
    return invitationsCount;
}

- (void)wipeInvitationsPersistedDataInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        NSArray *objects = [DSBlockchainInvitationEntity objectsInContext:context matching:@"chain == %@", [self chainEntityInContext:context]];
        [DSBlockchainInvitationEntity deleteObjects:objects inContext:context];
    }];
}

// TODO: should we revive this?
//
//-(BOOL)registerBlockchainIdentityRegistrationTransaction:(DSIdentityRegistrationTransition*)identityRegistrationTransaction {
//    DSWallet * identityWallet = [self walletHavingIdentityAuthenticationHash:identityRegistrationTransaction.pubkeyHash foundAtIndex:nil];
//    BOOL registered = [odentityWallet.specialTransactionsHolder registerTransaction:identityRegistrationTransaction];
//
//    if (identityWallet) {
//        DSAuthenticationKeysDerivationPath * identitiesDerivationPath = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:identityWallet];
//        [identitiesDerivationPath registerTransactionAddress:identityRegistrationTransaction.pubkeyAddress];
//    }
//    return registered;
//}
//
//-(BOOL)registerIdentityResetTransaction:(DSIdentityUpdateTransition*)identityResetTransaction {
//    DSWallet * identityWallet = [self walletHavingIdentityAuthenticationHash:identityResetTransaction.replacementPublicKeyHash foundAtIndex:nil];
//    [identityWallet.specialTransactionsHolder registerTransaction:identityResetTransaction];
//    DSWallet * identityRegistrationWallet = nil;
//    DSTransaction * identityRegistrationTransaction = [self transactionForHash:identityResetTransaction.registrationTransactionHash returnWallet:&identityRegistrationWallet];
//    BOOL registered = NO;
//    if (identityRegistrationTransaction && identityRegistrationWallet && (identityWallet != identityRegistrationWallet)) {
//        registered = [identityRegistrationWallet.specialTransactionsHolder registerTransaction:identityResetTransaction];
//    }
//
//    if (identityWallet) {
//        DSAuthenticationKeysDerivationPath * identitiesDerivationPath = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:identityWallet];
//        [identitiesDerivationPath registerTransactionAddress:identityResetTransaction.replacementAddress];
//    }
//    return registered;
//}
//
//-(BOOL)registerIdentityCloseTransaction:(DSIdentityCloseTransition*)identityCloseTransaction {
//    DSWallet * identityRegistrationWallet = nil;
//    DSTransaction * identityRegistrationTransaction = [self transactionForHash:identityCloseTransaction.registrationTransactionHash returnWallet:&identityRegistrationWallet];
//    if (identityRegistrationTransaction && identityRegistrationWallet) {
//        return [identityRegistrationWallet.specialTransactionsHolder registerTransaction:identityCloseTransaction];
//    } else {
//        return NO;
//    }
//}
//
//-(BOOL)registerIdentityTopupTransaction:(DSIdentityTopupTransition*)identityTopupTransaction {
//    DSWallet * identityRegistrationWallet = nil;
//    DSTransaction * identityRegistrationTransaction = [self transactionForHash:identityTopupTransaction.registrationTransactionHash returnWallet:&identityRegistrationWallet];
//    if (identityRegistrationTransaction && identityRegistrationWallet) {
//        return [identityRegistrationWallet.specialTransactionsHolder registerTransaction:identityTopupTransaction];
//    } else {
//        return NO;
//    }
//}
//

@end
