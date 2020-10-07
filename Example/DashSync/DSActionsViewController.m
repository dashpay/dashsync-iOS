//
//  DSActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 12/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSActionsViewController.h"
#import "DSTransactionFloodingViewController.h"
#import "DSMiningViewController.h"

@interface DSActionsViewController ()

@end

@implementation DSActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"TransactionFloodingSegue"]) {
        DSTransactionFloodingViewController * transactionFloodingViewController = (DSTransactionFloodingViewController*)segue.destinationViewController;
        transactionFloodingViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"MiningSegue"]) {
        DSMiningViewController * miningViewController = (DSMiningViewController*)segue.destinationViewController;
        miningViewController.chainManager = self.chainManager;
    }
}


@end
