//
//  DSSpecialTransactionsWalletHolder.h
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSWallet,DSTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic,readonly) NSArray * allTransactions;

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(DSTransaction*)transactionForHash:(UInt256)transactionHash;

@end

NS_ASSUME_NONNULL_END
