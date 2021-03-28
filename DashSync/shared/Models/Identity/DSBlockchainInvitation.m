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

#import "DSBlockchainInvitation.h"
#import "DSAuthenticationManager.h"
#import "DSDerivationPathFactory.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSWallet.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSCreditFundingTransaction.h"
#import "DSBlockchainInvitationEntity+CoreDataClass.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainManager.h"

@interface DSBlockchainInvitation()

@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, strong) DSBlockchainIdentity * identity;
@property (nonatomic, assign) BOOL isTransient;

@end

@implementation DSBlockchainInvitation

- (instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet *)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);

    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index isForInvitation:YES inWallet:wallet];
    self.chain = wallet.chain;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction *)transaction inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    if (![transaction isCreditFundingTransaction]) return nil;
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:transaction withUsernameDictionary:nil inWallet:wallet];
    self.chain = wallet.chain;

    return self;
}


- (void)generateBlockchainInvitationsExtendedPublicKeysWithPrompt:(NSString *)prompt completion:(void (^_Nullable)(BOOL registered))completion {
    __block DSCreditFundingDerivationPath *derivationPathInvitationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityInvitationFundingDerivationPathForWallet:self.wallet];
    if ([derivationPathInvitationFunding hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                   forWallet:self.wallet
                                                   forAmount:0
                                         forceAuthentication:NO
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                      if (!seed) {
                                                          completion(NO);
                                                          return;
                                                      }
                                                      [derivationPathInvitationFunding generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueIDString];
                                                      completion(YES);
                                                  }];
}


- (void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction *)fundingTransaction {
    NSAssert(self.identity != nil, @"The identity must already exist");
    [self.identity setInvitationRegistrationCreditFundingTransaction:fundingTransaction];
    [self registerInWalletForBlockchainIdentityUniqueId:fundingTransaction.creditBurnIdentityIdentifier];

    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [fundingTransaction markInvitationAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    [self.identity setInvitationUniqueId:blockchainIdentityUniqueId];
    [self registerInWallet];
}

- (BOOL)isRegisteredInWallet {
    if (!self.wallet) return FALSE;
    return [self.wallet containsBlockchainInvitation:self];
}

- (void)registerInWallet {
    NSAssert(self.identity.isInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isInvitation) return;
    [self.wallet registerBlockchainInvitation:self];
    [self saveInitial];
}

- (BOOL)unregisterLocally {
    NSAssert(self.identity.isInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isInvitation) return FALSE;
    if (self.identity.isRegistered) return FALSE; //if the invitation has already been used we can not unregister it
    [self.wallet unregisterBlockchainInvitation:self];
    [self deletePersistentObjectAndSave:YES inContext:[NSManagedObjectContext platformContext]];
    return TRUE;
}


- (void)saveInitial {
    [self saveInitialInContext:[NSManagedObjectContext platformContext]];
}

- (void)saveInitialInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        DSBlockchainInvitationEntity *entity = [DSBlockchainInvitationEntity managedObjectInBlockedContext:context];
        entity.chain = [self.chain chainEntityInContext:context];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self}];
        });
    }];
}

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray *updateEvents = [NSMutableArray array];
        DSBlockchainInvitationEntity *entity = [self blockchainInvitationEntityInContext:context];
        if (entity.link != self.link) {
            entity.link = self.link;
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainInvitationUpdateLink];
        }
        if (changeOccured) {
            [context ds_save];
            if (updateEvents.count) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self, DSBlockchainInvitationUpdateEvents: updateEvents}];
                });
            }
        }
    }];
}

// MARK: Deletion

- (void)deletePersistentObjectAndSave:(BOOL)save inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSBlockchainInvitationEntity *blockchainInvitationEntity = [self blockchainInvitationEntityInContext:context];
        if (blockchainInvitationEntity) {
            NSSet<DSFriendRequestEntity *> *friendRequests = [blockchainInvitationEntity.matchingDashpayUser outgoingRequests];
            for (DSFriendRequestEntity *friendRequest in friendRequests) {
                uint32_t accountNumber = friendRequest.account.index;
                DSAccount *account = [self.wallet accountWithNumber:accountNumber];
                [account removeIncomingDerivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
            [blockchainInvitationEntity deleteObjectAndWait];
            if (save) {
                [context ds_save];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self}];
        });
    }];
}

// MARK: Entity

- (DSBlockchainInvitationEntity *)blockchainInvitationEntity {
    return [self blockchainInvitationEntityInContext:[NSManagedObjectContext viewContext]];
}

- (DSBlockchainInvitationEntity *)blockchainInvitationEntityInContext:(NSManagedObjectContext *)context {
    __block DSBlockchainInvitationEntity *entity = nil;
    [context performBlockAndWait:^{
        entity = [DSBlockchainInvitationEntity anyObjectInContext:context matching:@"uniqueID == %@", self.uniqueIDData];
    }];
    NSAssert(entity, @"An entity should always be found");
    return entity;
}

- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%d-%@-%@}", self.identity.index, self.identity.currentDashpayUsername, self.uniqueIdString]];
}


@end
