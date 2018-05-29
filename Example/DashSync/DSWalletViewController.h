//
//  DSWalletViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

@interface DSWalletViewController : UITableViewController

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) DSChain * chain;

@end
