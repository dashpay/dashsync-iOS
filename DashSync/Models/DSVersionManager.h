//
//  DSVersionManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

@class DSChain;

typedef void (^UpgradeCompletionBlock)(BOOL success, BOOL neededUpgrade,BOOL authenticated,BOOL cancelled); //success is true is neededUpgrade is true and we upgraded, or we didn't need upgrade

@interface DSVersionManager : NSObject

+ (instancetype _Nullable)sharedInstance;

-(void)upgradeExtendedKeysWithCompletion:(_Nullable UpgradeCompletionBlock)completion forChain:(DSChain*)chain;

- (void)clearKeychainWalletData;

@end
