//
//  DSChooseWalletViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/27/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@protocol DSWalletChooserDelegate

- (void)viewController:(UIViewController *)controller didChooseWallet:(DSWallet *)wallet;

@end


@interface DSWalletChooserViewController : UITableViewController

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, weak) id<DSWalletChooserDelegate> delegate;

@end
