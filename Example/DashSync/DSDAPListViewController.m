//
//  DSDAPListViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 9/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSDAPListViewController.h"
#import "DSAddDAPViewController.h"

@interface DSDAPListViewController ()

@end

@implementation DSDAPListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView.refreshControl addTarget:self action:@selector(fetch:) forControlEvents:UIControlEventValueChanged];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

-(IBAction)fetch:(id)sender {
    // TODO: searchDapContracts was removed from JS dapi-client as outdated
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddDAPSegue"]) {
        DSAddDAPViewController * addDAPViewController = (DSAddDAPViewController*)segue.destinationViewController;
        addDAPViewController.chainManager = self.chainManager;
    }
}

@end
