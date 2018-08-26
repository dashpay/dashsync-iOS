//
//  DSBlockchainUserActionsViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

@interface DSBlockchainUserActionsViewController : UITableViewController

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;
@property (nonatomic,strong) DSBlockchainUser * blockchainUser;

@end
