//
//  DSTransactionFactory.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSAssetLockTransaction.h"
#import "DSAssetUnlockTransaction.h"
#import "DSTransactionFactory.h"
#import "DSCoinbaseTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSQuorumCommitmentTransaction.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"

@implementation DSTransactionFactory

+ (DSTransactionType)transactionTypeOfMessage:(NSData *)message {
    uint16_t version = [message UInt16AtOffset:0];
    if (version < SPECIAL_TX_VERSION) return DSTransactionType_Classic;
    return [message UInt16AtOffset:2];
}

+ (DSTransaction *)transactionWithMessage:(NSData *)message onChain:(DSChain *)chain {
    uint16_t version = [message UInt16AtOffset:0];
    uint16_t type;
    if (version < SPECIAL_TX_VERSION) {
        type = DSTransactionType_Classic;
    } else {
        type = [message UInt16AtOffset:2];
    }
    switch (type) {
        case DSTransactionType_Classic:
            return [DSTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_Coinbase:
            return [DSCoinbaseTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderRegistration:
            return [DSProviderRegistrationTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateService:
            return [DSProviderUpdateServiceTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateRegistrar:
            return [DSProviderUpdateRegistrarTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_ProviderUpdateRevocation:
            return [DSProviderUpdateRevocationTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_AssetLock:
            return [DSAssetLockTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_AssetUnlock:
            return [DSAssetUnlockTransaction transactionWithMessage:message onChain:chain];
        case DSTransactionType_QuorumCommitment:
            return [DSQuorumCommitmentTransaction transactionWithMessage:message onChain:chain];
        default:
            return [DSTransaction transactionWithMessage:message onChain:chain]; //we won't be able to check the payload, but try best to support it.
    }
}

+ (BOOL)ignoreMessagesOfTransactionType:(DSTransactionType)transactionType {
    switch (transactionType) {
        case DSTransactionType_Classic:
            return FALSE;
        case DSTransactionType_Coinbase:
            return FALSE;
        case DSTransactionType_AssetLock:
            return FALSE;
        case DSTransactionType_AssetUnlock:
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

+ (BOOL)shouldIgnoreTransactionMessage:(NSData *)message {
    return [self ignoreMessagesOfTransactionType:[self transactionTypeOfMessage:message]];
}

@end
