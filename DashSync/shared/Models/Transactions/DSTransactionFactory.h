//
//  DSTransactionFactory.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSCoinbaseTransaction.h"
#import "DSTransaction.h"
#import <Foundation/Foundation.h>

//Special Transaction
//https://github.com/dashpay/dips/blob/master/dip-0002-special-transactions.md
typedef NS_ENUM(NSUInteger, DSTransactionType)
{
    DSTransactionType_Classic = 0,
    DSTransactionType_ProviderRegistration = 1,
    DSTransactionType_ProviderUpdateService = 2,
    DSTransactionType_ProviderUpdateRegistrar = 3,
    DSTransactionType_ProviderUpdateRevocation = 4,
    DSTransactionType_Coinbase = 5,
    DSTransactionType_QuorumCommitment = 6,
    DSTransactionType_AssetLock = 8,
    DSTransactionType_AssetUnlock = 9,
    DSTransactionType_SubscriptionResetKey = 10,
    DSTransactionType_SubscriptionCloseAccount = 11,
    DSTransactionType_Transition = 12,
};

@interface DSTransactionFactory : NSObject

+ (DSTransaction *)transactionWithMessage:(NSData *)data onChain:(DSChain *)chain;

+ (DSTransactionType)transactionTypeOfMessage:(NSData *)data;

+ (BOOL)ignoreMessagesOfTransactionType:(DSTransactionType)transactionType;

+ (BOOL)shouldIgnoreTransactionMessage:(NSData *)data;

@end
