//
//  DSdashpayUserEntity+CoreDataClass.m
//  Copyright © 2019 Dash Core Group. All rights reserved.
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
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSDashPlatform.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSFundsDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSPaymentRequest.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSTransactionManager.h"
#import "DSTransientDashpayUser.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation DSDashpayUserEntity

+ (void)deleteContactsOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *contactsToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
        for (DSDashpayUserEntity *contact in contactsToDelete) {
            [chainEntity.managedObjectContext deleteObject:contact];
        }
    }];
}

- (NSArray<DSDashpayUserEntity *> *)mostActiveFriends:(DSDashpayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending {
    NSDictionary<NSData *, NSNumber *> *friendsWithActivity = [self friendsWithActivityForType:activityType count:count ascending:ascending];
    if (!friendsWithActivity.count) return @[];
    NSArray *results = [DSDashpayUserEntity objectsInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID IN %@", friendsWithActivity.allKeys];
    return results;
}


- (NSDictionary<NSData *, NSNumber *> *)friendsWithActivityForType:(DSDashpayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:DSTxOutputEntity.entityName];

    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"n"]; // Does not really matter
    NSExpression *countExpression = [NSExpression expressionForFunction:@"count:"
                                                              arguments:@[keyPathExpression]];
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName:@"count"];
    [expressionDescription setExpression:countExpression];
    [expressionDescription setExpressionResultType:NSInteger32AttributeType];
    if (activityType == DSDashpayUserEntityFriendActivityType_IncomingTransactions) {
        [fetchRequest setPropertiesToFetch:@[@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID", expressionDescription]];
        [fetchRequest setPropertiesToGroupBy:@[@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID"]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest != NULL && localAddress.derivationPath.friendRequest.sourceContact == %@", self]]; //first part is an optimization for left outer joins
    } else if (activityType == DSDashpayUserEntityFriendActivityType_OutgoingTransactions) {
        [fetchRequest setPropertiesToFetch:@[@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID", expressionDescription]];
        [fetchRequest setPropertiesToGroupBy:@[@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID"]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest != NULL && localAddress.derivationPath.friendRequest.destinationContact == %@", self]]; //first part is an optimization for left outer joins
    }
    [fetchRequest setResultType:NSDictionaryResultType];
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:NULL];

    NSArray *orderedResults = [results sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"count" ascending:ascending]]];
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    NSUInteger i = 0;
    for (NSDictionary *result in orderedResults) {
        if (activityType == DSDashpayUserEntityFriendActivityType_IncomingTransactions) {
            rDictionary[result[@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID"]] = result[@"count"];
        } else if (activityType == DSDashpayUserEntityFriendActivityType_OutgoingTransactions) {
            rDictionary[result[@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID"]] = result[@"count"];
        }
        i++;
        if (i == count) break;
    }
    return rDictionary;
}

- (NSString *)username {
    //todo manage when more than 1 username
    DSBlockchainIdentityUsernameEntity *username = self.associatedBlockchainIdentity.dashpayUsername ? self.associatedBlockchainIdentity.dashpayUsername : [self.associatedBlockchainIdentity.usernames anyObject];
    return username.stringValue;
}

- (NSError *)applyTransientDashpayUser:(DSTransientDashpayUser *)transientDashpayUser save:(BOOL)save {
    if (!self.documentIdentifier) {
        self.documentIdentifier = transientDashpayUser.documentIdentifier;
    } else if (self.documentIdentifier) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Error when updating profile information", nil)}];
    }
    self.localProfileDocumentRevision = transientDashpayUser.revision;
    self.remoteProfileDocumentRevision = transientDashpayUser.revision;
    self.avatarPath = transientDashpayUser.avatarPath;
    self.publicMessage = transientDashpayUser.publicMessage;
    self.displayName = transientDashpayUser.displayName;

    self.createdAt = transientDashpayUser.createdAt;
    self.updatedAt = transientDashpayUser.updatedAt;

    if (save) {
        [self.managedObjectContext ds_save];
    }
    return nil;
}

- (void)sendAmount:(uint64_t)amount fromAccount:(DSAccount *)account toFriend:(DSDashpayUserEntity *)friend requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                 presentChallenge:(DSTransactionChallengeBlock)challenge
    transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                 signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
              publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
           errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSFriendRequestEntity *friendRequest = [[self.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", friend]] anyObject];
    NSAssert(friendRequest, @"there must be a friendRequest");
    [friendRequest sendAmount:amount fromAccount:account requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion errorNotificationBlock:errorNotificationBlock];
}

- (void)sendAmount:(uint64_t)amount fromAccount:(DSAccount *)account toFriendWithIdentityIdentifier:(UInt256)identityIdentifier requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                  presentChallenge:(DSTransactionChallengeBlock)challenge
     transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                  signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
               publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
            errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSFriendRequestEntity *friendRequest = [[self.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(identityIdentifier)]] anyObject];
    NSAssert(friendRequest, @"there must be a friendRequest");
    [friendRequest sendAmount:amount fromAccount:account requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion errorNotificationBlock:errorNotificationBlock];
}

@end
