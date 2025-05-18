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
#import "DSAccountEntity+CoreDataClass.h"
#import "DSAssetLockTransactionEntity+CoreDataClass.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSAssetLockDerivationPath.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet+Identity.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import <objc/runtime.h>

#define WALLET_BLOCKCHAIN_USERS_KEY @"WALLET_BLOCKCHAIN_USERS_KEY"
#define IDENTITY_INDEX_KEY @"IDENTITY_INDEX_KEY"
#define IDENTITY_LOCKED_OUTPUT_KEY @"IDENTITY_LOCKED_OUTPUT_KEY"

NSString const *mIdentitiesDictionaryKey = @"mIdentitiesDictionaryKey";
NSString const *defaultIdentityKey = @"defaultIdentityKey";

@implementation DSWallet (Identity)

- (void)setMIdentities:(NSMutableDictionary<NSData *, DSIdentity *> *)dictionary {
    objc_setAssociatedObject(self, &mIdentitiesDictionaryKey, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSData *, DSIdentity *> *)mIdentities {
    return objc_getAssociatedObject(self, &mIdentitiesDictionaryKey);
}

- (DSIdentity *)defaultIdentity {
    return objc_getAssociatedObject(self, &defaultIdentityKey);
}

- (void)setDefaultIdentity:(DSIdentity *)defaultIdentity {
    objc_setAssociatedObject(self, &defaultIdentityKey, defaultIdentity, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setup {
    self.mIdentities = nil;
    self.mIdentities = [NSMutableDictionary dictionary];
}

- (void)setupIdentities {
    self.mIdentities = nil;
    [self identities];
}

- (NSString *)walletIdentitiesKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_BLOCKCHAIN_USERS_KEY, [self uniqueIDString]];
}

- (NSString *)walletIdentitiesDefaultIndexKey {
    return [NSString stringWithFormat:@"%@_%@_DEFAULT_INDEX", WALLET_BLOCKCHAIN_USERS_KEY, [self uniqueIDString]];
}

- (void)loadIdentities {
    [self.chain.chainManagedObjectContext performBlockAndWait:^{
        NSMutableArray *usedFriendshipIdentifiers = [NSMutableArray array];
        for (NSData *identityData in self.mIdentities) {
            DSIdentity *identity = [self.mIdentities objectForKey:identityData];
            NSSet *outgoingRequests = [identity matchingDashpayUserInContext:self.chain.chainManagedObjectContext].outgoingRequests;
            for (DSFriendRequestEntity *request in outgoingRequests) {
                DSAccount *account = [self accountWithNumber:request.account.index];
                UInt256 destinationIdentityID = request.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256;
                UInt256 sourceIdentityID = identity.uniqueID;
                DSIncomingFundsDerivationPath *path = [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:destinationIdentityID
                                                                                                                        sourceIdentityUniqueId:sourceIdentityID
                                                                                                                                    forAccount:account
                                                                                                                                       onChain:self.chain];
                path.standaloneExtendedPublicKeyUniqueID = request.derivationPath.publicKeyIdentifier;
                path.wallet = self;
                [account addIncomingDerivationPath:path forFriendshipIdentifier:request.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                [usedFriendshipIdentifiers addObject:request.friendshipIdentifier];
            }
        }

        for (NSData *identityUniqueIdData in self.mIdentities) {
            DSIdentity *identity = [self.mIdentities objectForKey:identityUniqueIdData];
            NSSet *incomingRequests = [identity matchingDashpayUserInContext:self.chain.chainManagedObjectContext].incomingRequests;
            for (DSFriendRequestEntity *request in incomingRequests) {
                DSAccount *account = [self accountWithNumber:request.account.index];
                DSIncomingFundsDerivationPath *fundsDerivationPath = [account derivationPathForFriendshipWithIdentifier:request.friendshipIdentifier];
                if (fundsDerivationPath) {
                    //both contacts are on device
                    [account addOutgoingDerivationPath:fundsDerivationPath
                               forFriendshipIdentifier:request.friendshipIdentifier
                                             inContext:self.chain.chainManagedObjectContext];
                } else {
                    NSString *derivationPathPublicKeyIdentifier = request.derivationPath.publicKeyIdentifier;
                    UInt256 destinationIdentityID = request.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256;
                    UInt256 sourceIdentityID = request.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256;
                    DSIncomingFundsDerivationPath *path = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKeyUniqueID:derivationPathPublicKeyIdentifier
                                                                                                             withDestinationIdentityUniqueId:destinationIdentityID
                                                                                                                      sourceIdentityUniqueId:sourceIdentityID
                                                                                                                                     onChain:self.chain];
                    path.wallet = self;
                    path.account = account;
                    [account addOutgoingDerivationPath:path
                               forFriendshipIdentifier:request.friendshipIdentifier
                                             inContext:self.chain.chainManagedObjectContext];
                }
            }
        }

        //this adds the extra information to the transaction and must come after loading all blockchain identities.
        for (DSAccount *account in self.accounts) {
            for (DSTransaction *transaction in account.allTransactions) {
                [transaction loadIdentitiesFromDerivationPaths:account.fundDerivationPaths];
                [transaction loadIdentitiesFromDerivationPaths:account.outgoingFundDerivationPaths];
            }
        }
    }];
}
// MARK: - Identities

- (NSArray *)identityAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self];
    return derivationPath.hasExtendedPublicKey ? [derivationPath addressesToIndex:[self unusedIdentityIndex] + 10 useCache:YES addToCache:YES] : @[];
}

