//
//  DSWalletInputPhraseViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 5/18/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSWalletInputPhraseViewController : UIViewController <UITextViewDelegate>

@property (nonatomic, strong) DSChain *chain;

@end
