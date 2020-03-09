//
//  DSWalletDetailViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 3/6/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSWalletDetailViewController.h"
#import "DSAccountsViewController.h"
#import "DSDerivationPathFactory.h"
#import "DSSpecializedDerivationPathsViewController.h"

@interface DSWalletDetailViewController ()

@property (nonatomic, strong) UITableViewCell *accountsCell;
@property (nonatomic, strong) UITableViewCell *specialDerivationPathsCell;

@end

@implementation DSWalletDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.accountsCell = [self.tableView dequeueReusableCellWithIdentifier:@"AccountsCellIdentifier"];
    self.accountsCell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.wallet.accounts.count];
    self.specialDerivationPathsCell = [self.tableView dequeueReusableCellWithIdentifier:@"SpecialDerivationPathsCellIdentifier"];
    self.specialDerivationPathsCell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self.wallet].count];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
            return self.accountsCell;
            break;
        case 1:
            return self.specialDerivationPathsCell;
            break;
    }
    return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewAccountsSegue"]) {
        DSAccountsViewController *accountsViewController = (DSAccountsViewController *)segue.destinationViewController;
        accountsViewController.wallet = self.wallet;
    }
    else if ([segue.identifier isEqualToString:@"ViewSpecializedDerivationPathsSegue"]) {
        DSSpecializedDerivationPathsViewController *specializedDerivationPathsViewController = (DSSpecializedDerivationPathsViewController *)segue.destinationViewController;
        specializedDerivationPathsViewController.wallet = self.wallet;
    }
}
@end