- (void)unregisterIdentity:(DSIdentity *)identity {
    NSParameterAssert(identity);
    NSAssert(identity.wallet == self, @"the identity you are trying to remove is not in this wallet");
    [self.mIdentities removeObjectForKey:identity.uniqueIDData];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletIdentitiesKey, @[[NSNumber class], [NSData class], [NSString class]], &error) mutableCopy];
    if (keyChainDictionary)
        [keyChainDictionary removeObjectForKey:identity.uniqueIDData];
    else
        keyChainDictionary = [NSMutableDictionary dictionary];
    setKeychainDict(keyChainDictionary, self.walletIdentitiesKey, NO);
}

- (void)addIdentities:(NSArray<DSIdentity *> *)identities {
    for (DSIdentity *identity in identities) {
        [self addIdentity:identity];
    }
}

- (void)addIdentity:(DSIdentity *)identity {
    NSParameterAssert(identity);
    NSAssert(uint256_is_not_zero(identity.uniqueID), @"The identity unique ID must be set");
    [self.mIdentities setObject:identity forKey:identity.uniqueIDData];
}

- (BOOL)containsIdentity:(DSIdentity *)identity {
    return identity.lockedOutpointData && ([self.mIdentities objectForKey:identity.uniqueIDData] != nil);
}

- (BOOL)registerIdentities:(NSArray<DSIdentity *> *)identities
                    verify:(BOOL)verify {
    for (DSIdentity *identity in identities) {
        if (![self registerIdentity:identity verify:verify])
            return FALSE;
    }
    return TRUE;
}

- (BOOL)registerIdentity:(DSIdentity *)identity {
    return [self registerIdentity:identity verify:NO];
}

- (BOOL)registerIdentity:(DSIdentity *)identity
                  verify:(BOOL)verify {
    NSParameterAssert(identity);
    if (verify && ![identity verifyKeysForWallet:self]) {
        dash_spv_platform_identity_model_IdentityModel_set_is_local(identity.model, NO);
        return FALSE;
    }
    if ([self.mIdentities objectForKey:identity.uniqueIDData] == nil)
        [self addIdentity:identity];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletIdentitiesKey, @[[NSNumber class], [NSData class], [NSString class]], &error) mutableCopy];
    if (error) return FALSE;
    if (!keyChainDictionary)
        keyChainDictionary = [NSMutableDictionary dictionary];
    NSAssert(uint256_is_not_zero(identity.uniqueID), @"registrationTransactionHashData must not be null");
    keyChainDictionary[identity.uniqueIDData] = uint256_is_zero(identity.lockedOutpointData.transactionOutpoint.hash)
        ? @{IDENTITY_INDEX_KEY: @(identity.index)}
        : @{IDENTITY_INDEX_KEY: @(identity.index), IDENTITY_LOCKED_OUTPUT_KEY: identity.lockedOutpointData};
    setKeychainDict(keyChainDictionary, self.walletIdentitiesKey, NO);
    if (!self.defaultIdentity && (identity.index == 0))
        self.defaultIdentity = identity;
    return TRUE;
}

- (void)wipeIdentitiesInContext:(NSManagedObjectContext *)context {
    for (DSIdentity *identity in [self.mIdentities allValues]) {
        [self unregisterIdentity:identity];
        [identity deletePersistentObjectAndSave:NO inContext:context];
    }
    self.defaultIdentity = nil;
}

