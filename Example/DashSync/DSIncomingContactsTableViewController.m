//
//  DSIncomingContactsTableViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSIncomingContactsTableViewController.h"

#import "DSContactsModel.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const CellId = @"CellId";

@interface DSIncomingContactsTableViewController ()

@end

@implementation DSIncomingContactsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.model.incomingContactRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId forIndexPath:indexPath];
    
    NSString *username = self.model.incomingContactRequests[indexPath.row];
    cell.textLabel.text = username;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *username = self.model.incomingContactRequests[indexPath.row];
    __weak typeof(self) weakSelf = self;
    [self.model contactRequestUsername:username completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf showAlertTitle:@"Confirming contact request:" result:success];
    }];
}

#pragma mark - Private

- (void)showAlertTitle:(NSString *)title result:(BOOL)result {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:result ? @"✅ success" : @"❌ failure" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

NS_ASSUME_NONNULL_END
