//
//  DSLayer2ViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 9/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSLayer2ViewController.h"
#import "DSDAPICallsViewController.h"
#import "DSDAPListViewController.h"

@interface DSLayer2ViewController ()

@end

@implementation DSLayer2ViewController

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
    if ([segue.identifier isEqualToString:@"DAPICallsSegue"]) {
        DSDAPICallsViewController * DAPICallsViewController = (DSDAPICallsViewController*)segue.destinationViewController;
        DAPICallsViewController.chainPeerManager = self.chainPeerManager;
    } else if ([segue.identifier isEqualToString:@"DAPsSegue"]) {
        DSDAPListViewController * DAPListViewController = (DSDAPListViewController*)segue.destinationViewController;
        DAPListViewController.chainPeerManager = self.chainPeerManager;
    }
}

@end
