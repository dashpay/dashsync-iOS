//
//  DSInsightManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSTransaction,DSChain;

@interface DSInsightManager : NSObject

+ (instancetype _Nullable)sharedInstance;

// queries api.dashwallet.com and calls the completion block with unspent outputs for the given address
- (void)utxosForAddresses:(NSArray * _Nonnull)address onChain:(DSChain*)chain 
               completion:(void (^ _Nonnull)(NSArray * _Nonnull utxos, NSArray * _Nonnull amounts, NSArray * _Nonnull scripts,
                                             NSError * _Null_unspecified error))completion;

-(void)queryInsightForTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion;

- (void)queryInsight:(NSString *)insightURL forTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion;

@end
