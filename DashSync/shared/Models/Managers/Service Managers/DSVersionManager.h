//
//  DSVersionManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSWallet;
@class DSChain;

typedef void (^NeedsUpgradeCompletionBlock)(BOOL success, BOOL neededUpgrade); //success is true is neededUpgrade is true and we upgraded, or we didn't need upgrade

typedef void (^UpgradeCompletionBlock)(BOOL success, BOOL neededUpgrade, BOOL authenticated, BOOL cancelled); //success is true is neededUpgrade is true and we upgraded, or we didn't need upgrade

@interface DSVersionManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)noOldWallet;

- (void)upgradeVersion1ExtendedKeysForWallet:(nullable DSWallet *)wallet chain:(DSChain *)chain withMessage:(NSString *)message withCompletion:(UpgradeCompletionBlock)completion;

- (void)upgradeExtendedKeysForWallets:(NSArray *)wallets withMessage:(NSString *)message withCompletion:(_Nullable UpgradeCompletionBlock)completion;

- (BOOL)clearKeychainWalletOldData;

@end

NS_ASSUME_NONNULL_END
