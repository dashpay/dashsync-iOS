//
//  DSTransactionManager.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSPeer.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerSyncStartedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerSyncFinishedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerSyncFailedNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerTransactionStatusDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerTransactionReceivedNotification;

FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerNotificationTransactionKey;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerNotificationTransactionChangesKey;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerNotificationInstantSendTransactionLockKey;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey;
FOUNDATION_EXPORT NSString* _Nonnull const DSTransactionManagerNotificationInstantSendTransactionAcceptedStatusKey;


typedef NS_ENUM(NSUInteger, DSRequestingAdditionalInfo) {
    DSRequestingAdditionalInfo_Amount = 1,
    DSRequestingAdditionalInfo_CancelOrChangeAmount = 2
};

@class DSChain, DSPaymentRequest,DSPaymentProtocolRequest,DSShapeshiftEntity,DSTransaction,DSPaymentProtocolACK;

typedef void (^DSTransactionCreationRequestingAdditionalInfoBlock)(DSRequestingAdditionalInfo additionalInfo);

typedef void (^DSTransactionChallengeBlock)(NSString * challengeTitle, NSString * challengeMessage,NSString * actionTitle, void (^actionBlock)(void), void (^cancelBlock)(void) );

typedef void (^DSTransactionErrorNotificationBlock)(NSError *error, NSString * _Nullable errorTitle, NSString * _Nullable errorMessage,BOOL shouldCancel);

typedef BOOL (^DSTransactionCreationCompletionBlock)(DSTransaction *tx, NSString *prompt, uint64_t amount, uint64_t proposedFee, NSArray<NSString *> *addresses, BOOL isSecure); //return is whether we should continue automatically

typedef BOOL (^DSTransactionSigningCompletionBlock)(DSTransaction * tx, NSError * _Nullable error, BOOL cancelled); //return is whether we should continue automatically

typedef void (^DSTransactionPublishedCompletionBlock)(DSTransaction * tx, NSError * _Nullable error, BOOL sent);

typedef void (^DSTransactionRequestRelayCompletionBlock)(DSTransaction * tx, DSPaymentProtocolACK *ack, BOOL relayedToServer);

@interface DSTransactionManager : NSObject <DSChainTransactionsDelegate,DSPeerTransactionDelegate>

@property (nonatomic,readonly) DSChain * chain;

- (void)fetchTransactionHavingHash:(UInt256)transactionHash;

- (NSUInteger)relayCountForTransaction:(UInt256)txHash; // number of connected peers that have relayed the transaction

- (DSBloomFilter *)transactionsBloomFilterForPeer:(DSPeer *)peer;

- (void)publishTransaction:(DSTransaction *)transaction completion:(void (^)(NSError *error))completion;

- (void)confirmPaymentRequest:(DSPaymentRequest *)paymentRequest usingUserBlockchainIdentity:(DSBlockchainIdentity* _Nullable)blockchainIdentity fromAccount:(DSAccount*)account acceptInternalAddress:(BOOL)acceptInternalAddress acceptReusingAddress:(BOOL)acceptReusingAddress addressIsFromPasteboard:(BOOL)addressIsFromPasteboard requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingConfirmationPrompt
     keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
     requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)completion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock;

- (void)signAndPublishTransaction:(DSTransaction *)tx createdFromProtocolRequest:(DSPaymentProtocolRequest*)protocolRequest fromAccount:(DSAccount*)account toAddress:(NSString*)address requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingConfirmationPrompt promptMessage:(NSString * _Nullable)promptMessage forAmount:(uint64_t)amount keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock _Nullable)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock;

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount*)account addressIsFromPasteboard:(BOOL)addressIsFromPasteboard requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
      keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
      requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock _Nullable)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock;

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount*)account acceptInternalAddress:(BOOL)acceptInternalAddress acceptReusingAddress:(BOOL)acceptReusingAddress addressIsFromPasteboard:(BOOL)addressIsFromPasteboard acceptUncertifiedPayee:(BOOL)acceptUncertifiedPayee requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
      keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
      requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock _Nullable)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock;
@end

NS_ASSUME_NONNULL_END
