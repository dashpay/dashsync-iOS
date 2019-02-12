//
//  DSTransactionFactory.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransactionFactory.h"
#import "DSCoinbaseTransaction.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "NSData+Dash.h"
#import "NSData+Bitcoin.h"

@implementation DSTransactionFactory

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
            return [DSBlockchainUserRegistrationTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionTopUp:
            return [DSBlockchainUserTopupTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionCloseAccount:
            return [DSBlockchainUserCloseTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_SubscriptionResetKey:
            return [DSBlockchainUserResetTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderRegistration:
            return [DSProviderRegistrationTransaction transactionWithMessage:message onChain:chain];
        default:
            return [DSTransaction transactionWithMessage:message onChain:chain]; //we won't be able to check the payload, but try best to support it.
    }
}

@end
