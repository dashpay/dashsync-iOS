//
//  DSSendAmountViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/23/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSSendAmountViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) DSAccount *account;

@end
