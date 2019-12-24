//
//  DSTransactionFactory.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransactionFactory.h"
#import "DSCoinbaseTransaction.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSBlockchainIdentityResetTransaction.h"
#import "DSBlockchainIdentityCloseTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSTransition.h"
#import "NSData+Dash.h"
#import "NSData+Bitcoin.h"

@implementation DSTransactionFactory

+(DSTransactionType)transactionTypeOfMessage:(NSData*)message {
    uint16_t version = [message UInt16AtOffset:0];
    if (version < 3) return DSTransactionType_Classic;
    return [message UInt16AtOffset:2];
}

+(DSTransaction*)transactionWithMessage:(NSData*)message onChain:(DSChain*)chain {
    uint16_t version = [message UInt16AtOffset:0];
    if (version < 3) return [DSTransaction transactionWithMessage:message onChain:chain]; //no special transactions yet
    uint16_t type = [message UInt16AtOffset:2];
    switch (type) {
        case DSTransactionType_Classic:
            return [DSTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_Coinbase:
            return [DSCoinbaseTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionRegistration:
            return [DSBlockchainIdentityRegistrationTransition transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionTopUp:
            return [DSBlockchainIdentityTopupTransition transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionCloseAccount:
            return [DSBlockchainIdentityCloseTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionResetKey:
            return [DSBlockchainIdentityResetTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderRegistration:
            return [DSProviderRegistrationTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateService:
            return [DSProviderUpdateServiceTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateRegistrar:
            return [DSProviderUpdateRegistrarTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateRevocation:
            return [DSProviderUpdateRevocationTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_Transition:
            return [DSTransition transactionWithMessage:message onChain:chain];
        default:
            return [DSTransaction transactionWithMessage:message onChain:chain]; //we won't be able to check the payload, but try best to support it.
    }
}

+(BOOL)ignoreMessagesOfTransactionType:(DSTransactionType)transactionType {
    switch (transactionType) {
        case DSTransactionType_Classic:
            return FALSE;
        case DSTransactionType_Coinbase:
            return FALSE;
        case DSTransactionType_SubscriptionRegistration:
            return FALSE;
        case DSTransactionType_SubscriptionTopUp:
            return FALSE;
        case DSTransactionType_SubscriptionCloseAccount:
            return FALSE;
        case DSTransactionType_SubscriptionResetKey:
            return FALSE;
        case DSTransactionType_ProviderRegistration:
            return FALSE;
        case DSTransactionType_ProviderUpdateService:
            return FALSE;
        case DSTransactionType_ProviderUpdateRegistrar:
            return FALSE;
        case DSTransactionType_ProviderUpdateRevocation:
            return FALSE;
        case DSTransactionType_QuorumCommitment:
            return TRUE;
        default:
            return TRUE;
    }
}

+(BOOL)shouldIgnoreTransactionMessage:(NSData*)message {
    return [self ignoreMessagesOfTransactionType:[self transactionTypeOfMessage:message]];
}

@end
