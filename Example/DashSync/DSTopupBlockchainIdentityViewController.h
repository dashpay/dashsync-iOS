//
//  DSTopupBlockchainIdentityViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAccountChooserViewController.h"
#import "DSWalletChooserViewController.h"
#import <UIKit/UIKit.h>

@interface DSTopupBlockchainIdentityViewController : UITableViewController <DSWalletChooserDelegate, DSAccountChooserDelegate>

@property (nonatomic, strong) DSChainManager *chainManager;
@property (nonatomic, strong) DSBlockchainIdentity *blockchainIdentity;

@end
