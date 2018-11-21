//
//  DSInsightManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

@interface DSInsightManager : NSObject

+ (instancetype _Nullable)sharedInstance;

// queries api.dashwallet.com and calls the completion block with unspent outputs for the given address
- (void)utxosForAddresses:(NSArray * _Nonnull)address
               completion:(void (^ _Nonnull)(NSArray * _Nonnull utxos, NSArray * _Nonnull amounts, NSArray * _Nonnull scripts,
                                             NSError * _Null_unspecified error))completion;

@end
