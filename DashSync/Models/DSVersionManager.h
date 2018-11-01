//
//  DSVersionManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

@class DSWallet;

typedef void (^UpgradeCompletionBlock)(BOOL success, BOOL neededUpgrade,BOOL authenticated,BOOL cancelled); //success is true is neededUpgrade is true and we upgraded, or we didn't need upgrade

@interface DSVersionManager : NSObject

+ (instancetype _Nullable)sharedInstance;

- (void)upgradeExtendedKeysForWallet:(DSWallet*)wallet withMessage:(NSString*)message withCompletion:(UpgradeCompletionBlock)completion;

- (void)clearKeychainWalletData;

@end