- (DSIdentity *_Nullable)identityThatCreatedContract:(DDataContract *)contract
                                      withContractId:(UInt256)contractId {
    NSParameterAssert(contract);
    NSAssert(uint256_is_not_zero(contractId), @"contractId must not be null");
    DSIdentity *foundIdentity = nil;
    for (DSIdentity *identity in [self.mIdentities allValues]) {
        if (uint256_eq([identity contractIdIfRegistered:contract], contractId))
            foundIdentity = identity;
    }
    return foundIdentity;
}

- (DSIdentity *)identityForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    DSIdentity *foundIdentity = nil;
    for (DSIdentity *identity in [self.mIdentities allValues]) {
        if (uint256_eq([identity uniqueID], uniqueId))
            foundIdentity = identity;
    }
    return foundIdentity;
}

- (DSIdentity *)identityForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key {
    DSIdentity *foundIdentity = nil;
    for (DSIdentity *identity in [self.mIdentities allValues]) {
        if ([identity containsPublicKey:identity_public_key])
            foundIdentity = identity;
    }
    return foundIdentity;
}

- (DMaybeOpaqueKey *)identityPrivateKeyForIdentityPublicKey:(dpp_identity_identity_public_key_IdentityPublicKey *)identity_public_key {
    switch (identity_public_key->tag) {
        case dpp_identity_identity_public_key_IdentityPublicKey_V0: {
            dpp_identity_identity_public_key_v0_IdentityPublicKeyV0 *v0 = identity_public_key->v0;
            uint32_t key_index = v0->id->_0;
            for (DSIdentity *identity in [self.mIdentities allValues]) {
                DOpaqueKey *key = [identity keyAtIndex:key_index];
                if (key && DOpaqueKeyPublicKeyDataEqualTo(key, v0->data->_0))
                    return [identity privateKeyAtIndex:key_index ofType:dash_spv_platform_identity_manager_key_kind_from_key_type(v0->key_type)];
            }
            return nil;
        }
        default: return nil;
    }
}

- (uint32_t)identitiesCount {
    return (uint32_t)[self.mIdentities count];
}

- (BOOL)upgradeIdentityKeyChain {
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletIdentitiesKey, @[[NSNumber class], [NSData class], [NSString class]], &error) mutableCopy];
    NSAssert(error == nil, @"There should be no error during upgrade");
    if (error) return FALSE;
    NSMutableDictionary *updated = [NSMutableDictionary dictionary];
    for (NSData *identityLockedOutpoint in keyChainDictionary) {
        [updated setObject:@{IDENTITY_INDEX_KEY: keyChainDictionary[identityLockedOutpoint], IDENTITY_LOCKED_OUTPUT_KEY: identityLockedOutpoint}
                    forKey:uint256_data([identityLockedOutpoint SHA256_2])];
    }
    setKeychainDict(updated, self.walletIdentitiesKey, NO);
    return TRUE;
}


