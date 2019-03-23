//
//  DSOutgoingContactsTableViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSOutgoingContactsTableViewController.h"


NS_ASSUME_NONNULL_BEGIN

static NSString * const CellId = @"CellId";

@interface DSOutgoingContactsTableViewController ()

@end

@implementation DSOutgoingContactsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Pending";
}

- (void)refreshData {
    [self.tableView reloadData];
}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.blockchainUser.outgoingContactRequests.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId forIndexPath:indexPath];
    
    NSString *username = self.blockchainUser.outgoingContactRequests[indexPath.row];
    cell.textLabel.text = username;
    
    return cell;
}

@end

NS_ASSUME_NONNULL_END
