//
//  DSInsightManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSTransaction,DSChain;

@interface DSInsightManager : NSObject

+ (instancetype)sharedInstance;

// queries api.dashwallet.com and calls the completion block with unspent outputs for the given address
- (void)utxosForAddresses:(NSArray *)address onChain:(DSChain *)chain 
               completion:(void (^)(NSArray * utxos, NSArray * amounts, NSArray * scripts,
                                             NSError * _Null_unspecified error))completion;

- (void)blockHeightsForBlockHashes:(NSArray*)blockHashes onChain:(DSChain*)chain completion:(void (^)(NSDictionary * blockHeightDictionary,
NSError * _Null_unspecified error))completion;

-(void)queryInsightForTransactionWithHash:(UInt256)transactionHash onChain:(DSChain *)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion;

- (void)queryInsight:(NSString *)insightURL forTransactionWithHash:(UInt256)transactionHash onChain:(DSChain*)chain completion:(void (^)(DSTransaction * transaction, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