//This loads all the identities that the wallet knows about. If the app was deleted and reinstalled the identity information will remain from the keychain but must be reaquired from the network.
- (NSMutableDictionary *)identities {
    //setKeychainDict(@{}, self.walletIdentitiesKey, NO);
    if (self.mIdentities) return self.mIdentities;
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletIdentitiesKey, @[[NSNumber class], [NSData class], [NSString class]], &error) mutableCopy];
    if (error) return nil;
    uint64_t defaultIndex = getKeychainInt(self.walletIdentitiesDefaultIndexKey, &error);
    if (error) return nil;
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    if (keyChainDictionary && keyChainDictionary.count) {
        if ([[[keyChainDictionary allValues] firstObject] isKindOfClass:[NSNumber class]])
            return [self upgradeIdentityKeyChain] ? (NSMutableDictionary *) [self identities] : nil;
        for (NSData *uniqueIdData in keyChainDictionary) {
            NSDictionary *dict = keyChainDictionary[uniqueIdData];
            uint32_t index = [[dict objectForKey:IDENTITY_INDEX_KEY] unsignedIntValue];
            // either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
            //TODO: get the identity from core data

            NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used

            [context performBlockAndWait:^{
                NSUInteger identityEntitiesCount = [DSBlockchainIdentityEntity countObjectsInContext:context matching:@"chain == %@ && isLocal == TRUE", [self.chain chainEntityInContext:context]];
                if (identityEntitiesCount != keyChainDictionary.count)
                    DSLog(@"[%@] Unmatching blockchain entities count", self.chain.name);
                DSBlockchainIdentityEntity *entity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", uniqueIdData];
                DSIdentity *identity = nil;
                NSDictionary *dict = keyChainDictionary[uniqueIdData];
                NSData *lockedOutpointData = [dict objectForKey:IDENTITY_LOCKED_OUTPUT_KEY];
                if (entity) {
                    if (lockedOutpointData) {
                        identity = [[DSIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpointData.transactionOutpoint inWallet:self withIdentityEntity:entity];
                    } else {
                        identity = [[DSIdentity alloc] initAtIndex:index withUniqueId:uniqueIdData.UInt256 inWallet:self withIdentityEntity:entity];
                    }
                } else if (lockedOutpointData) {
                    //No blockchain identity is known in core data
                    NSData *transactionHashData = uint256_data(uint256_reverse(lockedOutpointData.transactionOutpoint.hash));
                    DSAssetLockTransactionEntity *creditRegitrationTransactionEntity = [DSAssetLockTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", transactionHashData];
                    if (creditRegitrationTransactionEntity) {
                        // The registration funding transaction exists
                        // Weird but we should recover in this situation
                        DSAssetLockTransaction *assetLockTransaction = (DSAssetLockTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];
                        BOOL correctIndex = [assetLockTransaction checkDerivationPathIndexForWallet:self isIndex:index];
                        if (!correctIndex) {
                            DSLog(@"%@: AssetLockTX: IncorrectIndex %u (%@)", self.chain.name, index, assetLockTransaction.toData.hexString);
//                            NSAssert(FALSE, @"We should implement this");
                        } else {
                            identity = [[DSIdentity alloc] initAtIndex:index withAssetLockTransaction:assetLockTransaction inWallet:self];
                            [identity registerInWallet];
                        }
                    } else {
                        // We also don't have the registration funding transaction
                        identity = [[DSIdentity alloc] initAtIndex:index uniqueId:uniqueIdData.UInt256 inWallet:self];
                        [identity registerInWalletForIdentityUniqueId:uniqueIdData.UInt256];
                    }
                } else {
                    identity = [[DSIdentity alloc] initAtIndex:index uniqueId:uniqueIdData.UInt256 inWallet:self];
                    [identity registerInWalletForIdentityUniqueId:uniqueIdData.UInt256];
                }
                if (identity) {
                    rDictionary[uniqueIdData] = identity;
                    if (index == defaultIndex)
                        self.defaultIdentity = identity;
                }
            }];
        }
    }
    self.mIdentities = rDictionary;
    return self.mIdentities;
}

- (uint32_t)unusedIdentityIndex {
    NSArray *identities = [self.mIdentities allValues];
    NSNumber *max = [identities valueForKeyPath:@"index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (DSIdentity *)createIdentity {
    return [[DSIdentity alloc] initAtIndex:[self unusedIdentityIndex] inWallet:self];
}

- (DSIdentity *)createIdentityUsingDerivationIndex:(uint32_t)index {
    return [[DSIdentity alloc] initAtIndex:index inWallet:self];
}

- (DSIdentity *)createIdentityForUsername:(NSString *)username {
    DSIdentity *identity = [self createIdentity];
    [identity addDashpayUsername:username save:NO];
    return identity;
}

- (DSIdentity *)createIdentityForUsername:(NSString *)username
                     usingDerivationIndex:(uint32_t)index {
    DSIdentity *identity = [self createIdentityUsingDerivationIndex:index];
    [identity addDashpayUsername:username save:NO];
    return identity;
}


//- (NSUInteger)indexOfIdentityAuthenticationHash:(UInt160)hash {
//    return [[DSAuthenticationKeysDerivationPath identitiesBLSKeysDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
//}

- (NSUInteger)indexOfIdentityAssetLockRegistrationHash:(UInt160)hash {
    return [[DSAssetLockDerivationPath identityRegistrationFundingDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

- (NSUInteger)indexOfIdentityAssetLockTopupHash:(UInt160)hash {
    return [[DSAssetLockDerivationPath identityTopupFundingDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

- (NSUInteger)indexOfIdentityAssetLockInvitationHash:(UInt160)hash {
    return [[DSAssetLockDerivationPath identityInvitationFundingDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

@end
