//
//  DSFriendRequestEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "BigIntTypes.h"
#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSPaymentRequest.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@interface DSFriendRequestEntity ()

@end

@implementation DSFriendRequestEntity

+ (void)deleteFriendRequestsOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *friendRequestsToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(derivationPath.chain == %@)", chainEntity];
        for (DSFriendRequestEntity *friendRequest in friendRequestsToDelete) {
            [friendRequest.managedObjectContext deleteObject:friendRequest];
        }
    }];
}

+ (DSFriendRequestEntity *)existingFriendRequestEntityOnFriendshipIdentifier:(NSData *)friendshipIdentifier inContext:(NSManagedObjectContext *)context {
    DSFriendRequestEntity *friendRequestEntity = [self anyObjectInContext:context matching:@"(friendshipIdentifier == %@)", friendshipIdentifier];
    //    if (!friendRequestEntity) {
    //        DSLog(@"No friend request entity on friendship identifier %@ %@", friendshipIdentifier.hexString, [NSThread callStackSymbols]);
    //    }
    return friendRequestEntity;
}

+ (DSFriendRequestEntity *)existingFriendRequestEntityWithSourceIdentifier:(UInt256)sourceIdentifier destinationIdentifier:(UInt256)destinationIdentifier onAccountIndex:(uint32_t)accountIndex inContext:(NSManagedObjectContext *)context {
    NSData *friendshipIdentifier = [self friendshipIdentifierWithSourceIdentifier:sourceIdentifier destinationIdentifier:destinationIdentifier onAccountIndex:accountIndex];
    return [self existingFriendRequestEntityOnFriendshipIdentifier:friendshipIdentifier inContext:context];
}

+ (NSData *)friendshipIdentifierWithSourceIdentifier:(UInt256)sourceIdentifier destinationIdentifier:(UInt256)destinationIdentifier onAccountIndex:(uint32_t)accountIndex {
    UInt256 friendship = uint256_xor(sourceIdentifier, destinationIdentifier);
    if (uint256_sup(sourceIdentifier, destinationIdentifier)) {
        //the destination should always be bigger than the source, otherwise add 1 on the 32nd bit to differenciate them
        friendship = uInt256AddLE(friendship, uint256_from_int(1 << 31));
    }
    UInt256 friendshipOnAccount = uint256_xor(friendship, uint256_from_int(accountIndex));
    return uint256_data(friendshipOnAccount);
}

- (NSData *)finalizeWithFriendshipIdentifier {
    NSAssert(self.sourceContact, @"source contact must exist");
    NSAssert(self.destinationContact, @"destination contact must exist");
    NSAssert(self.account, @"account must exist");
    UInt256 sourceIdentifier = self.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256;
    UInt256 destinationIdentifier = self.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256;
    self.friendshipIdentifier = [DSFriendRequestEntity friendshipIdentifierWithSourceIdentifier:sourceIdentifier destinationIdentifier:destinationIdentifier onAccountIndex:self.account.index];
    //DSLog(@"Creating friend request on friendship identifier %@ %@", self.friendshipIdentifier.hexString, [NSThread callStackSymbols]);
    return self.friendshipIdentifier;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - { %@ -> %@ / %d }", [super debugDescription], self.sourceContact.associatedBlockchainIdentity.dashpayUsername.stringValue, self.destinationContact.associatedBlockchainIdentity.dashpayUsername.stringValue, self.account.index];
}

- (void)sendAmount:(uint64_t)amount fromAccount:(DSAccount *)account requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                 presentChallenge:(DSTransactionChallengeBlock)challenge
    transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                 signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
              publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
           errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSIncomingFundsDerivationPath *derivationPath = [account derivationPathForFriendshipWithIdentifier:self.friendshipIdentifier];
    NSAssert(derivationPath.extendedPublicKeyData, @"Extended public key must exist already");
    NSString *address = [derivationPath receiveAddress];

    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:address onChain:account.wallet.chain];
    paymentRequest.amount = amount;

    NSAssert([paymentRequest isValidAsNonDashpayPaymentRequest], @"Payment request must be valid");

    [account.wallet.chain.chainManager.transactionManager confirmPaymentRequest:paymentRequest
                                                    usingUserIdentity:nil
                                                                    fromAccount:account
                                                          acceptInternalAddress:NO
                                                           acceptReusingAddress:YES
                                                        addressIsFromPasteboard:NO
                                           requiresSpendingAuthenticationPrompt:YES
                                    keepAuthenticatedIfErrorAfterAuthentication:NO
                                                       requestingAdditionalInfo:additionalInfoRequest
                                                               presentChallenge:challenge
                                                  transactionCreationCompletion:transactionCreationCompletion
                                                               signedCompletion:signedCompletion
                                                            publishedCompletion:publishedCompletion
                                                         errorNotificationBlock:errorNotificationBlock];
}

@end
