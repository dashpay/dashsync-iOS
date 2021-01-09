//
//  DSBlockchainIdentitiesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSBlockchainIdentitiesViewController : UITableViewController

@property (nonatomic, strong) DSChainManager *chainManager;

@end
