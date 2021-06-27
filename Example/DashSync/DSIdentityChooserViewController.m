//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSIdentityChooserViewController.h"
#import "DSBlockchainIdentityChooserTableViewCell.h"

@interface DSIdentityChooserViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *chooseButton;
@property (nonatomic, strong) NSArray<NSArray *> *orderedBlockchainIdentities;
@property (strong, nonatomic) id blockchainIdentitiesObserver;
- (IBAction)choose:(id)sender;

@end

@implementation DSIdentityChooserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chooseButton.enabled = FALSE;

    [self loadData];

    self.blockchainIdentitiesObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:self.chain]) {
                                                              [self loadData];
                                                              [self.tableView reloadData];
                                                          }
                                                      }];
}


- (void)loadData {
    NSMutableArray *mOrderedBlockchainIdentities = [NSMutableArray array];
    for (DSWallet *wallet in self.chain.wallets) {
        if ([wallet.blockchainIdentities count]) {
            [mOrderedBlockchainIdentities addObject:[[wallet.blockchainIdentities allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"registrationCreditFundingTransaction.blockHeight" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"registrationCreditFundingTransaction.timestamp" ascending:NO]]]];
        }
    }

    self.orderedBlockchainIdentities = [mOrderedBlockchainIdentities copy];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.orderedBlockchainIdentities[section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedBlockchainIdentities count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    DSWallet *wallet = [self.chain.wallets objectAtIndex:section];
    return wallet.uniqueIDString;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainIdentityChooserTableViewCell *cell = (DSBlockchainIdentityChooserTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"IdentityCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSBlockchainIdentityChooserTableViewCell *)blockchainIdentityCell atIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainIdentity *blockchainIdentity = self.orderedBlockchainIdentities[indexPath.section][indexPath.row];
    blockchainIdentityCell.usernameLabel.text = blockchainIdentity.currentDashpayUsername ? blockchainIdentity.currentDashpayUsername : @"Not yet set";
    blockchainIdentityCell.indexLabel.text = [NSString stringWithFormat:@"%u", blockchainIdentity.index];
    blockchainIdentityCell.walletLabel.text = blockchainIdentity.wallet.uniqueIDString;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DSBlockchainIdentity *blockchainIdentity = self.orderedBlockchainIdentities[indexPath.section][indexPath.row];
    if (blockchainIdentity.isRegistered) {
        self.chooseButton.enabled = TRUE;
        return indexPath;
    }
    self.chooseButton.enabled = FALSE;
    return indexPath;
}

- (IBAction)choose:(id)sender {
    if (self.tableView.indexPathForSelectedRow) {
        DSBlockchainIdentity *blockchainIdentity = self.orderedBlockchainIdentities[self.tableView.indexPathForSelectedRow.section][self.tableView.indexPathForSelectedRow.row];
        if (blockchainIdentity.isRegistered) {
            [self.delegate viewController:self didChooseIdentity:blockchainIdentity];
            [self.navigationController popViewControllerAnimated:TRUE];
        }
    }
}

@end
