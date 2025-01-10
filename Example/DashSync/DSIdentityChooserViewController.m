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
#import "DSIdentityChooserTableViewCell.h"

@interface DSIdentityChooserViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *chooseButton;
@property (nonatomic, strong) NSArray<NSArray *> *orderedIdentities;
@property (strong, nonatomic) id identitiesObserver;
- (IBAction)choose:(id)sender;

@end

@implementation DSIdentityChooserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chooseButton.enabled = FALSE;

    [self loadData];

    self.identitiesObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateNotification
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
    NSMutableArray *mOrderedIdentities = [NSMutableArray array];
    for (DSWallet *wallet in self.chain.wallets) {
        if ([wallet.identities count]) {
            [mOrderedIdentities addObject:[[wallet.identities allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"registrationAssetLockTransaction.blockHeight" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"registrationAssetLockTransaction.timestamp" ascending:NO]]]];
        }
    }

    self.orderedIdentities = [mOrderedIdentities copy];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.orderedIdentities[section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedIdentities count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    DSWallet *wallet = [self.chain.wallets objectAtIndex:section];
    return wallet.uniqueIDString;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentityChooserTableViewCell *cell = (DSIdentityChooserTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"IdentityCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSIdentityChooserTableViewCell *)identityCell atIndexPath:(NSIndexPath *)indexPath {
    DSIdentity *identity = self.orderedIdentities[indexPath.section][indexPath.row];
    identityCell.usernameLabel.text = identity.currentDashpayUsername ? identity.currentDashpayUsername : @"Not yet set";
    identityCell.indexLabel.text = [NSString stringWithFormat:@"%u", identity.index];
    identityCell.walletLabel.text = identity.wallet.uniqueIDString;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentity *identity = self.orderedIdentities[indexPath.section][indexPath.row];
    if (identity.isRegistered) {
        self.chooseButton.enabled = TRUE;
        return indexPath;
    }
    self.chooseButton.enabled = FALSE;
    return indexPath;
}

- (IBAction)choose:(id)sender {
    if (self.tableView.indexPathForSelectedRow) {
        DSIdentity *identity = self.orderedIdentities[self.tableView.indexPathForSelectedRow.section][self.tableView.indexPathForSelectedRow.row];
        if (identity.isRegistered) {
            [self.delegate viewController:self didChooseIdentity:identity];
            [self.navigationController popViewControllerAnimated:TRUE];
        }
    }
}

@end
