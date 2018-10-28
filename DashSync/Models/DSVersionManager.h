//
//  DSVersionManager.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

@class DSWallet;

typedef void (^UpgradeCompletionBlock)(BOOL success, BOOL neededUpgrade,BOOL authenticated,BOOL cancelled); //success is true is neededUpgrade is true and we upgraded, or we didn't need upgrade
typedef void (^CheckPassphraseCompletionBlock)(BOOL needsCheck,BOOL authenticated,BOOL cancelled,NSString * _Nullable seedPhrase);

@interface DSVersionManager : NSObject

+ (instancetype _Nullable)sharedInstance;

-(void)upgradeExtendedKeysForWallet:(DSWallet*)wallet withCompletion:(UpgradeCompletionBlock)completion;

//todo : this logic should be in dashwallet instead
-(void)checkPassphraseWasShownCorrectlyForWallet:(DSWallet*)wallet withCompletion:(CheckPassphraseCompletionBlock)completion;

- (void)clearKeychainWalletData;

@end
