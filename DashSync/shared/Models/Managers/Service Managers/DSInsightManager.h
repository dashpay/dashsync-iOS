//
//  DSInsightManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSTransaction, DSChain, DSBlock;

@interface DSInsightManager : NSObject

+ (instancetype)sharedInstance;

// queries api.dashwallet.com and calls the completion block with unspent outputs for the given address
- (void)utxosForAddresses:(NSArray *)address onChain:(DSChain *)chain
               completion:(void (^)(NSArray *utxos, NSArray *amounts, NSArray *scripts,
                              NSError *_Null_unspecified error))completion;

- (void)findExistingAddresses:(NSArray *)addresses onChain:(DSChain *)chain
                   completion:(void (^)(NSArray *addresses, NSError *error))completion;

- (void)blockHeightsForBlockHashes:(NSArray *)blockHashes onChain:(DSChain *)chain completion:(void (^)(NSDictionary *blockHeightDictionary,
                                                                                                  NSError *_Null_unspecified error))completion;

- (void)blockForBlockHash:(UInt256)blockHash onChain:(DSChain *)chain completion:(void (^)(DSBlock *_Nullable block, NSError *_Nullable error))completion;

- (void)queryInsightForTransactionWithHash:(UInt256)transactionHash onChain:(DSChain *)chain completion:(void (^)(DSTransaction *transaction, NSError *error))completion;

- (void)queryInsight:(NSString *)insightURL forTransactionWithHash:(UInt256)transactionHash onChain:(DSChain *)chain completion:(void (^)(DSTransaction *transaction, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
