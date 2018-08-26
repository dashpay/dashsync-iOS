//
//  DSBlockchainUserActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainUserActionsViewController.h"
#import "DSTopupBlockchainUserViewController.h"

@interface DSBlockchainUserActionsViewController ()

@end

@implementation DSBlockchainUserActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainUserTopupSegue"]) {
        DSTopupBlockchainUserViewController * topupBlockchainUserViewController = (DSTopupBlockchainUserViewController*)segue.destinationViewController;
        topupBlockchainUserViewController.chainPeerManager = self.chainPeerManager;
        topupBlockchainUserViewController.blockchainUser = self.blockchainUser;
    }
}

@end
