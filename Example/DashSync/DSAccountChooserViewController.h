//
//  DSAccountChooserViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

@protocol DSAccountChooserDelegate

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount*)account;

@end


@interface DSAccountChooserViewController : UITableViewController

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,weak) id<DSAccountChooserDelegate> delegate;

@end
