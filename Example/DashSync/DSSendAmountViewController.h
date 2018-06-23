//
//  DSSendAmountViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/23/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

@interface DSSendAmountViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic,strong) DSAccount * account;

@end
