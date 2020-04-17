//
//  DSCreateBlockchainIdentityViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/27/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSWalletChooserViewController.h"
#import "DSAccountChooserViewController.h"

@interface DSCreateBlockchainIdentityViewController : UITableViewController <DSWalletChooserDelegate,DSAccountChooserDelegate>

@property (nonatomic,strong) DSChainManager * chainManager;

@end
