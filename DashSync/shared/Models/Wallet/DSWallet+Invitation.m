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

#import "DSInvitation+Protected.h"
#import "DSChain+Params.h"
#import "DSAssetLockTransactionEntity+CoreDataClass.h"
#import "DSWallet+Invitation.h"
#import "NSManagedObject+Sugar.h"
#import <objc/runtime.h>

#define WALLET_BLOCKCHAIN_INVITATIONS_KEY @"WALLET_BLOCKCHAIN_INVITATIONS_KEY"
NSString const *mInvitationsDictionaryKey = @"mInvitationsDictionaryKey";

@interface DSWallet ()

@property (nonatomic, strong) NSMutableDictionary<NSData *, DSInvitation *> *mInvitations;

@end

@implementation DSWallet (Invitation)

- (void)setMInvitations:(NSMutableDictionary<NSData *, DSInvitation *> *)dictionary {
    objc_setAssociatedObject(self, &mInvitationsDictionaryKey, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSData *, DSInvitation *> *)mInvitations {
    return objc_getAssociatedObject(self, &mInvitationsDictionaryKey);
}

- (void)setupInvitations {
    self.mInvitations = nil;
    [self invitations];
}

- (NSString *)walletInvitationsKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_BLOCKCHAIN_INVITATIONS_KEY, [self uniqueIDString]];
}

// MARK: - Invitations


- (uint32_t)invitationsCount {
    return (uint32_t)[self.mInvitations count];
}


//This loads all the identities that the wallet knows about. If the app was deleted and reinstalled the identity information will remain from the keychain but must be reaquired from the network.
- (NSMutableDictionary *)invitations {
    //setKeychainDict(@{}, self.walletInvitationsKey, NO);
    if (self.mInvitations) return self.mInvitations;
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (error) return nil;
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    if (keyChainDictionary) {
        for (NSData *invitationLockedOutpointData in keyChainDictionary) {
            uint32_t index = [keyChainDictionary[invitationLockedOutpointData] unsignedIntValue];
            DSUTXO invitationLockedOutpoint = invitationLockedOutpointData.transactionOutpoint;
            //either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
            //TODO: get the identity from core data
            NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used
            [context performBlockAndWait:^{
                NSUInteger invitationEntitiesCount = [DSBlockchainInvitationEntity countObjectsInContext:context matching:@"chain == %@", [self.chain chainEntityInContext:context]];
                if (invitationEntitiesCount != keyChainDictionary.count)
                    DSLog(@"[%@] Unmatching blockchain invitations count", self.chain.name);
                NSData *identityID = uint256_data([dsutxo_data(invitationLockedOutpoint) SHA256_2]);
                DSBlockchainInvitationEntity *invitationEntity = [DSBlockchainInvitationEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", identityID];
                DSInvitation *invitation = nil;
                if (invitationEntity) {
                    invitation = [[DSInvitation alloc] initAtIndex:index withLockedOutpoint:invitationLockedOutpoint inWallet:self withInvitationEntity:invitationEntity];
                } else {
                    //No blockchain identity is known in core data
                    NSData *transactionHashData = uint256_data(uint256_reverse(invitationLockedOutpoint.hash));
                    DSAssetLockTransactionEntity *creditRegitrationTransactionEntity = [DSAssetLockTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", transactionHashData];
                    if (creditRegitrationTransactionEntity) {
                        //The registration funding transaction exists
                        //Weird but we should recover in this situation
                        DSAssetLockTransaction *registrationTransaction = (DSAssetLockTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];

                        BOOL correctIndex = [registrationTransaction checkInvitationDerivationPathIndexForWallet:self isIndex:index];
                        if (!correctIndex) {
                            NSAssert(FALSE, @"We should implement this");
                        } else {
                            invitation = [[DSInvitation alloc] initAtIndex:index withAssetLockTransaction:registrationTransaction inWallet:self];
                            [invitation registerInWallet];
                        }
                    } else {
                        //We also don't have the registration funding transaction
                        invitation = [[DSInvitation alloc] initAtIndex:index withLockedOutpoint:invitationLockedOutpoint inWallet:self];
                        [invitation registerInWalletForIdentityUniqueId:[dsutxo_data(invitationLockedOutpoint) SHA256_2]];
                    }
                }
                if (invitation)
                    rDictionary[invitationLockedOutpointData] = invitation;
            }];
        }
    }
    self.mInvitations = rDictionary;
    return self.mInvitations;
}

- (DSInvitation *)invitationForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    DSInvitation *foundInvitation = nil;
    for (DSInvitation *invitation in [self.mInvitations allValues]) {
        if (uint256_eq([invitation.identity uniqueID], uniqueId))
            foundInvitation = invitation;
    }
    return foundInvitation;
}

- (uint32_t)unusedInvitationIndex {
    NSArray *invitations = [self.mInvitations allValues];
    NSNumber *max = [invitations valueForKeyPath:@"identity.index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (DSInvitation *)createInvitation {
    return [[DSInvitation alloc] initAtIndex:[self unusedInvitationIndex] inWallet:self];
}

- (DSInvitation *)createInvitationUsingDerivationIndex:(uint32_t)index {
    return [[DSInvitation alloc] initAtIndex:index inWallet:self];
}

- (void)unregisterInvitation:(DSInvitation *)invitation {
    NSParameterAssert(invitation);
    NSAssert(invitation.wallet == self, @"the invitation you are trying to remove is not in this wallet");
    NSAssert(invitation.identity != nil, @"the invitation you are trying to remove has no identity");
    [self.mInvitations removeObjectForKey:invitation.identity.lockedOutpointData];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:invitation.identity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletInvitationsKey, NO);
}

- (void)addInvitation:(DSInvitation *)invitation {
    NSParameterAssert(invitation);
    [self.mInvitations setObject:invitation forKey:invitation.identity.lockedOutpointData];
}

- (void)registerInvitation:(DSInvitation *)invitation {
    NSParameterAssert(invitation);
    NSAssert(invitation.identity != nil, @"the invitation you are trying to remove has no identity");
    if ([self.mInvitations objectForKey:invitation.identity.lockedOutpointData] == nil)
        [self addInvitation:invitation];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (!keyChainDictionary)
        keyChainDictionary = [NSMutableDictionary dictionary];
    NSAssert(uint256_is_not_zero(invitation.identity.uniqueID), @"registrationTransactionHashData must not be null");
    keyChainDictionary[invitation.identity.lockedOutpointData] = @(invitation.identity.index);
    setKeychainDict(keyChainDictionary, self.walletInvitationsKey, NO);
}

- (BOOL)containsInvitation:(DSInvitation *)invitation {
    return invitation.identity.lockedOutpointData && ([self.mInvitations objectForKey:invitation.identity.lockedOutpointData] != nil);
}

- (void)wipeInvitationsInContext:(NSManagedObjectContext *)context {
    for (DSInvitation *invitation in [self.mInvitations allValues]) {
        [self unregisterInvitation:invitation];
        [invitation deletePersistentObjectAndSave:NO inContext:context];
    }
}

@end
