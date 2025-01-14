//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSSearchIdentitiesViewController.h"
#import "DSIdentitySearchTableViewCell.h"

@interface DSSearchIdentitiesViewController ()

@property (nonatomic, strong) NSArray *identities;

@end

@implementation DSSearchIdentitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.identities = [NSArray array];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.identities.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentitySearchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainIdentityNameCellIdentifier" forIndexPath:indexPath];

    DSIdentity *identity = self.identities[indexPath.row];

    cell.usernameLabel.text = identity.currentDashpayUsername;
    cell.identityUniqueIDLabel.text = identity.uniqueIdString;
    cell.avatarPathLabel.text = identity.avatarPath;
    cell.displayNameLabel.text = identity.displayName;

    return cell;
}

- (void)searchByNamePrefix:(NSString *)namePrefix {
    [self.chainManager.identitiesManager searchIdentitiesByDashpayUsernamePrefix:namePrefix
                                                         queryDashpayProfileInfo:YES
                                                                  withCompletion:^(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *_Nonnull errors) {
        if (success) [self updateIdentities:identities];
    }];
}

- (void)updateIdentities:(NSArray<DSIdentity *> *_Nullable)identities {
    self.identities = identities;
    [self.tableView reloadData];
}

- (void)searchByIdentifier:(NSData *)identifier {
    [self.chainManager.identitiesManager searchIdentitiesByDPNSRegisteredIdentityUniqueID:identifier
                                                                           withCompletion:^(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *_Nonnull errors) {
        if (success) [self updateIdentities:identities];
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if (!searchBar.selectedScopeButtonIndex) {
        [self searchByNamePrefix:searchBar.text];
    } else {
        [self searchByIdentifier:searchBar.text.base58ToData];
    }
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
