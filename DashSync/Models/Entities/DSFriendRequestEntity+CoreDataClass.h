//
//  DSFriendRequestEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSTransactionManager.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSDashpayUserEntity, DSTransitionEntity, DSDerivationPathEntity, DSAccountEntity, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSFriendRequestEntity : NSManagedObject

+ (NSData *)friendshipIdentifierWithSourceIdentifier:(UInt256)sourceIdentifier destinationIdentifier:(UInt256)destinationIdentifier onAccountIndex:(uint32_t)accountIndex;
- (NSData *)finalizeWithFriendshipIdentifier;
+ (void)deleteFriendRequestsOnChainEntity:(DSChainEntity *)chainEntity;
- (void)sendAmount:(uint64_t)amount fromAccount:(DSAccount *)account requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                 presentChallenge:(DSTransactionChallengeBlock)challenge
    transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                 signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
              publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
           errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock;

@end

NS_ASSUME_NONNULL_END

#import "DSFriendRequestEntity+CoreDataProperties.h"
